from rest_framework import serializers
from .models import Transaction


class TransactionSerializer(serializers.ModelSerializer):
    recipient = serializers.SerializerMethodField()
    provider = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = [
            'id', 'type', 'category', 'amount', 'reference',
            'status', 'description', 'metadata', 'created_at',
            'recipient', 'provider',
        ]
        read_only_fields = fields

    def get_recipient(self, obj):
        return obj.metadata.get('phone') or obj.metadata.get('account_number')

    def get_provider(self, obj):
        return obj.metadata.get('provider')
