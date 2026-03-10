from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from .serializers import UserSerializer, UpdateProfileSerializer, SetTransactionPinSerializer


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
