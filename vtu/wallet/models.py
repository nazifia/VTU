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
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'wallet_wallet'

    def __str__(self):
        return f'{self.user.phone} — ₦{self.balance}'

    def credit(self, amount: Decimal):
        self.balance += amount
        self.save(update_fields=['balance', 'updated_at'])

    def debit(self, amount: Decimal):
        if self.balance < amount:
            raise ValueError('Insufficient wallet balance.')
        self.balance -= amount
        self.save(update_fields=['balance', 'updated_at'])
