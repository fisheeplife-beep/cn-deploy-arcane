#!/usr/bin/env bash
# Arcane CN preflight — v3 Manager Compose (path A) readiness.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ok=0; warn=0; bad=0
say() { printf '%s\n' "$*"; }
pass() { say "✅ $*"; ok=$((ok+1)); }
warn_() { say "⚠️  $*"; warn=$((warn+1)); }
fail() { say "❌ $*"; bad=$((bad+1)); }

say "=== Arcane CN preflight (v3 Manager Compose + probes) ==="
say ""
say "Host: $(uname -s) $(uname -m)"
say "Time: $(date '+%Y-%m-%d %H:%M %Z')"
say "Pin: ${ARCANE_TAG} / commit ${ARCANE_COMMIT:0:12} / $(image_ref)"
say "Note: path A is a long-running self-hosted panel on port ${ARCANE_PORT}."
say "      v2→v3 migration is a separate chapter, not this preflight."
say ""

arch=$(uname -m)
case "$arch" in
  x86_64|amd64)
    pass "CPU arch $arch — official ${ARCANE_TAG} images include linux/amd64"
    ;;
  aarch64|arm64)
    pass "CPU arch $arch — official ${ARCANE_TAG} images include linux/arm64"
    ;;
  armv7l|armv7)
    pass "CPU arch $arch — official ${ARCANE_TAG} images include linux/arm/v7"
    ;;
  riscv64)
    pass "CPU arch $arch — official ${ARCANE_TAG} images include linux/riscv64"
    ;;
  *)
    warn_ "CPU arch $arch is not in the official image list (linux/amd64, linux/arm64, linux/arm/v7, linux/riscv64)"
    ;;
esac

cpus=$(nproc 2>/dev/null || echo 0)
if [[ "$cpus" -ge 1 ]]; then
  pass "CPUs $cpus"
else
  warn_ "Could not read CPU count"
fi

if [[ -r /proc/meminfo ]]; then
  mem_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
  mem_total_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
  mem_gi=$(awk -v k="$mem_kb" 'BEGIN {printf "%.0f", k/1024/1024}')
  mem_total_gi=$(awk -v k="$mem_total_kb" 'BEGIN {printf "%.0f", k/1024/1024}')
  if [[ "${mem_gi:-0}" -ge 1 ]]; then
    pass "RAM available ~${mem_gi} GiB (total ~${mem_total_gi} GiB)"
  else
    warn_ "RAM available ~${mem_gi} GiB (total ~${mem_total_gi} GiB) — a small host may feel tight once the panel plus stacks are running"
  fi
else
  warn_ "/proc/meminfo unreadable"
fi

if df -Pk "$ROOT" >/dev/null 2>&1; then
  disk_gb=$(df -Pk "$ROOT" | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
  if [[ "${disk_gb:-0}" -ge 8 ]]; then
    pass "Disk free ~${disk_gb} GB under $ROOT"
  else
    warn_ "Disk free ~${disk_gb} GB — leave room for images, the projects folder, and volume backups"
  fi
fi

for c in git curl jq python3 openssl; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c present"
  else
    fail "$c missing — required for probes / clone / key generation"
  fi
done

if command -v docker >/dev/null 2>&1; then
  pass "docker: $(docker --version 2>/dev/null | head -1)"
  if docker compose version >/dev/null 2>&1; then
    pass "docker compose: $(docker compose version --short 2>/dev/null || docker compose version | head -1)"
  else
    fail "docker compose v2 missing — path A uses compose/docker-compose.yml"
  fi
  if docker info >/dev/null 2>&1; then
    pass "docker daemon reachable"
    if [[ -S /var/run/docker.sock ]]; then
      pass "docker.sock exists at /var/run/docker.sock"
    else
      warn_ "docker.sock not at /var/run/docker.sock — set the compose mount to the real socket path"
    fi
  else
    warn_ "docker daemon not reachable (pull / up will fail until fixed)"
  fi
else
  fail "docker missing — required for path A (image pull + Compose). Probes and the shallow clone still work."
fi

proj="${ARCANE_PROJECTS_DIRECTORY:-/opt/docker}"
if [[ -d "$proj" ]]; then
  pass "projects directory exists: $proj"
else
  warn_ "projects directory $proj does not exist yet — create it (same absolute path inside the container) before ./scripts/up-manager.sh"
fi

envf="$(env_file)"
if [[ -f "$envf" ]]; then
  if grep -qE '^ARCANE_ENCRYPTION_KEY=.+' "$envf"; then
    pass "ARCANE_ENCRYPTION_KEY is set in $(basename "$(dirname "$envf")")/$(basename "$envf") (value hidden)"
  else
    warn_ "ARCANE_ENCRYPTION_KEY is empty — generate with ./scripts/generate-key.sh (openssl). Do not invent a new key for an existing database."
  fi
  if grep -qE '^ARCANE_APP_URL=.+' "$envf"; then
    pass "ARCANE_APP_URL is set (value hidden)"
  else
    warn_ "ARCANE_APP_URL missing — set it to the URL you will actually open"
  fi
else
  warn_ "No local/.env yet — copy local/.env.example and run ./scripts/generate-key.sh before ./scripts/up-manager.sh"
fi

say ""
say "=== summary: ${ok} ok / ${warn} warn / ${bad} bad ==="
if [[ "$bad" -gt 0 ]]; then
  say "Preflight found blockers. Network / image probes and the shallow clone can still run without Docker."
  exit 1
fi
exit 0
