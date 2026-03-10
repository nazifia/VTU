from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils.html import format_html, mark_safe
from django.urls import reverse
from django.db.models import Sum, Count, Q
from django.utils import timezone
from .models import User, OTP


# ── Inline: Wallet (shown inside User detail page) ───────────────────────────
class WalletInline(admin.StackedInline):
    """Lets admins see and edit a user's wallet balance directly on the User page."""
    from wallet.models import Wallet
    model = Wallet
    extra = 0
    fields = ('balance', 'updated_at')
    readonly_fields = ('updated_at',)
    can_delete = False


# ── Inline: Recent transactions (shown inside User detail page) ──────────────
class TransactionInline(admin.TabularInline):
    from transactions.models import Transaction
    model = Transaction
    extra = 0
    fields = ('reference', 'type', 'category', 'amount', 'status', 'created_at')
    readonly_fields = fields
    can_delete = False
    max_num = 10
    ordering = ('-created_at',)
    show_change_link = True
    verbose_name = 'Recent Transaction'
    verbose_name_plural = 'Recent Transactions (last 10)'


# ── User Admin ────────────────────────────────────────────────────────────────
@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ['-date_joined']
    list_display = [
        'phone', 'full_name', 'email',
        'wallet_balance_display',
        'is_verified', 'is_active', 'is_staff',
        'txn_pin_set_display',
        'kyc_status_display',
        'transaction_count_display',
        'date_joined',
    ]
    list_filter = ['is_verified', 'is_staff', 'is_active', 'date_joined']
    search_fields = ['phone', 'first_name', 'last_name', 'email']
    readonly_fields = ['id', 'date_joined', 'wallet_balance_display', 'transaction_summary', 'bvn', 'nin']
    inlines = [WalletInline, TransactionInline]

    fieldsets = (
        ('Account', {
            'fields': ('id', 'phone', 'password'),
        }),
        ('Personal Info', {
            'fields': ('first_name', 'last_name', 'email', 'avatar'),
        }),
        ('Status', {
            'fields': ('is_active', 'is_verified', 'is_staff', 'is_superuser'),
        }),
        ('KYC / Identity', {
            'description': 'BVN and NIN linked by the user. Tick *_verified to manually approve.',
            'fields': ('bvn', 'bvn_verified', 'nin', 'nin_verified'),
        }),
        ('Permissions', {
            'classes': ('collapse',),
            'fields': ('groups', 'user_permissions'),
        }),
        ('Wallet Summary', {
            'fields': ('wallet_balance_display', 'transaction_summary'),
        }),
        ('Timestamps', {
            'fields': ('date_joined',),
        }),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('phone', 'first_name', 'last_name', 'email', 'password1', 'password2'),
        }),
        ('Permissions', {
            'classes': ('wide',),
            'fields': ('is_active', 'is_verified', 'is_staff', 'is_superuser'),
        }),
    )

    actions = ['verify_users', 'deactivate_users', 'activate_users', 'approve_kyc', 'revoke_kyc']

    # ── Custom list columns ──────────────────────────────────────────────────

    @admin.display(description='KYC')
    def kyc_status_display(self, obj):
        bvn_icon = '✅' if obj.bvn_verified else ('⏳' if obj.bvn else '—')
        nin_icon = '✅' if obj.nin_verified else ('⏳' if obj.nin else '—')
        return format_html(
            '<span title="BVN">B:{}</span> <span title="NIN">N:{}</span>',
            bvn_icon, nin_icon,
        )

    @admin.display(description='Txn PIN')
    def txn_pin_set_display(self, obj):
        if obj.has_transaction_pin:
            return mark_safe('<span style="color:#10B981; font-weight:700;">&#10003; Set</span>')
        return mark_safe('<span style="color:#EF4444;">&#10007; Not set</span>')

    @admin.display(description='Wallet Balance', ordering='wallet__balance')
    def wallet_balance_display(self, obj):
        try:
            bal = obj.wallet.balance
            color = '#10B981' if bal > 0 else '#6B7280'
            return format_html(
                '<span style="color:{}; font-weight:700;">₦{}</span>',
                color, f"{bal:,.2f}",
            )
        except Exception:
            return mark_safe('<span style="color:#EF4444;">No wallet</span>')

    @admin.display(description='Transactions')
    def transaction_count_display(self, obj):
        count = obj.transactions.count()
        url = (
            reverse('admin:transactions_transaction_changelist')
            + f'?user__id__exact={obj.id}'
        )
        return format_html('<a href="{}">{} txns</a>', url, count)

    @admin.display(description='Transaction Summary')
    def transaction_summary(self, obj):
        agg = obj.transactions.aggregate(
            total=Count('id'),
            credit_sum=Sum('amount', filter=Q(type='credit')),
            debit_sum=Sum('amount', filter=Q(type='debit')),
            success=Count('id', filter=Q(status='success')),
            failed=Count('id', filter=Q(status='failed')),
        )
        return format_html(
            '<table style="font-size:13px; line-height:1.8;">'
            '<tr><td><b>Total Transactions</b></td><td>{}</td></tr>'
            '<tr><td><b>Total Credits</b></td><td style="color:#10B981;">₦{}</td></tr>'
            '<tr><td><b>Total Debits</b></td><td style="color:#EF4444;">₦{}</td></tr>'
            '<tr><td><b>Successful</b></td><td>{}</td></tr>'
            '<tr><td><b>Failed</b></td><td>{}</td></tr>'
            '</table>',
            agg['total'] or 0,
            f"{agg['credit_sum'] or 0:,.2f}",
            f"{agg['debit_sum'] or 0:,.2f}",
            agg['success'] or 0,
            agg['failed'] or 0,
        )

    # ── Bulk actions ─────────────────────────────────────────────────────────

    @admin.action(description='🪪 Approve KYC (BVN + NIN) for selected users')
    def approve_kyc(self, request, queryset):
        updated = queryset.filter(bvn__isnull=False).update(bvn_verified=True)
        updated += queryset.filter(nin__isnull=False).update(nin_verified=True)
        self.message_user(request, f'KYC approved for {queryset.count()} user(s).')

    @admin.action(description='❌ Revoke KYC for selected users')
    def revoke_kyc(self, request, queryset):
        queryset.update(bvn_verified=False, nin_verified=False)
        self.message_user(request, f'KYC revoked for {queryset.count()} user(s).')

    @admin.action(description='✅ Mark selected users as verified')
    def verify_users(self, request, queryset):
        updated = queryset.filter(is_verified=False).update(is_verified=True)
        self.message_user(request, f'{updated} user(s) marked as verified.')

    @admin.action(description='🔴 Deactivate selected users')
    def deactivate_users(self, request, queryset):
        updated = queryset.update(is_active=False)
        self.message_user(request, f'{updated} user(s) deactivated.')

    @admin.action(description='🟢 Activate selected users')
    def activate_users(self, request, queryset):
        updated = queryset.update(is_active=True)
        self.message_user(request, f'{updated} user(s) activated.')

    def get_queryset(self, request):
        return (
            super().get_queryset(request)
            .prefetch_related('transactions')
            .select_related('wallet')
        )


# ── OTP Admin ─────────────────────────────────────────────────────────────────
@admin.register(OTP)
class OTPAdmin(admin.ModelAdmin):
    list_display = ['phone', 'code', 'purpose', 'is_used', 'age_display', 'created_at']
    list_filter = ['purpose', 'is_used']
    search_fields = ['phone']
    readonly_fields = ['phone', 'code', 'purpose', 'created_at']
    ordering = ['-created_at']
    actions = ['mark_used', 'delete_expired']

    @admin.display(description='Age')
    def age_display(self, obj):
        diff = timezone.now() - obj.created_at
        minutes = int(diff.total_seconds() / 60)
        if minutes < 60:
            return f'{minutes}m ago'
        if minutes < 1440:
            return f'{minutes // 60}h ago'
        return f'{minutes // 1440}d ago'

    @admin.action(description='Mark selected OTPs as used')
    def mark_used(self, request, queryset):
        updated = queryset.update(is_used=True)
        self.message_user(request, f'{updated} OTP(s) marked as used.')

    @admin.action(description='🗑️ Delete OTPs older than 24 hours')
    def delete_expired(self, request, queryset):
        cutoff = timezone.now() - timezone.timedelta(hours=24)
        deleted, _ = OTP.objects.filter(created_at__lt=cutoff).delete()
        self.message_user(request, f'{deleted} expired OTP(s) deleted.')
