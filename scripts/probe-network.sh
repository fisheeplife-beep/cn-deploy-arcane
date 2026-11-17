#!/usr/bin/env bash
# HTTP reachability probes for Arcane deploy dependencies (no secrets, no Docker).
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
need_cmd curl

say() { printf '%s\n' "$*"; }
say "# network probe $(date '+%Y-%m-%d %H:%M:%S %z')"
say "Host: $(uname -s) $(uname -m)"
say ""

probe() {
  local name="$1" url="$2"
  local out code time_s
  out=$(curl -sS -o /dev/null -w '%{http_code} %{time_total}' --max-time 20 -L -A 'cn-deploy-arcane-probe' "$url" 2>/dev/null || true)
  code=$(awk '{print $1}' <<<"$out")
  time_s=$(awk '{print $2}' <<<"$out")
  [[ "$code" =~ ^[0-9]{3}$ ]] || code="000"
  printf 'HTTP %-3s  %6ss  %s  %s\n' "$code" "${time_s:-?}" "$name" "$url"
}

say "--- source / docs / releases ---"
probe "GitHub repo" "https://github.com/getarcaneapp/arcane"
probe "Release v3.0.1" "https://github.com/getarcaneapp/arcane/releases/tag/v3.0.1"
probe "LICENSE @ v3.0.1" "https://raw.githubusercontent.com/getarcaneapp/arcane/v3.0.1/LICENSE"
probe "Official compose.basic.yaml @ v3.0.1" "https://raw.githubusercontent.com/getarcaneapp/arcane/v3.0.1/docker/examples/compose.basic.yaml"
probe "Docs site" "https://getarcane.app"
probe "Install docs" "https://getarcane.app/docs/get-started/installation"
probe "Migrate to 3.0 docs" "https://getarcane.app/docs/get-started/migrate-v3"
probe "install.sh" "https://getarcane.app/install.sh"

say ""
say "--- registries ---"
probe "GHCR /v2/ (anonymous)" "https://ghcr.io/v2/"
probe "GHCR token (manager pull)" "https://ghcr.io/token?service=ghcr.io&scope=repository:getarcaneapp/manager:pull"
probe "Docker Hub auth" "https://auth.docker.io/token?service=registry.docker.io&scope=repository:getarcaneapp/manager:pull"
probe "Docker Hub registry" "https://registry-1.docker.io/v2/"
probe "Quay /v2/ (anonymous)" "https://quay.io/v2/"
probe "Quay manager tag page" "https://quay.io/v2/getarcaneapp/manager/tags/list"

say ""
say "--- optional egress (analytics / templates; not required to open the panel) ---"
probe "Analytics check-in host" "https://checkin.getarcane.app"
probe "Template registry" "https://registry.getarcane.app"

say ""
say "Codes 200/301/302/401/403 mean the TCP/TLS hop completed. 401 on GHCR /v2/ or Docker Hub /v2/ without a token is expected."
say "000/timeout only describes THIS environment; it is not a howto for bypassing regional restrictions."
