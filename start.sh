#!/usr/bin/env bash
# ── Npay — Start Backend + Frontend ──────────────────────────────────────────
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "  Npay — Starting Backend + Frontend"
echo "========================================"

# ── Backend (Django) ─────────────────────────────────────────────────────────
echo "[1/2] Starting Django backend on http://localhost:8000 ..."
(
  cd "$SCRIPT_DIR/vtu"
  if [ -f env/bin/activate ]; then
    source env/bin/activate
  fi
  python manage.py runserver 0.0.0.0:8000
) &
BACKEND_PID=$!
echo "  Backend PID: $BACKEND_PID"

# Give Django a moment to bind before starting Flutter
sleep 3

# ── Frontend (Flutter Web) ────────────────────────────────────────────────────
echo "[2/2] Starting Flutter web frontend on http://localhost:8080 ..."
(
  cd "$SCRIPT_DIR/vtu_app"
  flutter run -d web-server --web-port 8080 --web-hostname localhost
) &
FRONTEND_PID=$!
echo "  Frontend PID: $FRONTEND_PID"

echo ""
echo "Both services started."
echo "  Backend:  http://localhost:8000/api/v1/"
echo "  Frontend: http://localhost:8080"
echo "  Admin:    http://localhost:8000/admin/"
echo ""
echo "Press Ctrl+C to stop both."

# Wait for either process to exit and then kill both
trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit 0" INT TERM
wait
