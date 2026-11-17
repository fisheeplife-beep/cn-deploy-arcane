#!/usr/bin/env bash
# Shared helpers for cn-deploy-arcane scripts. Source this file.
# shellcheck disable=SC2034

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [[ -f "$ROOT/local/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/local/.env"
  set +a
fi

# Pinned to the latest stable GitHub Release as of 2026-11-17.
# Do not retarget these at a floating :latest / :v3 tag.
ARCANE_TAG="${ARCANE_TAG:-v3.0.1}"
ARCANE_COMMIT="${ARCANE_COMMIT:-c614e0d2df6d6bcb6188c1af249f457000c7e96c}"
ARCANE_IMAGE_REPO="${ARCANE_IMAGE_REPO:-ghcr.io/getarcaneapp/manager}"
# Multi-arch index digest for manager:v3.0.1, identical on GHCR / Docker Hub / Quay.
ARCANE_MANAGER_DIGEST="${ARCANE_MANAGER_DIGEST:-sha256:80a2f71c60bc1bff3e618e6e71efec98ad365ba4f0395aa76e234d8ba75e5a99}"
ARCANE_MANAGER_AMD64="${ARCANE_MANAGER_AMD64:-sha256:2322302702c42b795255c9a2430b02c65b7749705cab16ae80ed478b52e05d79}"
ARCANE_AGENT_IMAGE_REPO="${ARCANE_AGENT_IMAGE_REPO:-ghcr.io/getarcaneapp/agent}"
ARCANE_AGENT_DIGEST="${ARCANE_AGENT_DIGEST:-sha256:4285608a7a085acb8296c5a76261fd1b738a40760dcf46e48a4361240cd94692}"
ARCANE_AGENT_AMD64="${ARCANE_AGENT_AMD64:-sha256:e54c087b1f0f068733190cf932421ee973ec5e91ca13bdcd5cd9f7532ee380de}"
# Migration stepping-stone (not the production pin).
ARCANE_V2173_TAG="${ARCANE_V2173_TAG:-v2.17.3}"
ARCANE_V2173_MANAGER_DIGEST="${ARCANE_V2173_MANAGER_DIGEST:-sha256:2e0dc9f5ef03599181a49baf6470055d82e24d9cb15bbc62498ea642c0f882a7}"
ARCANE_V2173_AGENT_DIGEST="${ARCANE_V2173_AGENT_DIGEST:-sha256:3005364d5aa603a8fe8b51bee26413b473965c3c2dc6c152b0016dd1cdda1cf4}"
ARCANE_DEST="${ARCANE_DEST:-data/upstream-arcane}"
ARCANE_PORT="${ARCANE_PORT:-3552}"
ARCANE_BIND="${ARCANE_BIND:-127.0.0.1}"
ARCANE_CONTAINER_NAME="${ARCANE_CONTAINER_NAME:-arcane}"
ARCANE_UPSTREAM_REPO="${ARCANE_UPSTREAM_REPO:-https://github.com/getarcaneapp/arcane.git}"

abs_under_root() {
  local p="$1"
  if [[ "$p" = /* ]]; then
    printf '%s\n' "$p"
  else
    printf '%s\n' "$ROOT/$p"
  fi
}

upstream_dir() { abs_under_root "$ARCANE_DEST"; }

image_ref() {
  printf '%s@%s\n' "$ARCANE_IMAGE_REPO" "$ARCANE_MANAGER_DIGEST"
}

agent_image_ref() {
  printf '%s@%s\n' "$ARCANE_AGENT_IMAGE_REPO" "$ARCANE_AGENT_DIGEST"
}

env_file() {
  if [[ -f "$ROOT/local/.env" ]]; then
    printf '%s\n' "$ROOT/local/.env"
  elif [[ -f "$ROOT/.env" ]]; then
    printf '%s\n' "$ROOT/.env"
  else
    printf '%s\n' "$ROOT/local/.env"
  fi
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }
