from django.urls import path, include
from django.contrib import admin
from django.conf import settings
from django.conf.urls.static import static
from wallet.views import InitiateCardPaymentView, PaystackWebhookView

# ── Admin site branding ───────────────────────────────────────────────────────
admin.site.site_header  = '🏦 Npay Admin'
admin.site.site_title   = 'Npay Admin'
admin.site.index_title  = 'Npay — Control Panel'

payment_patterns = [
    path('card/initiate/', InitiateCardPaymentView.as_view(), name='card-payment-initiate'),
    path('webhook/paystack/', PaystackWebhookView.as_view(), name='paystack-webhook'),
]

api_v1_patterns = [
    path('auth/',         include('accounts.urls')),
    path('user/',         include('accounts.user_urls')),
    path('wallet/',       include('wallet.urls')),
    path('payment/',      include(payment_patterns)),
    path('transactions/', include('transactions.urls')),
    path('vtu/',          include('vtu.vtu_urls')),
    path('transfer/',     include('transfers.urls')),
]

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/', include(api_v1_patterns)),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

