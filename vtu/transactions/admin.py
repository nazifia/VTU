import csv
from decimal import Decimal
from django.contrib import admin
from django.contrib import messages
from django.http import HttpResponse
from django.utils.html import format_html
from django.urls import reverse
from django.db.models import Sum, Count, Q
from django.utils import timezone
from .models import Transaction


# ── Custom list filter for amount ranges ──────────────────────────────────────
class AmountRangeFilter(admin.SimpleListFilter):
    title = 'Amount Range'
    parameter_name = 'amount_range'

    def lookups(self, request, model_admin):
        return [
            ('micro', 'Under ₦100'),
            ('small', '₦100 – ₦999'),
            ('medium', '₦1,000 – ₦9,999'),
            ('large', '₦10,000 – ₦99,999'),
            ('xlarge', '₦100,000+'),
        ]

    def queryset(self, request, queryset):
        match self.value():
            case 'micro':   return queryset.filter(amount__lt=100)
            case 'small':   return queryset.filter(amount__gte=100,    amount__lt=1000)
            case 'medium':  return queryset.filter(amount__gte=1000,   amount__lt=10000)
            case 'large':   return queryset.filter(amount__gte=10000,  amount__lt=100000)
            case 'xlarge':  return queryset.filter(amount__gte=100000)
        return queryset


# ── Custom date filter ────────────────────────────────────────────────────────
class DateRangeFilter(admin.SimpleListFilter):
    title = 'Date Range'
    parameter_name = 'date_range'

    def lookups(self, request, model_admin):
        return [
            ('today',    'Today'),
            ('week',     'Last 7 days'),
            ('month',    'Last 30 days'),
            ('quarter',  'Last 90 days'),
        ]

    def queryset(self, request, queryset):
        now = timezone.now()
        match self.value():
            case 'today':   return queryset.filter(created_at__date=now.date())
            case 'week':    return queryset.filter(created_at__gte=now - timezone.timedelta(days=7))
            case 'month':   return queryset.filter(created_at__gte=now - timezone.timedelta(days=30))
            case 'quarter': return queryset.filter(created_at__gte=now - timezone.timedelta(days=90))
        return queryset


# ── Transaction Admin ─────────────────────────────────────────────────────────
@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = [
        'reference_display',
        'user_link',
        'type_badge',
        'category_display',
        'amount_display',
        'status_badge',
        'created_at',
    ]
    list_filter = [
        'status',
        'type',
        'category',
        DateRangeFilter,
        AmountRangeFilter,
    ]
    search_fields = ['reference', 'user__phone', 'user__first_name',
                     'user__last_name', 'description']
    readonly_fields = [
        'id', 'user', 'type', 'category', 'amount',
        'reference', 'status', 'description', 'metadata', 'created_at',
        'user_wallet_link',
    ]
    ordering = ['-created_at']
    date_hierarchy = 'created_at'
    list_per_page = 50

    fieldsets = (
        ('Transaction Info', {
            'fields': ('id', 'reference', 'type', 'category', 'status'),
        }),
        ('Financial', {
            'fields': ('amount', 'description'),
        }),
        ('User', {
            'fields': ('user', 'user_wallet_link'),
        }),
        ('Metadata', {
            'classes': ('collapse',),
            'fields': ('metadata',),
        }),
        ('Timestamps', {
            'fields': ('created_at',),
        }),
    )

    actions = [
        'mark_success',
        'mark_failed',
        'refund_to_wallet',
        'export_csv',
    ]

    # ── List columns ──────────────────────────────────────────────────────────

    @admin.display(description='Reference', ordering='reference')
    def reference_display(self, obj):
        return format_html(
            '<code style="font-size:11px;">{}</code>', obj.reference
        )

    @admin.display(description='User', ordering='user__phone')
    def user_link(self, obj):
        url = reverse('admin:accounts_user_change', args=[obj.user.pk])
        return format_html(
            '<a href="{}">{}</a><br>'
            '<small style="color:#6B7280;">{}</small>',
            url, obj.user.phone, obj.user.full_name,
        )

    @admin.display(description='Type', ordering='type')
    def type_badge(self, obj):
        colors = {'credit': ('#D1FAE5', '#065F46'), 'debit': ('#FEE2E2', '#991B1B')}
        bg, fg = colors.get(obj.type, ('#F3F4F6', '#374151'))
        symbol = '+' if obj.type == 'credit' else '-'
        return format_html(
            '<span style="background:{};color:{};padding:2px 8px;'
            'border-radius:12px;font-size:11px;font-weight:700;">'
            '{} {}</span>',
            bg, fg, symbol, obj.type.upper(),
        )

    @admin.display(description='Category', ordering='category')
    def category_display(self, obj):
        icons = {
            'airtime': '📱',
            'data': '📶',
            'electricity': '⚡',
            'cable_tv': '📺',
            'water': '💧',
            'bank_transfer': '🏦',
            'wallet_funding': '💰',
            'other': '📋',
        }
        icon = icons.get(obj.category, '📋')
        label = obj.get_category_display()
        return format_html('{}&nbsp;{}', icon, label)

    @admin.display(description='Amount', ordering='amount')
    def amount_display(self, obj):
        color = '#10B981' if obj.type == 'credit' else '#EF4444'
        prefix = '+' if obj.type == 'credit' else '-'
        return format_html(
            '<strong style="color:{};">{}₦{}</strong>',
            color, prefix, f"{obj.amount:,.2f}",
        )

    @admin.display(description='Status', ordering='status')
    def status_badge(self, obj):
        styles = {
            'success': ('#D1FAE5', '#065F46', '✅'),
            'pending': ('#FEF3C7', '#92400E', '⏳'),
            'failed':  ('#FEE2E2', '#991B1B', '❌'),
        }
        bg, fg, icon = styles.get(obj.status, ('#F3F4F6', '#374151', '❓'))
        return format_html(
            '<span style="background:{};color:{};padding:2px 10px;'
            'border-radius:12px;font-size:11px;font-weight:600;">'
            '{} {}</span>',
            bg, fg, icon, obj.status.upper(),
        )

    @admin.display(description='Wallet')
    def user_wallet_link(self, obj):
        try:
            url = reverse('admin:wallet_wallet_change', args=[obj.user.wallet.pk])
            bal = obj.user.wallet.balance
            return format_html(
                '<a href="{}">View Wallet</a> — Current balance: <strong>₦{:,.2f}</strong>',
                url, bal,
            )
        except Exception:
            return '—'

    # ── Bulk actions ──────────────────────────────────────────────────────────

    @admin.action(description='✅ Mark selected transactions as Success')
    def mark_success(self, request, queryset):
        updated = queryset.exclude(status='success').update(status='success')
        self.message_user(request, f'{updated} transaction(s) marked as success.')

    @admin.action(description='❌ Mark selected transactions as Failed')
    def mark_failed(self, request, queryset):
        updated = queryset.exclude(status='failed').update(status='failed')
        self.message_user(request, f'{updated} transaction(s) marked as failed.')

    @admin.action(description='↩️ Refund selected failed debit transactions to wallet')
    def refund_to_wallet(self, request, queryset):
        import uuid
        eligible = queryset.filter(type='debit', status='failed').select_related('user', 'user__wallet')
        skipped = queryset.exclude(type='debit', status='failed').count()
        refunded = 0
        errors = 0
        for txn in eligible:
            try:
                txn.user.wallet.credit(txn.amount)
                Transaction.objects.create(
                    user=txn.user,
                    type='credit',
                    category='other',
                    amount=txn.amount,
                    reference=f'REFUND-{uuid.uuid4().hex[:12].upper()}',
                    status='success',
                    description=f'Admin refund for failed transaction {txn.reference}',
                    metadata={'refunded_from': str(txn.id)},
                )
                refunded += 1
            except Exception:
                errors += 1
        if refunded:
            self.message_user(request, f'₦ refunded to {refunded} wallet(s) successfully.')
        if skipped:
            self.message_user(
                request,
                f'{skipped} transaction(s) skipped — only failed debit transactions can be refunded.',
                level=messages.WARNING,
            )
        if errors:
            self.message_user(request, f'{errors} refund(s) failed.', level=messages.ERROR)

    @admin.action(description='📥 Export selected transactions to CSV')
    def export_csv(self, request, queryset):
        response = HttpResponse(content_type='text/csv')
        ts = timezone.now().strftime('%Y%m%d_%H%M')
        response['Content-Disposition'] = f'attachment; filename="transactions_{ts}.csv"'

        writer = csv.writer(response)
        writer.writerow([
            'ID', 'Reference', 'User Phone', 'User Name',
            'Type', 'Category', 'Amount', 'Status',
            'Description', 'Created At',
        ])
        for t in queryset.select_related('user'):
            writer.writerow([
                str(t.id), t.reference,
                t.user.phone, t.user.full_name,
                t.type, t.category, str(t.amount), t.status,
                t.description, t.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            ])
        self.message_user(
            request,
            f'Exported {queryset.count()} transactions to CSV.',
            messages.SUCCESS,
        )
        return response

    def get_queryset(self, request):
        return super().get_queryset(request).select_related('user', 'user__wallet')

    # ── Summary stats in the changelist header ────────────────────────────────
    def changelist_view(self, request, extra_context=None):
        qs = self.get_queryset(request)
        # Apply active filters so stats reflect what the admin sees.
        try:
            cl = self.get_changelist_instance(request)
            qs = cl.queryset
        except Exception:
            pass

        agg = qs.aggregate(
            total=Count('id'),
            credit_sum=Sum('amount', filter=Q(type='credit')),
            debit_sum=Sum('amount', filter=Q(type='debit')),
            success_count=Count('id', filter=Q(status='success')),
            failed_count=Count('id', filter=Q(status='failed')),
        )
        extra_context = extra_context or {}
        extra_context['summary'] = {
            'total':         agg['total'] or 0,
            'credit_sum':    f"₦{agg['credit_sum'] or 0:,.2f}",
            'debit_sum':     f"₦{agg['debit_sum'] or 0:,.2f}",
            'success_count': agg['success_count'] or 0,
            'failed_count':  agg['failed_count'] or 0,
        }
        return super().changelist_view(request, extra_context=extra_context)

