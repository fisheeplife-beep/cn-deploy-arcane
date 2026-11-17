#!/usr/bin/env bash
# Stop the lab Compose stack. Named volumes are left in place.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found — nothing to stop on this host."
  exit 2
fi

ENVF="$(env_file)"
if [[ -f "$ENVF" ]]; then
  docker compose -f "$ROOT/compose/docker-compose.yml" --env-file "$ENVF" down
else
  docker compose -f "$ROOT/compose/docker-compose.yml" down
fi
echo "Compose stack stopped. Named volume was kept (data is the product)."
echo "To also remove the volume: docker compose -f $ROOT/compose/docker-compose.yml down -v  (this wipes users and settings)."
