import random
from django.utils import timezone
from django.conf import settings
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView
from rest_framework_simplejwt.exceptions import TokenError
from django.contrib.auth import get_user_model, authenticate

from .models import OTP
from .serializers import (
    RegisterSerializer,
    LoginSerializer,
    OTPRequestSerializer,
    OTPVerifySerializer,
    UserSerializer,
    UpdateProfileSerializer,
)
from wallet.models import Wallet

User = get_user_model()

OTP_EXPIRY = getattr(settings, "OTP_EXPIRY_MINUTES", 10)


def _generate_otp():
    if getattr(settings, "DEBUG", False):
        return "123456"
    return str(random.randint(100000, 999999))


def _get_tokens(user):
    refresh = RefreshToken.for_user(user)
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
        "user": UserSerializer(user).data,
    }


# ── Registration ──────────────────────────────────────────────────────────────
class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        user = User.objects.create_user(
            phone=data["phone"],
            pin=data["pin"],
            first_name=data["first_name"],
            last_name=data["last_name"],
            email=data.get("email", ""),
        )
        Wallet.objects.get_or_create(user=user)

        # Generate & save OTP
        code = _generate_otp()
        OTP.objects.create(phone=data["phone"], code=code, purpose="register")

        # In production: send via SMS gateway. For dev, return in response.
        return Response(
            {"message": f"OTP sent to {data['phone']}", "otp": code},
            status=status.HTTP_201_CREATED,
        )


# ── Login ─────────────────────────────────────────────────────────────────────
class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"]
        pin = serializer.validated_data["pin"]

        user = authenticate(request, username=phone, password=pin)

        print(f"Login attempt: phone='{phone}', pin='{pin}'")
        print(f"User found: {user}")

        if user is None:
            return Response(
                {"detail": "Invalid phone number or PIN."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        if not user.is_active:
            return Response(
                {"detail": "Account disabled."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return Response(_get_tokens(user))


# ── OTP: Send ─────────────────────────────────────────────────────────────────
class SendOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = OTPRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"]

        code = _generate_otp()
        OTP.objects.create(phone=phone, code=code, purpose="register")

        # In production: send SMS. For dev, return OTP in response.
        return Response({"message": "OTP sent", "otp": code})


# ── OTP: Verify ───────────────────────────────────────────────────────────────
class VerifyOTPView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = OTPVerifySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone = serializer.validated_data["phone"]
        code = serializer.validated_data["otp"]

        cutoff = timezone.now() - timezone.timedelta(minutes=OTP_EXPIRY)
        otp = OTP.objects.filter(
            phone=phone,
            code=code,
            is_used=False,
            created_at__gte=cutoff,
        ).first()

        if not otp:
            return Response(
                {"detail": "Invalid or expired OTP."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        otp.is_used = True
        otp.save()

        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            return Response(
                {"detail": "Account not found. Please register first."},
                status=status.HTTP_404_NOT_FOUND,
            )
        user.is_verified = True
        user.save()

        return Response(_get_tokens(user))


# ── JWT refresh (reuse simplejwt + blacklist) ─────────────────────────────────
class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            token = RefreshToken(request.data.get("refresh"))
            token.blacklist()
        except (TokenError, KeyError):
            pass
        return Response({"detail": "Logged out."})
