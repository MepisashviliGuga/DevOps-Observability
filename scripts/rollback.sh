#!/usr/bin/env bash
# Rollback procedure: re-deploys from git HEAD or a specified commit/tag.
# Usage:  ./scripts/rollback.sh [git-ref]
# Example: ./scripts/rollback.sh v1.2.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TARGET_REF="${1:-HEAD}"

cd "$PROJECT_DIR"

echo "=== Rollback Procedure ==="
echo "Target ref: $TARGET_REF"
echo ""

echo "Current stack status:"
docker compose ps
echo ""

echo "Step 1: Taking down current stack..."
docker compose down
echo ""

echo "Step 2: Checking out $TARGET_REF..."
git stash --include-untracked 2>/dev/null || true
git checkout "$TARGET_REF" -- src/ config/ docker-compose.yml
echo ""

echo "Step 3: Rebuilding and starting from $TARGET_REF..."
docker compose up --build -d
echo ""

echo "Step 4: Waiting for services to be healthy..."
timeout 90 bash -c '
  until curl -sf http://localhost:3000/health > /dev/null 2>&1; do
    printf "."
    sleep 3
  done
'
echo ""

echo "Step 5: Running post-rollback validation..."
bash "$SCRIPT_DIR/validate.sh"

echo ""
echo "Rollback to '$TARGET_REF' completed successfully."
