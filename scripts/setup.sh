#!/usr/bin/env bash
# Single-command environment setup for the observability stack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=== DevOps Observability Stack — Setup ==="
echo ""

# ── Prerequisites check ────────────────────────────────────────────────────
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' is not installed or not in PATH."
    exit 1
  fi
  echo "  OK: $1 ($(command -v "$1"))"
}

echo "Checking prerequisites..."
check_cmd docker
echo ""

if ! docker info &>/dev/null; then
  echo "ERROR: Docker daemon is not running. Start Docker Desktop and retry."
  exit 1
fi
echo "  OK: Docker daemon is running"
echo ""

# ── Environment file ───────────────────────────────────────────────────────
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env from .env.example."
  echo "NOTICE: Default admin password is 'admin'. Change GF_SECURITY_ADMIN_PASSWORD for production."
else
  echo ".env already exists — skipping."
fi
echo ""

# ── Build & start ──────────────────────────────────────────────────────────
echo "Building and starting the stack (this may take a minute on first run)..."
docker compose up --build -d
echo ""

# ── Wait for health ────────────────────────────────────────────────────────
echo -n "Waiting for app to become healthy"
timeout 90 bash -c '
  until curl -sf http://localhost:3000/health > /dev/null 2>&1; do
    printf "."
    sleep 3
  done
'
echo " ready."

echo -n "Waiting for Prometheus"
timeout 60 bash -c '
  until curl -sf http://localhost:9090/-/healthy > /dev/null 2>&1; do
    printf "."
    sleep 3
  done
'
echo " ready."
echo ""

# ── Validate ───────────────────────────────────────────────────────────────
bash "$SCRIPT_DIR/validate.sh"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "  App:        http://localhost:3000"
echo "  Grafana:    http://localhost:3001  (admin / admin)"
echo "  Prometheus: http://localhost:9090"
echo "  Loki:       http://localhost:3100"
echo ""
echo "To stop:       docker compose down"
echo "To stop+clean: docker compose down -v"
