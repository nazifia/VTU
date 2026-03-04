from django.urls import path
from .vtu_views import AirtimeView, DataView, BillsView, DataPlansView

urlpatterns = [
    path("airtime/", AirtimeView.as_view(), name="vtu-airtime"),
    path("data/", DataView.as_view(), name="vtu-data"),
    path("data/plans/", DataPlansView.as_view(), name="vtu-data-plans"),
    path("bills/", BillsView.as_view(), name="vtu-bills"),
]
