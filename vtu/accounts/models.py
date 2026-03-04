from django.db import models
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.utils import timezone
import uuid


class UserManager(BaseUserManager):
    def create_user(self, phone, pin=None, **extra_fields):
        if not phone:
            raise ValueError('Phone number is required')
        if pin is None:
            raise ValueError('A PIN is required')
        user = self.model(phone=phone, **extra_fields)
        user.set_password(pin)
        user.save(using=self._db)
        # Auto-create linked wallet
        from wallet.models import Wallet
        Wallet.objects.get_or_create(user=user)
        return user

    def create_superuser(self, phone, pin=None, password=None, **extra_fields):
        """Support both `pin` (app flow) and `password` (Django createsuperuser)."""
        actual_pin = pin or password
        if not actual_pin:
            raise ValueError('A PIN/password is required for superuser')
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_verified', True)
        return self.create_user(phone, actual_pin, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone = models.CharField(max_length=15, unique=True)
    email = models.EmailField(blank=True, null=True)
    first_name = models.CharField(max_length=50)
    last_name = models.CharField(max_length=50)
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_verified = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)

    objects = UserManager()

    USERNAME_FIELD = 'phone'
    REQUIRED_FIELDS = ['first_name', 'last_name']  # pin/password is prompted separately by createsuperuser

    class Meta:
        db_table = 'accounts_user'

    @property
    def full_name(self):
        return f'{self.first_name} {self.last_name}'.strip()

    def __str__(self):
        return self.phone


class OTP(models.Model):
    phone = models.CharField(max_length=15)
    code = models.CharField(max_length=6)
    purpose = models.CharField(
        max_length=20,
        choices=[('register', 'Register'), ('login', 'Login'), ('reset', 'Reset')],
        default='register',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    is_used = models.BooleanField(default=False)

    class Meta:
        db_table = 'accounts_otp'
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.phone} – {self.code}'
