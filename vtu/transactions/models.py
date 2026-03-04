from django.db import models
from django.conf import settings
import uuid


TRANSACTION_TYPES = [
    ('credit', 'Credit'),
    ('debit', 'Debit'),
]

TRANSACTION_CATEGORIES = [
    ('wallet_funding', 'Wallet Funding'),
    ('airtime', 'Airtime'),
    ('data', 'Data'),
    ('electricity', 'Electricity'),
    ('cable_tv', 'Cable TV'),
    ('water', 'Water'),
    ('bank_transfer', 'Bank Transfer'),
    ('other', 'Other'),
]

TRANSACTION_STATUSES = [
    ('pending', 'Pending'),
    ('success', 'Success'),
    ('failed', 'Failed'),
]


class Transaction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='transactions',
    )
    type = models.CharField(max_length=10, choices=TRANSACTION_TYPES)
    category = models.CharField(max_length=20, choices=TRANSACTION_CATEGORIES)
    amount = models.DecimalField(max_digits=14, decimal_places=2)
    reference = models.CharField(max_length=100, unique=True)
    status = models.CharField(max_length=10, choices=TRANSACTION_STATUSES, default='pending')
    description = models.TextField(blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'transactions_transaction'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.user.phone} — {self.category} — ₦{self.amount} ({self.status})'
