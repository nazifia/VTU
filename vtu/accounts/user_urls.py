from django.urls import path
from .profile_views import ProfileView

urlpatterns = [
    path('profile/', ProfileView.as_view(), name='user-profile'),
]
