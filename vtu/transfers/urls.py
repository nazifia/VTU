from django.urls import path
from .views import BankTransferView, VerifyAccountView

urlpatterns = [
    path('bank/', BankTransferView.as_view(), name='transfer-bank'),
    path('verify/', VerifyAccountView.as_view(), name='transfer-verify'),
]
