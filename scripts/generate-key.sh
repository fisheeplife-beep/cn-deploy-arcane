#!/usr/bin/env bash
# Generate ARCANE_ENCRYPTION_KEY with OpenSSL (official alternative to
# `docker run ... /app/arcane generate secret`) and write it into local/.env.
# Never prints the key. Do not run this against an existing Arcane database —
# keep the original key and only rename ENCRYPTION_KEY → ARCANE_ENCRYPTION_KEY.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
need_cmd openssl

ENVF="$(env_file)"
mkdir -p "$(dirname "$ENVF")"

if [[ -f "$ENVF" ]] && grep -qE '^ARCANE_ENCRYPTION_KEY=.+' "$ENVF"; then
  echo "ARCANE_ENCRYPTION_KEY is already set in $ENVF (value hidden)."
  echo "Refusing to overwrite it. On a migration, keep the existing key."
  exit 0
fi

KEY="$(openssl rand -hex 32)"
if [[ ! -f "$ENVF" ]]; then
  cp "$ROOT/local/.env.example" "$ENVF"
fi

if grep -qE '^ARCANE_ENCRYPTION_KEY=' "$ENVF"; then
  # Replace only the empty assignment; do not print the value.
  tmp="$(mktemp)"
  awk -v k="$KEY" '{
    if ($0 ~ /^ARCANE_ENCRYPTION_KEY=/) { print "ARCANE_ENCRYPTION_KEY=" k }
    else print
  }' "$ENVF" > "$tmp"
  mv "$tmp" "$ENVF"
else
  printf '\nARCANE_ENCRYPTION_KEY=%s\n' "$KEY" >> "$ENVF"
fi
chmod 600 "$ENVF" 2>/dev/null || true
echo "Wrote ARCANE_ENCRYPTION_KEY to $ENVF (value hidden, 32-byte hex)."
echo "Back this file up with /app/data. Losing the key can make encrypted data unrecoverable."
