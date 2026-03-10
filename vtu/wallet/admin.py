from django.contrib import admin
from django.utils.html import format_html
from django.urls import reverse
from django.db.models import Sum, Count, Q
from decimal import Decimal
from .models import Wallet
from transactions.models import Transaction


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = [
        'user_phone', 'user_full_name',
        'balance_display', 'updated_at',
        'credit_total_display', 'debit_total_display',
        'limits_display',
        'view_transactions_link',
    ]
    list_filter = ['updated_at']
    search_fields = ['user__phone', 'user__first_name', 'user__last_name']
    readonly_fields = ['id', 'user', 'updated_at', 'wallet_stats']
    ordering = ['-balance']

    fieldsets = (
        ('Wallet Info', {
            'fields': ('id', 'user', 'balance', 'updated_at'),
        }),
        ('Spending Limits', {
            'description': 'Daily and monthly debit limits enforced on this wallet.',
            'fields': ('daily_limit', 'monthly_limit'),
        }),
        ('Statistics', {
            'fields': ('wallet_stats',),
        }),
    )

    actions = ['credit_100', 'credit_500', 'credit_1000', 'zero_balance', 'reset_limits']

    # ── List columns ──────────────────────────────────────────────────────────

    @admin.display(description='Phone', ordering='user__phone')
    def user_phone(self, obj):
        url = reverse('admin:accounts_user_change', args=[obj.user.pk])
        return format_html('<a href="{}">{}</a>', url, obj.user.phone)

    @admin.display(description='Name', ordering='user__first_name')
    def user_full_name(self, obj):
        return obj.user.full_name

    @admin.display(description='Balance', ordering='balance')
    def balance_display(self, obj):
        color = '#10B981' if obj.balance > 0 else '#6B7280'
        return format_html(
            '<strong style="color:{}; font-size:14px;">₦{}</strong>',
            color, f"{obj.balance:,.2f}",
        )

    @admin.display(description='Total Credits')
    def credit_total_display(self, obj):
        total = obj.user.transactions.filter(type='credit').aggregate(
            s=Sum('amount'))['s'] or Decimal('0')
        return format_html('<span style="color:#10B981;">+₦{}</span>', f"{total:,.2f}")

    @admin.display(description='Total Debits')
    def debit_total_display(self, obj):
        total = obj.user.transactions.filter(type='debit').aggregate(
            s=Sum('amount'))['s'] or Decimal('0')
        return format_html('<span style="color:#EF4444;">-₦{}</span>', f"{total:,.2f}")

    @admin.display(description='Limits (Day / Month)')
    def limits_display(self, obj):
        return format_html(
            '<span style="font-size:12px; color:#6B7280;">₦{} / ₦{}</span>',
            f"{obj.daily_limit:,.0f}",
            f"{obj.monthly_limit:,.0f}",
        )

    @admin.display(description='Transactions')
    def view_transactions_link(self, obj):
        count = obj.user.transactions.count()
        url = (
            reverse('admin:transactions_transaction_changelist')
            + f'?user__id__exact={obj.user.pk}'
        )
        return format_html('<a href="{}">{} txns →</a>', url, count)

    @admin.display(description='Wallet Statistics')
    def wallet_stats(self, obj):
        agg = obj.user.transactions.aggregate(
            total=Count('id'),
            credits=Count('id', filter=Q(type='credit')),
            debits=Count('id', filter=Q(type='debit')),
            credit_sum=Sum('amount', filter=Q(type='credit')),
            debit_sum=Sum('amount', filter=Q(type='debit')),
            success=Count('id', filter=Q(status='success')),
            failed=Count('id', filter=Q(status='failed')),
            pending=Count('id', filter=Q(status='pending')),
        )
        return format_html(
            '<table style="font-size:13px; line-height:2; border-collapse:collapse; min-width:300px;">'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td style="padding:4px 16px 4px 0;"><b>Total Transactions</b></td>'
            '  <td>{}</td></tr>'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td><b>Credit Transactions</b></td>'
            '  <td style="color:#10B981;">{} (₦{})</td></tr>'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td><b>Debit Transactions</b></td>'
            '  <td style="color:#EF4444;">{} (₦{})</td></tr>'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td><b>Successful</b></td>'
            '  <td style="color:#10B981;">{}</td></tr>'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td><b>Failed</b></td>'
            '  <td style="color:#EF4444;">{}</td></tr>'
            '<tr><td><b>Pending</b></td>'
            '  <td style="color:#F59E0B;">{}</td></tr>'
            '</table>',
            agg['total'] or 0,
            agg['credits'] or 0, f"{agg['credit_sum'] or 0:,.2f}",
            agg['debits'] or 0, f"{agg['debit_sum'] or 0:,.2f}",
            agg['success'] or 0,
            agg['failed'] or 0,
            agg['pending'] or 0,
        )

    # ── Bulk actions ──────────────────────────────────────────────────────────

    def _credit_wallets(self, request, queryset, amount: Decimal, label: str):
        """Credit each selected wallet and record a transaction."""
        count = 0
        import uuid
        for wallet in queryset.select_related('user'):
            wallet.credit(amount)
            Transaction.objects.create(
                user=wallet.user,
                type='credit',
                category='wallet_funding',
                amount=amount,
                reference=f'ADMIN-CREDIT-{uuid.uuid4().hex[:10].upper()}',
                status='success',
                description=f'Admin credit — {label}',
            )
            count += 1
        self.message_user(request, f'₦{amount:,.0f} credited to {count} wallet(s).')

    @admin.action(description='💳 Credit ₦100 to selected wallets')
    def credit_100(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('100'), '₦100 admin top-up')

    @admin.action(description='💳 Credit ₦500 to selected wallets')
    def credit_500(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('500'), '₦500 admin top-up')

    @admin.action(description='💳 Credit ₦1,000 to selected wallets')
    def credit_1000(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('1000'), '₦1,000 admin top-up')

    @admin.action(description='🔄 Reset spending limits to defaults (₦50k/day, ₦500k/month)')
    def reset_limits(self, request, queryset):
        count = queryset.update(
            daily_limit=Decimal('50000.00'),
            monthly_limit=Decimal('500000.00'),
        )
        self.message_user(request, f'{count} wallet(s) limits reset to default.')

    @admin.action(description='⚠️ Zero out balance of selected wallets')
    def zero_balance(self, request, queryset):
        import uuid
        count = 0
        for wallet in queryset.select_related('user'):
            if wallet.balance > 0:
                Transaction.objects.create(
                    user=wallet.user,
                    type='debit',
                    category='other',
                    amount=wallet.balance,
                    reference=f'ADMIN-ZERO-{uuid.uuid4().hex[:10].upper()}',
                    status='success',
                    description='Admin balance zero-out',
                )
                wallet.balance = Decimal('0.00')
                wallet.save(update_fields=['balance', 'updated_at'])
                count += 1
        self.message_user(request, f'{count} wallet(s) zeroed.')

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')
