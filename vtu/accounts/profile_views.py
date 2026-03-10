from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from .serializers import UserSerializer, UpdateProfileSerializer, SetTransactionPinSerializer, KycSerializer


class ProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return UpdateProfileSerializer
        return UserSerializer

    def get_object(self):
        return self.request.user

    def patch(self, request, *args, **kwargs):
        serializer = UpdateProfileSerializer(
            self.request.user, data=request.data, partial=True,
            context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserSerializer(self.request.user, context={'request': request}).data)


class SetTransactionPinView(APIView):
    """
    Set or change the transaction PIN (separate from the login password).

    First-time setup  → send `new_pin` + `confirm_pin`.
    Changing the PIN  → send `current_pin` + `new_pin` + `confirm_pin`.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        s = SetTransactionPinSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        user = request.user

        if user.has_transaction_pin:
            current_pin = s.validated_data.get('current_pin')
            if not current_pin:
                return Response(
                    {'detail': 'current_pin is required to change your transaction PIN.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if not user.check_transaction_pin(current_pin):
                return Response(
                    {'detail': 'Current transaction PIN is incorrect.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        user.set_transaction_pin(s.validated_data['new_pin'])
        user.save(update_fields=['transaction_pin'])
        return Response(
            {'detail': 'Transaction PIN set successfully.'},
            status=status.HTTP_200_OK,
        )


class KycView(APIView):
    """
    Link BVN and/or NIN to the authenticated user's account.

    POST  { "bvn": "12345678901" }
    POST  { "nin": "12345678901" }
    POST  { "bvn": "...", "nin": "..." }

    In dev mode (SiteConfiguration.dev_mode = True) numbers are accepted and
    immediately marked as verified without calling an external API.

    In production, swap the _verify_bvn / _verify_nin stubs with calls to a
    KYC provider (e.g. Paystack Identity, Smile Identity, NIBSS).
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        s = KycSerializer(data=request.data, context={'request': request})
        s.is_valid(raise_exception=True)

        bvn = s.validated_data.get('bvn', '')
        nin = s.validated_data.get('nin', '')
        user = request.user

        from vtu.models import SiteConfiguration
        dev_mode = SiteConfiguration.get().dev_mode

        update_fields = []
        results = {}

        if bvn:
            verified = dev_mode or self._verify_bvn(bvn, user)
            user.bvn = bvn
            user.bvn_verified = verified
            update_fields += ['bvn', 'bvn_verified']
            results['bvn'] = 'verified' if verified else 'pending'

        if nin:
            verified = dev_mode or self._verify_nin(nin, user)
            user.nin = nin
            user.nin_verified = verified
            update_fields += ['nin', 'nin_verified']
            results['nin'] = 'verified' if verified else 'pending'

        user.save(update_fields=update_fields)

        return Response({
            'detail': 'KYC information submitted successfully.',
            'results': results,
            'user': UserSerializer(user, context={'request': request}).data,
        }, status=status.HTTP_200_OK)

    # ── Stub verification methods — replace with real KYC API calls ───────

    def _verify_bvn(self, bvn: str, user) -> bool:
        """
        Production: call Paystack/Smile Identity to verify the BVN matches
        the user's name and date of birth. Return True if verified.
        """
        return False   # pending by default in production

    def _verify_nin(self, nin: str, user) -> bool:
        """
        Production: call NIMC / Smile Identity to verify the NIN.
        Return True if verified.
        """
        return False   # pending by default in production
