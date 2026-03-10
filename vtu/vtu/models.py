from django.db import models


class SiteConfiguration(models.Model):
    """
    Singleton model — only one row ever exists (pk=1).
    Manage all app-wide feature flags from the Django admin.
    """

    # ── OTP / Auth test helpers ────────────────────────────────────────────────
    show_otp_in_response = models.BooleanField(
        default=True,
        verbose_name='Show OTP in API response',
        help_text=(
            'Return the OTP code in the register / send-otp response body. '
            'Turn OFF in production once an SMS gateway is configured.'
        ),
    )
    use_fixed_otp = models.BooleanField(
        default=True,
        verbose_name='Use fixed OTP (testing)',
        help_text='Always generate the fixed OTP value below instead of a random code.',
    )
    fixed_otp_value = models.CharField(
        max_length=6,
        default='123456',
        verbose_name='Fixed OTP value',
        help_text='The hardcoded OTP used when "Use fixed OTP" is ON. Must be 6 digits.',
    )

    # ── Maintenance / feature flags ────────────────────────────────────────────
    maintenance_mode = models.BooleanField(
        default=False,
        verbose_name='Maintenance mode',
        help_text=(
            'Block all financial transactions (VTU, transfers, wallet funding) '
            'and return a 503 response with a maintenance message.'
        ),
    )
    maintenance_message = models.CharField(
        max_length=255,
        default='The system is currently under maintenance. Please try again later.',
        verbose_name='Maintenance message',
        help_text='Message returned to users when maintenance mode is active.',
    )

    class Meta:
        verbose_name = 'Site Configuration'
        verbose_name_plural = 'Site Configuration'

    def __str__(self):
        return 'Site Configuration'

    # ── Singleton enforcement ──────────────────────────────────────────────────

    def save(self, *args, **kwargs):
        self.pk = 1
        super().save(*args, **kwargs)

    def delete(self, *args, **kwargs):
        pass  # prevent deletion

    @classmethod
    def get(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj
