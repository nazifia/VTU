import os
import uuid
import requests
from decimal import Decimal
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from .models import Wallet
from .serializers import WalletSerializer, FundWalletSerializer
from transactions.models import Transaction


class WalletDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        wallet = request.user.wallet
        return Response(WalletSerializer(wallet).data)


class FundWalletView(APIView):
    """
    Credits the user's wallet.
    In production this is called via a Paystack webhook after payment confirmation.
    For bank-transfer / USSD / virtual-account funding it can be called directly
    once the payment gateway confirms receipt.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = FundWalletSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        amount = serializer.validated_data['amount']
        reference = serializer.validated_data['reference']

        wallet = request.user.wallet
        wallet.credit(amount)

        Transaction.objects.create(
            user=request.user,
            type='credit',
            category='wallet_funding',
            amount=amount,
            reference=reference,
            status='success',
            description=f'Wallet funded with ₦{amount}',
        )
        return Response({
            'balance': str(wallet.balance),
            'message': 'Wallet funded successfully.',
        })


class VirtualAccountsView(APIView):
    """
    Returns the list of virtual bank accounts users can transfer money to
    in order to fund their wallet.

    Production upgrade path:
        - Create a Paystack/Flutterwave dedicated virtual account per user on
          registration, store the account number in the DB, and return it here.
        - Set PAYSTACK_SECRET_KEY in the environment.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        # TODO: in production, fetch from user.virtual_account or Paystack API
        accounts = [
            {
                'bank': 'Wema Bank',
                'number': '0123456789',
                'name': 'VTU Wallet Ltd',
            },
            {
                'bank': 'Sterling Bank',
                'number': '9876543210',
                'name': 'VTU Wallet Ltd',
            },
            {
                'bank': 'Providus Bank',
                'number': '5544332211',
                'name': 'VTU Wallet Ltd',
            },
            {
                'bank': 'GTBank',
                'number': '0012345678',
                'name': 'VTU Wallet Ltd',
            },
            {
                'bank': 'Access Bank',
                'number': '0087654321',
                'name': 'VTU Wallet Ltd',
            },
            {
                'bank': 'Zenith Bank',
                'number': '2200112233',
                'name': 'VTU Wallet Ltd',
            },
            {
                'bank': 'First Bank',
                'number': '3300998877',
                'name': 'VTU Wallet Ltd',
            },
            {
                'bank': 'UBA',
                'number': '2020304050',
                'name': 'VTU Wallet Ltd',
            },
        ]
        return Response(accounts)


class InitiateCardPaymentView(APIView):
    """
    Initiates a Paystack inline card charge session.
    Returns an authorization_url the Flutter app opens in a WebView.

    After the user completes payment, Paystack fires a webhook to
    /payment/webhook/ which then calls FundWalletView to credit the wallet.

    Requires PAYSTACK_SECRET_KEY in environment.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        amount = request.data.get('amount')
        if not amount:
            return Response(
                {'detail': 'amount is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        secret_key = os.environ.get('PAYSTACK_SECRET_KEY', '')
        if not secret_key:
            return Response(
                {'detail': 'Payment gateway not configured. Set PAYSTACK_SECRET_KEY.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        ref = f'CARD-{uuid.uuid4().hex[:12].upper()}'
        try:
            r = requests.post(
                'https://api.paystack.co/transaction/initialize',
                headers={
                    'Authorization': f'Bearer {secret_key}',
                    'Content-Type': 'application/json',
                },
                json={
                    'email': request.user.email or f'{request.user.phone}@vtu.app',
                    'amount': int(Decimal(str(amount)) * 100),   # Paystack uses kobo
                    'reference': ref,
                    'callback_url': f'{os.environ.get("APP_BASE_URL","")}/payment/callback/',
                    'metadata': {
                        'user_id': str(request.user.id),
                        'purpose': 'wallet_funding',
                    },
                },
                timeout=15,
            )
            r.raise_for_status()
            data = r.json()['data']
            return Response({
                'authorization_url': data['authorization_url'],
                'access_code': data['access_code'],
                'reference': ref,
            })
        except requests.exceptions.RequestException as exc:
            return Response(
                {'detail': f'Payment gateway error: {exc}'},
                status=status.HTTP_502_BAD_GATEWAY,
            )


class PaystackWebhookView(APIView):
    """
    Receives Paystack payment.success webhook, verifies the event,
    and credits the user's wallet.
    """
    permission_classes = []   # Paystack webhooks don't carry JWT tokens

    def post(self, request):
        secret_key = os.environ.get('PAYSTACK_SECRET_KEY', '')
        if not secret_key:
            return Response(status=status.HTTP_501_NOT_IMPLEMENTED)

        # 1. Verify Paystack signature
        import hmac, hashlib
        signature = request.headers.get('x-paystack-signature', '')
        computed = hmac.new(
            secret_key.encode(), request.body, hashlib.sha512
        ).hexdigest()
        if not hmac.compare_digest(signature, computed):
            return Response(status=status.HTTP_400_BAD_REQUEST)

        event = request.data.get('event')
        if event != 'charge.success':
            return Response(status=status.HTTP_200_OK)   # ignore other events

        data = request.data.get('data', {})
        ref = data.get('reference', '')
        amount_kobo = data.get('amount', 0)
        amount = Decimal(str(amount_kobo)) / 100
        user_id = data.get('metadata', {}).get('user_id')

        # 2. Idempotency check — don't double-credit
        if Transaction.objects.filter(reference=ref).exists():
            return Response(status=status.HTTP_200_OK)

        # 3. Credit wallet
        from django.contrib.auth import get_user_model
        User = get_user_model()
        try:
            user = User.objects.get(id=user_id)
            wallet = user.wallet
            wallet.credit(amount)
            Transaction.objects.create(
                user=user,
                type='credit',
                category='wallet_funding',
                amount=amount,
                reference=ref,
                status='success',
                description=f'Wallet funded via card – ₦{amount}',
            )
        except User.DoesNotExist:
            pass

        return Response(status=status.HTTP_200_OK)
