from django.urls import path, include
from django.contrib import admin
from django.conf import settings
from django.conf.urls.static import static

# ── Admin site branding ───────────────────────────────────────────────────────
admin.site.site_header  = '🏦 VTU Wallet Admin'
admin.site.site_title   = 'VTU Admin'
admin.site.index_title  = 'VTU Wallet — Control Panel'

api_v1_patterns = [
    path('auth/',         include('accounts.urls')),
    path('user/',         include('accounts.user_urls')),
    path('wallet/',       include('wallet.urls')),
    path('payment/',      include('wallet.urls')),   # card initiation + webhook
    path('transactions/', include('transactions.urls')),
    path('vtu/',          include('vtu.vtu_urls')),
    path('transfer/',     include('transfers.urls')),
]

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/', include(api_v1_patterns)),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

