from django.urls import path
from .views import TransactionListView, SpendingAnalyticsView

urlpatterns = [
    path('', TransactionListView.as_view(), name='transaction-list'),
    path('analytics/', SpendingAnalyticsView.as_view(), name='analytics'),
]
