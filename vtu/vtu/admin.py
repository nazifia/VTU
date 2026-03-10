from django.contrib import admin
from django.utils.html import format_html
from .models import SiteConfiguration


@admin.register(SiteConfiguration)
class SiteConfigurationAdmin(admin.ModelAdmin):
    """
    Singleton admin — shows exactly one row and prevents add / delete.
    All flags are editable inline on the detail page.
    """

    fieldsets = (
        ('OTP / Authentication (Testing)', {
            'description': (
                'Control how OTPs are generated and exposed. '
                'Disable these before going live.'
            ),
            'fields': ('show_otp_in_response', 'use_fixed_otp', 'fixed_otp_value'),
        }),
        ('Maintenance', {
            'description': 'Take the payment features offline without a deployment.',
            'fields': ('maintenance_mode', 'maintenance_message'),
        }),
    )

    # ── Status summary in the change-list ─────────────────────────────────────
    list_display = [
        'site_name',
        'otp_in_response_status',
        'fixed_otp_status',
        'maintenance_status',
    ]

    @admin.display(description='Configuration')
    def site_name(self, obj):
        return 'Global Settings'

    @admin.display(description='OTP in response')
    def otp_in_response_status(self, obj):
        if obj.show_otp_in_response:
            return format_html('<span style="color:#F59E0B;font-weight:700;">⚠ ON (dev only)</span>')
        return format_html('<span style="color:#10B981;font-weight:700;">✓ OFF</span>')

    @admin.display(description='Fixed OTP')
    def fixed_otp_status(self, obj):
        if obj.use_fixed_otp:
            return format_html(
                '<span style="color:#F59E0B;font-weight:700;">⚠ {} (dev only)</span>',
                obj.fixed_otp_value,
            )
        return format_html('<span style="color:#10B981;font-weight:700;">✓ Random</span>')

    @admin.display(description='Maintenance')
    def maintenance_status(self, obj):
        if obj.maintenance_mode:
            return format_html('<span style="color:#EF4444;font-weight:700;">🔴 ON</span>')
        return format_html('<span style="color:#10B981;font-weight:700;">🟢 OFF</span>')

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
