from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    full_name = serializers.ReadOnlyField()
    avatar_url = serializers.SerializerMethodField()
    balance = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'phone', 'email', 'first_name', 'last_name',
            'full_name', 'avatar_url', 'is_verified', 'date_joined',
            'balance',
        ]
        read_only_fields = ['id', 'phone', 'is_verified', 'date_joined', 'balance']

    def get_avatar_url(self, obj):
        request = self.context.get('request')
        if obj.avatar and request:
            return request.build_absolute_uri(obj.avatar.url)
        return None

    def get_balance(self, obj):
        try:
            return str(obj.wallet.balance)
        except Exception:
            return '0.00'


class RegisterSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    pin = serializers.CharField(min_length=4, write_only=True)
    first_name = serializers.CharField(max_length=50)
    last_name = serializers.CharField(max_length=50)
    email = serializers.EmailField(required=False, allow_blank=True)

    def validate_phone(self, value):
        # Normalise: strip spaces, ensure starts with 0 or +234
        value = value.strip().replace(' ', '')
        if User.objects.filter(phone=value).exists():
            raise serializers.ValidationError('Phone number already registered.')
        return value


class LoginSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    pin = serializers.CharField(write_only=True)


class OTPRequestSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)


class OTPVerifySerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    otp = serializers.CharField(min_length=6, max_length=6)


class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['first_name', 'last_name', 'email', 'avatar']
