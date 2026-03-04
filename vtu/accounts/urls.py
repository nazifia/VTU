from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from .views import RegisterView, LoginView, SendOTPView, VerifyOTPView, LogoutView

urlpatterns = [
    path('register/', RegisterView.as_view(), name='auth-register'),
    path('login/', LoginView.as_view(), name='auth-login'),
    path('logout/', LogoutView.as_view(), name='auth-logout'),
    path('send-otp/', SendOTPView.as_view(), name='auth-send-otp'),
    path('verify-otp/', VerifyOTPView.as_view(), name='auth-verify-otp'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
]
