#!/usr/bin/env bash
# HTTP smoke against a running path-A Manager (needs Docker + a started stack).
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

URL="${ARCANE_SMOKE_URL:-http://${ARCANE_BIND}:${ARCANE_PORT}}"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found — cannot smoke a running container on this host."
  echo "Would have checked: $URL/api/health (expect JSON with status UP)."
  exit 2
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$ARCANE_CONTAINER_NAME"; then
  echo "ERROR: no running container named $ARCANE_CONTAINER_NAME."
  echo "Start with ./scripts/up-manager.sh after filling local/.env."
  exit 2
fi

echo "# smoke $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "Base: $URL"
echo

for path in / /api/health; do
  code=$(curl -sS -o /tmp/arcane-smoke-body -w '%{http_code}' --max-time 15 "$URL$path" || true)
  printf 'HTTP %s  %s%s\n' "${code:-000}" "$URL" "$path"
  if [[ -s /tmp/arcane-smoke-body ]]; then
    head -c 240 /tmp/arcane-smoke-body | tr '\n' ' '
    echo
  fi
done

echo
echo "A healthy Manager answers /api/health with status UP (official healthcheck is './arcane health')."
echo "First login still needs the password in /app/data/initial-admin-password; that step is out of scope for this smoke."
