from decimal import Decimal
from django.utils import timezone
from django.core.exceptions import ValidationError
from transactions.models import Transaction

def check_spending_limits(user, amount: Decimal):
    """
    Checks if a requested outgoing transaction (amount) exceeds the user's
    daily or monthly spending limits. Raises ValidationError if exceeded.
    """
    wallet = user.wallet
    now = timezone.now()

    # Get start of today
    start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    
    # Get start of this month
    start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    # Calculate total spent today
    spent_today = sum(
        t.amount for t in Transaction.objects.filter(
            user=user, 
            type='debit', 
            status='success',
            created_at__gte=start_of_today
        )
    )

    # Calculate total spent this month
    spent_month = sum(
        t.amount for t in Transaction.objects.filter(
            user=user, 
            type='debit', 
            status='success',
            created_at__gte=start_of_month
        )
    )

    if (Decimal(spent_today) + amount) > wallet.daily_limit:
        raise ValidationError(f"Transaction exceeds daily limit of ₦{wallet.daily_limit}")

    if (Decimal(spent_month) + amount) > wallet.monthly_limit:
        raise ValidationError(f"Transaction exceeds monthly limit of ₦{wallet.monthly_limit}")
