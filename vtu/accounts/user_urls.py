from django.urls import path
from .profile_views import ProfileView, SetTransactionPinView

urlpatterns = [
    path('profile/',             ProfileView.as_view(),           name='user-profile'),
    path('set-transaction-pin/', SetTransactionPinView.as_view(), name='set-transaction-pin'),
]
