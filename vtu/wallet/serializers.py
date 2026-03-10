from rest_framework import serializers
from .models import Wallet

# Maximum limits a user may self-set (admin can always set higher via Django admin)
MAX_DAILY_LIMIT   = 200_000
MAX_MONTHLY_LIMIT = 2_000_000


class WalletSerializer(serializers.ModelSerializer):
    class Meta:
        model = Wallet
        fields = ['id', 'balance', 'daily_limit', 'monthly_limit', 'updated_at']
        read_only_fields = fields


class FundWalletSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=1)
    reference = serializers.CharField(max_length=100)


class WalletLimitsSerializer(serializers.ModelSerializer):
    class Meta:
        model = Wallet
        fields = ['daily_limit', 'monthly_limit']

    def validate_daily_limit(self, value):
        if value <= 0:
            raise serializers.ValidationError('Daily limit must be greater than 0.')
        if value > MAX_DAILY_LIMIT:
            raise serializers.ValidationError(
                f'Daily limit cannot exceed ₦{MAX_DAILY_LIMIT:,.0f}.'
            )
        return value

    def validate_monthly_limit(self, value):
        if value <= 0:
            raise serializers.ValidationError('Monthly limit must be greater than 0.')
        if value > MAX_MONTHLY_LIMIT:
            raise serializers.ValidationError(
                f'Monthly limit cannot exceed ₦{MAX_MONTHLY_LIMIT:,.0f}.'
            )
        return value

    def validate(self, data):
        daily   = data.get('daily_limit',   self.instance.daily_limit   if self.instance else None)
        monthly = data.get('monthly_limit', self.instance.monthly_limit if self.instance else None)
        if daily and monthly and daily > monthly:
            raise serializers.ValidationError(
                {'daily_limit': 'Daily limit cannot exceed the monthly limit.'}
            )
        return data
