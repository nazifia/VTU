from decimal import Decimal
from django.utils import timezone
from django.core.exceptions import ValidationError
from django.db.models import Sum
from transactions.models import Transaction


def verify_transaction_pin(user, raw_pin: str):
    """
    Raise ValidationError if the supplied PIN does not match the user's
    transaction PIN, or if no transaction PIN has been set yet.
    """
    if not user.has_transaction_pin:
        raise ValidationError(
            'Transaction PIN not set. Please set your transaction PIN before making payments.'
        )
    if not user.check_transaction_pin(raw_pin):
        raise ValidationError('Incorrect transaction PIN.')


def check_spending_limits(user, amount: Decimal):
    """
    Checks if a requested outgoing transaction (amount) exceeds the user's
    daily or monthly spending limits. Raises ValidationError if exceeded.
    """
    wallet = user.wallet
    now = timezone.now()

    start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    spent_today = Transaction.objects.filter(
        user=user,
        type='debit',
        status='success',
        created_at__gte=start_of_today,
    ).aggregate(total=Sum('amount'))['total'] or Decimal('0.00')

    spent_month = Transaction.objects.filter(
        user=user,
        type='debit',
        status='success',
        created_at__gte=start_of_month,
    ).aggregate(total=Sum('amount'))['total'] or Decimal('0.00')

    if (spent_today + amount) > wallet.daily_limit:
        raise ValidationError(f"Transaction exceeds daily limit of ₦{wallet.daily_limit}")

    if (spent_month + amount) > wallet.monthly_limit:
        raise ValidationError(f"Transaction exceeds monthly limit of ₦{wallet.monthly_limit}")
