import uuid
from decimal import Decimal
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework import serializers, status
from transactions.models import Transaction


# ── Serializers ───────────────────────────────────────────────────────────────
class AirtimeSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    provider = serializers.ChoiceField(choices=["MTN", "Glo", "Airtel", "9mobile"])
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=10)


class DataSerializer(serializers.Serializer):
    phone = serializers.CharField(max_length=15)
    provider = serializers.ChoiceField(choices=["MTN", "Glo", "Airtel", "9mobile"])
    plan_id = serializers.CharField(max_length=50)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=50)


class BillsSerializer(serializers.Serializer):
    BILL_TYPES = ["electricity", "cable_tv", "water"]
    bill_type = serializers.ChoiceField(choices=BILL_TYPES)
    provider = serializers.CharField(max_length=100)
    account_number = serializers.CharField(max_length=50)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=100)
    metadata = serializers.JSONField(required=False, default=dict)


# ── Data Plans ───────────────────────────────────────────────────────────────
DATA_PLANS = [
    {
        "id": "mtn_500mb_1day",
        "provider": "MTN",
        "size": "500MB",
        "price": 100,
        "validity": "1 Day",
    },
    {
        "id": "mtn_1gb_7days",
        "provider": "MTN",
        "size": "1GB",
        "price": 200,
        "validity": "7 Days",
    },
    {
        "id": "mtn_2gb_30days",
        "provider": "MTN",
        "size": "2GB",
        "price": 500,
        "validity": "30 Days",
    },
    {
        "id": "mtn_5gb_30days",
        "provider": "MTN",
        "size": "5GB",
        "price": 1000,
        "validity": "30 Days",
    },
    {
        "id": "mtn_10gb_30days",
        "provider": "MTN",
        "size": "10GB",
        "price": 2000,
        "validity": "30 Days",
    },
    {
        "id": "mtn_20gb_30days",
        "provider": "MTN",
        "size": "20GB",
        "price": 3500,
        "validity": "30 Days",
    },
    {
        "id": "glo_500mb_1day",
        "provider": "Glo",
        "size": "500MB",
        "price": 100,
        "validity": "1 Day",
    },
    {
        "id": "glo_1gb_7days",
        "provider": "Glo",
        "size": "1GB",
        "price": 200,
        "validity": "7 Days",
    },
    {
        "id": "glo_2gb_30days",
        "provider": "Glo",
        "size": "2GB",
        "price": 500,
        "validity": "30 Days",
    },
    {
        "id": "glo_5gb_30days",
        "provider": "Glo",
        "size": "5GB",
        "price": 1000,
        "validity": "30 Days",
    },
    {
        "id": "glo_10gb_30days",
        "provider": "Glo",
        "size": "10GB",
        "price": 2000,
        "validity": "30 Days",
    },
    {
        "id": "airtel_500mb_1day",
        "provider": "Airtel",
        "size": "500MB",
        "price": 100,
        "validity": "1 Day",
    },
    {
        "id": "airtel_1gb_7days",
        "provider": "Airtel",
        "size": "1GB",
        "price": 200,
        "validity": "7 Days",
    },
    {
        "id": "airtel_2gb_30days",
        "provider": "Airtel",
        "size": "2GB",
        "price": 500,
        "validity": "30 Days",
    },
    {
        "id": "airtel_5gb_30days",
        "provider": "Airtel",
        "size": "5GB",
        "price": 1000,
        "validity": "30 Days",
    },
    {
        "id": "airtel_10gb_30days",
        "provider": "Airtel",
        "size": "10GB",
        "price": 2000,
        "validity": "30 Days",
    },
    {
        "id": "9mobile_500mb_1day",
        "provider": "9mobile",
        "size": "500MB",
        "price": 100,
        "validity": "1 Day",
    },
    {
        "id": "9mobile_1gb_7days",
        "provider": "9mobile",
        "size": "1GB",
        "price": 200,
        "validity": "7 Days",
    },
    {
        "id": "9mobile_2gb_30days",
        "provider": "9mobile",
        "size": "2GB",
        "price": 500,
        "validity": "30 Days",
    },
    {
        "id": "9mobile_5gb_30days",
        "provider": "9mobile",
        "size": "5GB",
        "price": 1000,
        "validity": "30 Days",
    },
]


# ── Helpers ───────────────────────────────────────────────────────────────────
def _ref(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:12].upper()}"


def _process_vtu(
    user, amount: Decimal, category: str, description: str, metadata: dict
):
    """Debit wallet and record transaction."""
    wallet = user.wallet
    wallet.debit(amount)  # raises ValueError on insufficient funds

    ref = _ref(category[:3].upper())
    Transaction.objects.create(
        user=user,
        type="debit",
        category=category,
        amount=amount,
        reference=ref,
        status="success",
        description=description,
        metadata=metadata,
    )
    return ref


# ── Views ─────────────────────────────────────────────────────────────────────
class AirtimeView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        s = AirtimeSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        try:
            ref = _process_vtu(
                user=request.user,
                amount=d["amount"],
                category="airtime",
                description=f"{d['provider']} airtime – {d['phone']}",
                metadata={"phone": d["phone"], "provider": d["provider"]},
            )
        except ValueError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(
            {
                "status": "success",
                "message": f"₦{d['amount']} {d['provider']} airtime sent to {d['phone']}",
                "reference": ref,
            }
        )


class DataView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        s = DataSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        try:
            ref = _process_vtu(
                user=request.user,
                amount=d["amount"],
                category="data",
                description=f"{d['provider']} data – {d['phone']}",
                metadata={
                    "phone": d["phone"],
                    "provider": d["provider"],
                    "plan_id": d["plan_id"],
                },
            )
        except ValueError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(
            {
                "status": "success",
                "message": f"Data plan sent to {d['phone']}",
                "reference": ref,
            }
        )


class BillsView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        s = BillsSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        bill_type = d["bill_type"]
        try:
            ref = _process_vtu(
                user=request.user,
                amount=d["amount"],
                category=bill_type,
                description=f"{d['provider']} {bill_type} – {d['account_number']}",
                metadata={
                    "provider": d["provider"],
                    "account_number": d["account_number"],
                    **d.get("metadata", {}),
                },
            )
        except ValueError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
        return Response(
            {
                "status": "success",
                "message": f"{bill_type.replace('_', ' ').title()} payment successful",
                "reference": ref,
            }
        )


class DataPlansView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        provider = request.query_params.get("provider")
        if provider:
            plans = [p for p in DATA_PLANS if p["provider"].lower() == provider.lower()]
        else:
            plans = DATA_PLANS
        return Response({"plans": plans})
