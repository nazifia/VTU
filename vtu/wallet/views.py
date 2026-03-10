import os
import uuid
import logging
import requests
from decimal import Decimal
from django.db import transaction
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from .models import Wallet
from .serializers import WalletSerializer, FundWalletSerializer
from .utils import check_maintenance_mode
from transactions.models import Transaction

logger = logging.getLogger(__name__)


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

    @transaction.atomic
    def post(self, request):
        from django.core.exceptions import ValidationError
        try:
            check_maintenance_mode()
        except ValidationError as e:
            return Response({'detail': e.message}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        serializer = FundWalletSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        amount = serializer.validated_data['amount']
        reference = serializer.validated_data['reference']

        # Idempotency: don't double-credit for the same reference
        if Transaction.objects.filter(reference=reference).exists():
            wallet = request.user.wallet
            return Response({
                'balance': str(wallet.balance),
                'message': 'Wallet already funded with this reference.',
            })

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
            metadata={
                'source': 'Bank Transfer / USSD',
                'destination': 'Npay Wallet',
            }
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
                'bank': 'Npay',
                'number': '0000000000',
                'name': 'Npay',
            },
            {
                'bank': 'Wema Bank',
                'number': '0123456789',
                'name': 'Npay',
            },
            {
                'bank': 'Sterling Bank',
                'number': '9876543210',
                'name': 'Npay',
            },
            {
                'bank': 'Providus Bank',
                'number': '5544332211',
                'name': 'Npay',
            },
            {
                'bank': 'GTBank',
                'number': '0012345678',
                'name': 'Npay',
            },
            {
                'bank': 'Access Bank',
                'number': '0087654321',
                'name': 'Npay',
            },
            {
                'bank': 'Zenith Bank',
                'number': '2200112233',
                'name': 'Npay',
            },
            {
                'bank': 'First Bank',
                'number': '3300998877',
                'name': 'Npay',
            },
            {
                'bank': 'UBA',
                'number': '2020304050',
                'name': 'Npay',
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
        raw_amount = request.data.get('amount')
        if not raw_amount:
            return Response(
                {'detail': 'amount is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            amount = Decimal(str(raw_amount))
            if amount <= 0 or amount > Decimal('1000000'):
                raise ValueError
        except Exception:
            return Response(
                {'detail': 'amount must be a positive number not exceeding ₦1,000,000.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        secret_key = os.environ.get('PAYSTACK_SECRET_KEY', '')
        if not secret_key:
            return Response(
                {'detail': 'Payment gateway not configured.'},
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
                    'amount': int(amount * 100),   # Paystack uses kobo
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
        except requests.exceptions.RequestException:
            logger.exception('Paystack initiate payment error for user %s', request.user.id)
            return Response(
                {'detail': 'Payment gateway unavailable. Please try again later.'},
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
        import hmac, hashlib, logging
        logger = logging.getLogger(__name__)

        signature = request.headers.get('x-paystack-signature', '')
        computed = hmac.new(
            secret_key.encode(), request.body, hashlib.sha512
        ).hexdigest()
        
        if not hmac.compare_digest(signature, computed):
            logger.warning(f"Invalid Paystack webhook signature from {request.META.get('REMOTE_ADDR')}")
            return Response(status=status.HTTP_400_BAD_REQUEST)

        event = request.data.get('event')
        data = request.data.get('data', {})

        if event != 'charge.success' or data.get('status') != 'success':
            logger.info(f"Ignoring Paystack event: {event} with status {data.get('status')}")
            return Response(status=status.HTTP_200_OK)   # ignore other events

        data = request.data.get('data', {})
        ref = data.get('reference', '')
        amount_kobo = data.get('amount', 0)
        amount = Decimal(str(amount_kobo)) / 100
        user_id = data.get('metadata', {}).get('user_id')

        # 2. Idempotency check — don't double-credit
        if Transaction.objects.filter(reference=ref).exists():
            return Response(status=status.HTTP_200_OK)

        # 3. Credit wallet (atomic: both credit and transaction record succeed or neither does)
        from django.contrib.auth import get_user_model
        User = get_user_model()
        try:
            user = User.objects.get(id=user_id)
            with transaction.atomic():
                user.wallet.credit(amount)
                Transaction.objects.create(
                    user=user,
                    type='credit',
                    category='wallet_funding',
                    amount=amount,
                    reference=ref,
                    status='success',
                    description=f'Wallet funded via card – ₦{amount}',
                    metadata={
                        'source': 'Card',
                        'destination': 'Npay Wallet',
                    }
                )
        except User.DoesNotExist:
            logger.error('Webhook received for unknown user_id=%s ref=%s', user_id, ref)

        return Response(status=status.HTTP_200_OK)
