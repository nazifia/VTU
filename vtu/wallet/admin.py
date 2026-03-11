import csv
import uuid
from decimal import Decimal
from django import forms
from django.contrib import admin
from django.contrib.admin import helpers
from django.http import HttpResponse
from django.shortcuts import render
from django.utils.html import format_html
from django.urls import reverse
from django.db.models import Sum, Count, Q
from django.utils import timezone
from .models import Wallet
from transactions.models import Transaction


# ── Balance range filter ───────────────────────────────────────────────────────
class BalanceRangeFilter(admin.SimpleListFilter):
    title = 'Balance Range'
    parameter_name = 'balance_range'

    def lookups(self, request, model_admin):
        return [
            ('zero',   '₦0 (empty)'),
            ('low',    '₦1 – ₦999'),
            ('medium', '₦1,000 – ₦9,999'),
            ('high',   '₦10,000 – ₦99,999'),
            ('rich',   '₦100,000+'),
        ]

    def queryset(self, request, queryset):
        match self.value():
            case 'zero':   return queryset.filter(balance=0)
            case 'low':    return queryset.filter(balance__gt=0, balance__lt=1000)
            case 'medium': return queryset.filter(balance__gte=1000, balance__lt=10000)
            case 'high':   return queryset.filter(balance__gte=10000, balance__lt=100000)
            case 'rich':   return queryset.filter(balance__gte=100000)
        return queryset


# ── Credit-custom form ─────────────────────────────────────────────────────────
class _CreditForm(forms.Form):
    amount = forms.DecimalField(
        min_value=Decimal('1'), max_digits=12, decimal_places=2,
        label='Amount (₦)',
        widget=forms.NumberInput(attrs={'step': '0.01', 'min': '1', 'style': 'width:200px;'}),
    )
    description = forms.CharField(
        max_length=200, required=False, label='Description (optional)',
        widget=forms.TextInput(attrs={'placeholder': 'e.g. Promo top-up, bonus credit'}),
    )


@admin.register(Wallet)
class WalletAdmin(admin.ModelAdmin):
    list_display = [
        'user_phone', 'user_full_name',
        'balance_display', 'updated_at',
        'credit_total_display', 'debit_total_display',
        'limits_display',
        'view_transactions_link',
    ]
    list_filter = ['updated_at', BalanceRangeFilter]
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

    actions = [
        'credit_custom',
        'credit_100', 'credit_500', 'credit_1000',
        'credit_5000', 'credit_10000', 'credit_50000',
        'zero_balance', 'reset_limits',
        'export_wallets_csv',
    ]

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
            airtime=Count('id', filter=Q(category='airtime')),
            data=Count('id', filter=Q(category='data')),
            electricity=Count('id', filter=Q(category='electricity')),
            cable_tv=Count('id', filter=Q(category='cable_tv')),
            water=Count('id', filter=Q(category='water')),
            bank_transfer=Count('id', filter=Q(category='bank_transfer')),
        )
        return format_html(
            '<table style="font-size:13px; line-height:2; border-collapse:collapse; min-width:320px;">'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td style="padding:4px 16px 4px 0;"><b>Total Transactions</b></td><td>{}</td></tr>'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td><b>Credits</b></td><td style="color:#10B981;">{} (₦{})</td></tr>'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td><b>Debits</b></td><td style="color:#EF4444;">{} (₦{})</td></tr>'
            '<tr style="border-bottom:1px solid #e5e7eb;">'
            '  <td><b>Successful / Failed / Pending</b></td>'
            '  <td><span style="color:#10B981;">{}</span> / '
            '      <span style="color:#EF4444;">{}</span> / '
            '      <span style="color:#F59E0B;">{}</span></td></tr>'
            '<tr><td colspan="2" style="padding-top:8px; font-weight:600;">By category:</td></tr>'
            '<tr><td>📱 Airtime</td><td>{}</td></tr>'
            '<tr><td>📶 Data</td><td>{}</td></tr>'
            '<tr><td>⚡ Electricity</td><td>{}</td></tr>'
            '<tr><td>📺 Cable TV</td><td>{}</td></tr>'
            '<tr><td>💧 Water</td><td>{}</td></tr>'
            '<tr><td>🏦 Bank Transfer</td><td>{}</td></tr>'
            '</table>',
            agg['total'] or 0,
            agg['credits'] or 0, f"{agg['credit_sum'] or 0:,.2f}",
            agg['debits'] or 0, f"{agg['debit_sum'] or 0:,.2f}",
            agg['success'] or 0, agg['failed'] or 0, agg['pending'] or 0,
            agg['airtime'] or 0,
            agg['data'] or 0,
            agg['electricity'] or 0,
            agg['cable_tv'] or 0,
            agg['water'] or 0,
            agg['bank_transfer'] or 0,
        )

    # ── Internal credit helper ─────────────────────────────────────────────────

    def _credit_wallets(self, request, queryset, amount: Decimal, label: str):
        count = 0
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

    # ── Credit actions (fixed amounts) ────────────────────────────────────────

    @admin.action(description='💳 Credit ₦100 to selected wallets')
    def credit_100(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('100'), '₦100 admin top-up')

    @admin.action(description='💳 Credit ₦500 to selected wallets')
    def credit_500(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('500'), '₦500 admin top-up')

    @admin.action(description='💳 Credit ₦1,000 to selected wallets')
    def credit_1000(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('1000'), '₦1,000 admin top-up')

    @admin.action(description='💳 Credit ₦5,000 to selected wallets')
    def credit_5000(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('5000'), '₦5,000 admin top-up')

    @admin.action(description='💳 Credit ₦10,000 to selected wallets')
    def credit_10000(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('10000'), '₦10,000 admin top-up')

    @admin.action(description='💳 Credit ₦50,000 to selected wallets')
    def credit_50000(self, request, queryset):
        self._credit_wallets(request, queryset, Decimal('50000'), '₦50,000 admin top-up')

    # ── Credit custom amount (intermediate form page) ─────────────────────────

    @admin.action(description='💰 Credit custom amount to selected wallets')
    def credit_custom(self, request, queryset):
        if 'apply' in request.POST:
            form = _CreditForm(request.POST)
            if form.is_valid():
                amount = form.cleaned_data['amount']
                desc = form.cleaned_data.get('description') or f'Admin credit — ₦{amount:,.2f}'
                count = 0
                for wallet in queryset.select_related('user'):
                    wallet.credit(amount)
                    Transaction.objects.create(
                        user=wallet.user,
                        type='credit',
                        category='wallet_funding',
                        amount=amount,
                        reference=f'ADMIN-CREDIT-{uuid.uuid4().hex[:10].upper()}',
                        status='success',
                        description=desc,
                    )
                    count += 1
                self.message_user(
                    request,
                    f'₦{amount:,.2f} credited to {count} wallet(s).',
                )
                return None  # redirect back to changelist
        else:
            form = _CreditForm()

        return render(request, 'admin/wallet/credit_custom.html', {
            'title': 'Credit Custom Amount',
            'queryset': queryset,
            'form': form,
            'opts': self.model._meta,
            'action_checkbox_name': helpers.ACTION_CHECKBOX_NAME,
        })

    # ── Other bulk actions ────────────────────────────────────────────────────

    @admin.action(description='🔄 Reset spending limits to defaults (₦50k/day, ₦500k/month)')
    def reset_limits(self, request, queryset):
        count = queryset.update(
            daily_limit=Decimal('50000.00'),
            monthly_limit=Decimal('500000.00'),
        )
        self.message_user(request, f'{count} wallet(s) limits reset to default.')

    @admin.action(description='⚠️ Zero out balance of selected wallets')
    def zero_balance(self, request, queryset):
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

    @admin.action(description='📥 Export selected wallets to CSV')
    def export_wallets_csv(self, request, queryset):
        response = HttpResponse(content_type='text/csv')
        ts = timezone.now().strftime('%Y%m%d_%H%M')
        response['Content-Disposition'] = f'attachment; filename="wallets_{ts}.csv"'
        writer = csv.writer(response)
        writer.writerow([
            'Phone', 'Full Name', 'Balance',
            'Daily Limit', 'Monthly Limit', 'Last Updated',
        ])
        for wallet in queryset.select_related('user'):
            writer.writerow([
                wallet.user.phone, wallet.user.full_name,
                str(wallet.balance), str(wallet.daily_limit),
                str(wallet.monthly_limit),
                wallet.updated_at.strftime('%Y-%m-%d %H:%M:%S'),
            ])
        self.message_user(request, f'Exported {queryset.count()} wallets to CSV.')
        return response

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user')
