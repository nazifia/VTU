from django.contrib import admin, messages
from django.contrib.admin import AdminSite
from django.utils.html import format_html, mark_safe
from .models import SiteConfiguration


@admin.register(SiteConfiguration)
class SiteConfigurationAdmin(admin.ModelAdmin):
    """
    Singleton admin — shows exactly one row and prevents add / delete.
    Flip 'Development mode' OFF to switch the entire app to production behaviour.
    """

    fieldsets = (
        ('🔧 Mode', {
            'description': (
                '<strong>Development mode ON</strong> → OTP shown in API responses, '
                'fixed OTP active, CORS open. '
                '<br><strong>Development mode OFF</strong> → production behaviour; '
                'OTP settings below are locked automatically.'
            ),
            'fields': ('dev_mode',),
        }),
        ('OTP / Authentication', {
            'description': 'These are set automatically when you toggle Dev Mode. You can also adjust them individually.',
            'fields': ('show_otp_in_response', 'use_fixed_otp', 'fixed_otp_value'),
        }),
        ('Maintenance', {
            'description': 'Take payment features offline without a deployment.',
            'fields': ('maintenance_mode', 'maintenance_message'),
        }),
    )

    # ── Status summary in the change-list ─────────────────────────────────────
    list_display = [
        'site_name',
        'mode_badge',
        'otp_in_response_status',
        'fixed_otp_status',
        'maintenance_status',
    ]

    actions = ['switch_to_dev_mode', 'switch_to_production_mode', 'toggle_maintenance']

    # ── Column badges ─────────────────────────────────────────────────────────

    @admin.display(description='Configuration')
    def site_name(self, obj):
        return 'Global Settings'

    @admin.display(description='Mode')
    def mode_badge(self, obj):
        if obj.dev_mode:
            return mark_safe(
                '<span style="background:#F59E0B;color:#fff;padding:2px 10px;'
                'border-radius:12px;font-weight:700;font-size:12px;">🔧 DEV</span>'
            )
        return mark_safe(
            '<span style="background:#10B981;color:#fff;padding:2px 10px;'
            'border-radius:12px;font-weight:700;font-size:12px;">🚀 PROD</span>'
        )

    @admin.display(description='OTP in response')
    def otp_in_response_status(self, obj):
        if obj.show_otp_in_response:
            return mark_safe('<span style="color:#F59E0B;font-weight:700;">⚠ ON</span>')
        return mark_safe('<span style="color:#10B981;font-weight:700;">✓ OFF</span>')

    @admin.display(description='Fixed OTP')
    def fixed_otp_status(self, obj):
        if obj.use_fixed_otp:
            return format_html(
                '<span style="color:#F59E0B;font-weight:700;">⚠ {} (fixed)</span>',
                obj.fixed_otp_value,
            )
        return mark_safe('<span style="color:#10B981;font-weight:700;">✓ Random</span>')

    @admin.display(description='Maintenance')
    def maintenance_status(self, obj):
        if obj.maintenance_mode:
            return mark_safe('<span style="color:#EF4444;font-weight:700;">🔴 ON</span>')
        return mark_safe('<span style="color:#10B981;font-weight:700;">🟢 OFF</span>')

    # ── Quick actions ─────────────────────────────────────────────────────────

    @admin.action(description='🔧 Switch to Development mode (show OTP, fixed OTP ON)')
    def switch_to_dev_mode(self, request, queryset):
        cfg = SiteConfiguration.get()
        cfg.dev_mode = True
        cfg.save()
        self.message_user(request, '✅ Switched to Development mode. OTP shown in responses, fixed OTP active.', messages.SUCCESS)

    @admin.action(description='🚀 Switch to Production mode (hide OTP, random OTPs)')
    def switch_to_production_mode(self, request, queryset):
        cfg = SiteConfiguration.get()
        cfg.dev_mode = False
        cfg.save()
        self.message_user(request, '✅ Switched to Production mode. OTP hidden, random OTPs enabled.', messages.SUCCESS)

    @admin.action(description='🔴 Toggle maintenance mode ON/OFF')
    def toggle_maintenance(self, request, queryset):
        cfg = SiteConfiguration.get()
        cfg.maintenance_mode = not cfg.maintenance_mode
        # bypass the dev_mode auto-sync by calling super().save() directly
        SiteConfiguration.objects.filter(pk=1).update(maintenance_mode=cfg.maintenance_mode)
        state = 'ON' if cfg.maintenance_mode else 'OFF'
        self.message_user(request, f'🔴 Maintenance mode is now {state}.', messages.WARNING)

    # ── Singleton: no add, no delete ──────────────────────────────────────────

    def has_add_permission(self, request):
        return not SiteConfiguration.objects.exists()

    def has_delete_permission(self, request, obj=None):
        return False

    def changelist_view(self, request, extra_context=None):
        """Redirect straight to the edit page — no point listing one row."""
        from django.http import HttpResponseRedirect
        from django.urls import reverse
        obj = SiteConfiguration.get()
        return HttpResponseRedirect(
            reverse('admin:vtu_siteconfiguration_change', args=[obj.pk])
        )


# ── Dashboard stats injection ──────────────────────────────────────────────────
# Monkey-patch AdminSite.index to inject platform-wide stats into the
# admin/index.html template context without needing a custom AdminSite subclass.

_orig_index = AdminSite.index


def _npay_index(self, request, extra_context=None):
    from accounts.models import User
    from transactions.models import Transaction
    from wallet.models import Wallet
    from django.db.models import Sum, Count, Q
    from django.utils import timezone

    now = timezone.now()
    today = now.date()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    try:
        u = User.objects.aggregate(
            total=Count('id'),
            verified=Count('id', filter=Q(is_verified=True)),
            unverified=Count('id', filter=Q(is_verified=False)),
            active=Count('id', filter=Q(is_active=True)),
            new_today=Count('id', filter=Q(date_joined__date=today)),
        )
        t = Transaction.objects.aggregate(
            total=Count('id'),
            success=Count('id', filter=Q(status='success')),
            failed=Count('id', filter=Q(status='failed')),
            pending=Count('id', filter=Q(status='pending')),
            today_count=Count('id', filter=Q(created_at__date=today)),
            today_vol=Sum('amount', filter=Q(
                type='debit', status='success', created_at__date=today)),
            month_vol=Sum('amount', filter=Q(
                type='debit', status='success', created_at__gte=month_start)),
            total_funded=Sum('amount', filter=Q(
                type='credit', status='success', category='wallet_funding')),
        )
        w = Wallet.objects.aggregate(total_balance=Sum('balance'))

        cat_breakdown = list(
            Transaction.objects
            .filter(type='debit', status='success', created_at__gte=month_start)
            .values('category')
            .annotate(total=Sum('amount'), count=Count('id'))
            .order_by('-total')
        )

        dashboard = {
            'users_total':      u['total'] or 0,
            'users_verified':   u['verified'] or 0,
            'users_unverified': u['unverified'] or 0,
            'users_active':     u['active'] or 0,
            'users_today':      u['new_today'] or 0,
            'txns_total':       t['total'] or 0,
            'txns_success':     t['success'] or 0,
            'txns_failed':      t['failed'] or 0,
            'txns_pending':     t['pending'] or 0,
            'today_txns':       t['today_count'] or 0,
            'today_volume':     f"₦{t['today_vol'] or 0:,.0f}",
            'month_volume':     f"₦{t['month_vol'] or 0:,.0f}",
            'total_funded':     f"₦{t['total_funded'] or 0:,.0f}",
            'total_balance':    f"₦{w['total_balance'] or 0:,.2f}",
            'category_breakdown': cat_breakdown,
        }
    except Exception:
        dashboard = {}

    ctx = {'npay_dashboard': dashboard}
    if extra_context:
        ctx.update(extra_context)
    return _orig_index(self, request, extra_context=ctx)


AdminSite.index = _npay_index
