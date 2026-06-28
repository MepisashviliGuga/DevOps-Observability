#!/usr/bin/env bash
# Post-deployment validation — verifies every service responds correctly.
set -euo pipefail

APP_URL="${APP_URL:-http://localhost:3000}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3001}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
LOKI_URL="${LOKI_URL:-http://localhost:3100}"

PASS=0
FAIL=0

check() {
  local name="$1"
  local url="$2"
  local pattern="${3:-}"

  local response
  if ! response=$(curl -sf --max-time 5 "$url" 2>/dev/null); then
    echo "  FAIL  $name  ($url — connection refused or timeout)"
    FAIL=$((FAIL + 1))
    return
  fi

  if [[ -n "$pattern" ]] && ! echo "$response" | grep -q "$pattern"; then
    echo "  FAIL  $name  (expected pattern '$pattern' not found)"
    FAIL=$((FAIL + 1))
    return
  fi

  echo "  PASS  $name"
  PASS=$((PASS + 1))
}

echo "=== Deployment Validation ==="
check "App /health"      "$APP_URL/health"            '"status":"healthy"'
check "App /"            "$APP_URL/"                  '"status":"ok"'
check "App /metrics"     "$APP_URL/metrics"           'app_requests_total'
check "Prometheus"       "$PROMETHEUS_URL/-/healthy"  'Prometheus'
check "Loki /ready"      "$LOKI_URL/ready"            ''
check "Grafana /health"  "$GRAFANA_URL/api/health"    '"database"'
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Result: $PASS passed, $FAIL FAILED"
  exit 1
else
  echo "Result: all $PASS checks passed."
fi
