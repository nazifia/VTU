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
        from django.utils import timezone
        from django.db.models import Sum
        now = timezone.now()
        start_of_today = now.replace(hour=0, minute=0, second=0, microsecond=0)
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        debits = Transaction.objects.filter(
            user=request.user, type='debit', status='success'
        )

        spent_today = debits.filter(created_at__gte=start_of_today).aggregate(
            total=Sum('amount')
        )['total'] or 0

        spent_month = debits.filter(created_at__gte=start_of_month).aggregate(
            total=Sum('amount')
        )['total'] or 0

        breakdown_qs = debits.filter(created_at__gte=start_of_month).values(
            'category'
        ).annotate(total=Sum('amount'))
        breakdown = {row['category']: str(row['total']) for row in breakdown_qs}

        return Response({
            'spent_today': str(spent_today),
            'spent_this_month': str(spent_month),
            'daily_limit': str(request.user.wallet.daily_limit),
            'monthly_limit': str(request.user.wallet.monthly_limit),
            'category_breakdown': breakdown,
        })
