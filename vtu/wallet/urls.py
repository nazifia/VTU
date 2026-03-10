from django.urls import path
from .views import (
    WalletDetailView,
    FundWalletView,
    WalletLimitsView,
    VirtualAccountsView,
    InitiateCardPaymentView,
    PaystackWebhookView,
)

urlpatterns = [
    path('', WalletDetailView.as_view(), name='wallet-detail'),
    path('fund/', FundWalletView.as_view(), name='wallet-fund'),
    path('limits/', WalletLimitsView.as_view(), name='wallet-limits'),
    path('virtual-accounts/', VirtualAccountsView.as_view(), name='wallet-virtual-accounts'),
    path('card/initiate/', InitiateCardPaymentView.as_view(), name='card-payment-initiate'),
    path('webhook/paystack/', PaystackWebhookView.as_view(), name='paystack-webhook'),
]
