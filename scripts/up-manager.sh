#!/usr/bin/env bash
# Pull or start the digest-pinned official v3 Manager (path A, new install).
# Usage:
#   ./scripts/up-manager.sh --pull     # pull only
#   ./scripts/up-manager.sh            # docker compose up -d
#   ./scripts/up-manager.sh --compose  # same as default
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

MODE="compose"
for arg in "$@"; do
  case "$arg" in
    --pull) MODE="pull" ;;
    --compose) MODE="compose" ;;
    -h|--help)
      cat <<'H'
Usage: ./scripts/up-manager.sh [--pull|--compose]
  --pull     docker pull the pinned manager digest, do not start a container
  --compose  docker compose -f compose/docker-compose.yml up -d (default)
Needs Docker. Secrets come from local/.env (never pass keys on the command line).
This is the new-install path. For v2→v3, read docs/migrate-v3.md first.
H
      exit 0
      ;;
    *) die "unknown argument: $arg" ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Path A (pull / compose) is not verifiable on this host."
  echo "Pinned image: $(image_ref)"
  echo "Use ./scripts/probe-images.sh to re-check the index without Docker."
  exit 2
fi

REF="$(image_ref)"
echo "Image: $REF"
echo "Mode:  $MODE"

if [[ "$MODE" == "pull" ]]; then
  docker pull "$REF"
  docker image inspect "$REF" --format '{{.Id}} {{.Architecture}} {{.Os}} {{.Size}}'
  exit 0
fi

ENVF="$(env_file)"
[[ -f "$ENVF" ]] || die "missing $ENVF — copy local/.env.example and run ./scripts/generate-key.sh"
if ! grep -qE '^ARCANE_ENCRYPTION_KEY=.+' "$ENVF"; then
  die "ARCANE_ENCRYPTION_KEY is empty in $ENVF — run ./scripts/generate-key.sh (do not invent a new key for an existing database)"
fi

proj="${ARCANE_PROJECTS_DIRECTORY:-/opt/docker}"
if [[ ! -d "$proj" ]]; then
  echo "WARNING: projects directory $proj does not exist. Create it before managing stacks, e.g. sudo mkdir -p $proj"
fi

docker compose -f "$ROOT/compose/docker-compose.yml" --env-file "$ENVF" up -d
docker compose -f "$ROOT/compose/docker-compose.yml" --env-file "$ENVF" ps
echo
echo "Open ${ARCANE_APP_URL:-http://${ARCANE_BIND}:${ARCANE_PORT}}"
echo "Sign in as 'arcane'. Copy the first password with:"
echo "  docker compose -f $ROOT/compose/docker-compose.yml --env-file $ENVF cp ${ARCANE_CONTAINER_NAME}:/app/data/initial-admin-password ."
echo "Do not commit that file. The default password is no longer 'arcane-admin'."
