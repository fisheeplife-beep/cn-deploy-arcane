#!/usr/bin/env bash
# Shallow clone getarcaneapp/arcane at the pinned release tag.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
need_cmd git

TAG="$ARCANE_TAG"
DEST="$(upstream_dir)"
mkdir -p "$(dirname "$DEST")"

if [[ -d "$DEST/.git" ]]; then
  echo "Already cloned: $DEST"
  git -C "$DEST" fetch --depth 1 origin "refs/tags/${TAG}:refs/tags/${TAG}" 2>/dev/null || \
    git -C "$DEST" fetch --depth 1 origin "refs/tags/${TAG}" || true
  git -C "$DEST" checkout -q "tags/${TAG}" 2>/dev/null || git -C "$DEST" checkout -q "$TAG" || true
else
  git -c advice.detachedHead=false clone --depth 1 --branch "$TAG" "$ARCANE_UPSTREAM_REPO" "$DEST"
fi

echo "OK $TAG → $DEST"
HEAD=$(git -C "$DEST" rev-parse HEAD)
echo "HEAD $HEAD"
git -C "$DEST" log -1 --format='%h %s'
echo -n "tags-at-HEAD:"
git -C "$DEST" tag --points-at HEAD | awk '{printf " %s", $0} END {print ""}'
if [[ "$HEAD" != "$ARCANE_COMMIT" ]]; then
  echo "WARNING: HEAD $HEAD does not match pinned commit $ARCANE_COMMIT" >&2
  exit 2
fi
if ! git -C "$DEST" tag --points-at HEAD | grep -qx "$TAG"; then
  echo "WARNING: pinned tag $TAG does not point at HEAD" >&2
  exit 2
fi
echo "PASS HEAD matches $ARCANE_COMMIT and carries $TAG"
