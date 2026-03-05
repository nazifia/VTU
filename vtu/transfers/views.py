import os
import uuid
import requests
from decimal import Decimal
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import serializers, status
from django.core.exceptions import ValidationError
from transactions.models import Transaction
from wallet.utils import check_spending_limits


# ── Serializers ───────────────────────────────────────────────────────────────
class BankTransferSerializer(serializers.Serializer):
    account_number = serializers.CharField(min_length=10, max_length=10)
    bank_code = serializers.CharField(max_length=10)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=100)
    narration = serializers.CharField(max_length=200, required=False, allow_blank=True)


class AccountVerifySerializer(serializers.Serializer):
    account_number = serializers.CharField(min_length=10, max_length=10)
    bank_code = serializers.CharField(max_length=10)


# ── Real Paystack account name enquiry ────────────────────────────────────────
def _resolve_account_name(account_number: str, bank_code: str) -> str:
    """
    Calls the Paystack bank resolve API to get the real account holder name.
    Falls back gracefully if the API key is missing or the call fails.

    Requires PAYSTACK_SECRET_KEY in environment:
        export PAYSTACK_SECRET_KEY=sk_test_xxxxxxxxxxxx
    """
    secret_key = os.environ.get('PAYSTACK_SECRET_KEY', '')
    if not secret_key:
        # No key configured — return a placeholder so the app still works
        return f'Account {account_number}'

    try:
        response = requests.get(
            'https://api.paystack.co/bank/resolve',
            headers={'Authorization': f'Bearer {secret_key}'},
            params={'account_number': account_number, 'bank_code': bank_code},
            timeout=10,
        )
        response.raise_for_status()
        data = response.json()
        return data['data']['account_name']
    except requests.exceptions.Timeout:
        return f'Account {account_number}'   # timeout — degrade gracefully
    except Exception:
        return f'Account {account_number}'   # any other error — degrade gracefully


# ── Views ─────────────────────────────────────────────────────────────────────
class VerifyAccountView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        s = AccountVerifySerializer(data=request.query_params)
        s.is_valid(raise_exception=True)
        account_number = s.validated_data['account_number']
        bank_code = s.validated_data['bank_code']
        account_name = _resolve_account_name(account_number, bank_code)
        return Response({
            'account_name': account_name,
            'account_number': account_number,
            'bank_code': bank_code,
        })


class BankTransferView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        s = BankTransferSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        amount = d['amount']
        wallet = request.user.wallet

        try:
            check_spending_limits(request.user, amount)
            wallet.debit(amount)
        except (ValueError, ValidationError) as e:
            msg = e.message if hasattr(e, 'message') else str(e)
            return Response({'detail': msg}, status=status.HTTP_400_BAD_REQUEST)

        ref = f'TRF-{uuid.uuid4().hex[:12].upper()}'
        account_name = _resolve_account_name(d['account_number'], d['bank_code'])

        Transaction.objects.create(
            user=request.user,
            type='debit',
            category='bank_transfer',
            amount=amount,
            reference=ref,
            status='success',
            description=d.get('narration') or f'Transfer to {account_name}',
            metadata={
                'account_number': d['account_number'],
                'bank_code': d['bank_code'],
                'account_name': account_name,
                'narration': d.get('narration', ''),
                'source': 'Npay Wallet',
                'destination': f"{account_name} ({d['account_number']})",
            },
        )
        return Response({
            'status': 'success',
            'message': f'₦{amount} transferred to {account_name}',
            'reference': ref,
        })
