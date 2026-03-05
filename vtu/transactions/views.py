from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import Transaction
from .serializers import TransactionSerializer


class TransactionListView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = TransactionSerializer

    def get_queryset(self):
        qs = Transaction.objects.filter(user=self.request.user)
        category = self.request.query_params.get('category')
        status = self.request.query_params.get('status')
        if category:
            qs = qs.filter(category=category)
        if status:
            qs = qs.filter(status=status)
        return qs


class SpendingAnalyticsView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, *args, **kwargs):
        from decimal import Decimal
        from django.utils import timezone
        now = timezone.now()
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        debits = Transaction.objects.filter(
            user=request.user, type='debit', status='success'
        )

        spent_today = sum(t.amount for t in debits.filter(created_at__gte=start_of_today))
        spent_month = sum(t.amount for t in debits.filter(created_at__gte=start_of_month))

        # Category breakdown for the month
        breakdown = {}
        for t in debits.filter(created_at__gte=start_of_month):
            breakdown[t.category] = breakdown.get(t.category, Decimal('0.00')) + t.amount

        return Response({
            'spent_today': spent_today,
            'spent_this_month': spent_month,
            'daily_limit': request.user.wallet.daily_limit,
            'monthly_limit': request.user.wallet.monthly_limit,
            'category_breakdown': {k: v for k, v in breakdown.items()}
        })
