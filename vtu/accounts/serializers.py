import re
from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password

User = get_user_model()

NIGERIAN_PHONE_RE = re.compile(r'^0[789]\d{9}$')


class UserSerializer(serializers.ModelSerializer):
    full_name           = serializers.ReadOnlyField()
    profile_image       = serializers.SerializerMethodField()
    balance             = serializers.SerializerMethodField()
    created_at          = serializers.SerializerMethodField()
    has_transaction_pin = serializers.ReadOnlyField()

    class Meta:
        model = User
        fields = [
            'id', 'phone', 'email', 'first_name', 'last_name',
            'full_name', 'profile_image', 'is_verified', 'date_joined',
            'balance', 'created_at', 'has_transaction_pin',
        ]
        read_only_fields = ['id', 'phone', 'is_verified', 'date_joined', 'balance', 'has_transaction_pin']

    def get_profile_image(self, obj):
        request = self.context.get('request')
        if obj.avatar and request:
            return request.build_absolute_uri(obj.avatar.url)
        return None

    def get_balance(self, obj):
        try:
            return str(obj.wallet.balance)
        except Exception:
            return '0.00'

    def get_created_at(self, obj):
        if obj.date_joined:
            return obj.date_joined.isoformat()
        return None


def normalize_phone(value):
    """Normalize phone numbers: strip spaces, and prepend 0 if it's 10 digits (e.g. 801...)."""
    value = str(value).strip().replace(' ', '')
    if len(value) == 10 and not value.startswith('0'):
        value = '0' + value
    return value


def validate_nigerian_phone(value):
    """Raise ValidationError if value is not a valid 11-digit Nigerian mobile number."""
    if not NIGERIAN_PHONE_RE.match(value):
        raise serializers.ValidationError(
            'Enter a valid Nigerian phone number (e.g. 08012345678).'
        )


class RegisterSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    pin = serializers.CharField(min_length=4, max_length=6, write_only=True)
    first_name = serializers.CharField(max_length=50)
    last_name = serializers.CharField(max_length=50)
    email = serializers.EmailField(required=False, allow_blank=True)

    def validate_phone(self, value):
        value = normalize_phone(value)
        validate_nigerian_phone(value)
        if User.objects.filter(phone=value).exists():
            raise serializers.ValidationError('Phone number already registered.')
        return value

    def validate_pin(self, value):
        if not value.isdigit():
            raise serializers.ValidationError('PIN must contain digits only.')
        return value


class LoginSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    pin = serializers.CharField(write_only=True)

    def validate_phone(self, value):
        return normalize_phone(value)


class OTPRequestSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)

    def validate_phone(self, value):
        value = normalize_phone(value)
        validate_nigerian_phone(value)
        return value


class OTPVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    otp = serializers.CharField(min_length=6, max_length=6)

    def validate_phone(self, value):
        value = normalize_phone(value)
        validate_nigerian_phone(value)
        return value

    def validate_otp(self, value):
        if not value.isdigit():
            raise serializers.ValidationError('OTP must contain digits only.')
        return value


class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email', 'avatar']


class SetTransactionPinSerializer(serializers.Serializer):
    """
    Used for both setting a transaction PIN for the first time and changing it.
    `current_pin` is required only when the user already has a transaction PIN.
    """
    current_pin  = serializers.CharField(min_length=4, max_length=6, write_only=True, required=False)
    new_pin      = serializers.CharField(min_length=4, max_length=6, write_only=True)
    confirm_pin  = serializers.CharField(min_length=4, max_length=6, write_only=True)

    def validate_new_pin(self, value):
        if not value.isdigit():
            raise serializers.ValidationError('Transaction PIN must be digits only.')
        return value

    def validate_current_pin(self, value):
        if value and not value.isdigit():
            raise serializers.ValidationError('Transaction PIN must be digits only.')
        return value

    def validate(self, data):
        if data['new_pin'] != data['confirm_pin']:
            raise serializers.ValidationError({'confirm_pin': 'PINs do not match.'})
        return data
