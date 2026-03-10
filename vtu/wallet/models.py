from django.db import models
from django.conf import settings
from decimal import Decimal
import uuid


class Wallet(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='wallet'
    )
    balance = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0.00'))
    daily_limit = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('50000.00'))
    monthly_limit = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('500000.00'))
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'wallet_wallet'

    def __str__(self):
        return f'{self.user.phone} — ₦{self.balance}'

    def credit(self, amount: Decimal):
        """Atomically credit the wallet using a DB-level UPDATE (no race condition)."""
        from django.db.models import F
        from django.utils import timezone as tz
        Wallet.objects.filter(pk=self.pk).update(
            balance=F('balance') + amount,
            updated_at=tz.now(),
        )
        self.refresh_from_db()

    def debit(self, amount: Decimal):
        """
        Atomically debit the wallet using a conditional DB-level UPDATE.
        The balance check and subtraction happen in a single SQL statement,
        eliminating the TOCTOU race condition.
        """
        from django.db.models import F
        from django.utils import timezone as tz
        updated = Wallet.objects.filter(pk=self.pk, balance__gte=amount).update(
            balance=F('balance') - amount,
            updated_at=tz.now(),
        )
        if not updated:
            raise ValueError('Insufficient wallet balance.')
        self.refresh_from_db()
