#!/usr/bin/env bash
# Probe GHCR / Docker Hub / Quay indexes for the pinned Arcane images (no Docker required).
# Also checks the retired GHCR aliases, which is a common trap.
set -euo pipefail
# shellcheck disable=SC1091
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
need_cmd python3
need_cmd curl

OUT="${1:-}"
python3 - "$OUT" \
  "$ARCANE_MANAGER_DIGEST" "$ARCANE_MANAGER_AMD64" \
  "$ARCANE_AGENT_DIGEST" "$ARCANE_AGENT_AMD64" \
  "$ARCANE_V2173_MANAGER_DIGEST" "$ARCANE_V2173_AGENT_DIGEST" \
  <<'PY'
import json, sys, urllib.request, urllib.error, datetime

out_path = sys.argv[1] or None
pin_mgr, pin_mgr_amd64, pin_agt, pin_agt_amd64, pin_v2173_mgr, pin_v2173_agt = sys.argv[2:8]

lines = [f"# image probe {datetime.datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S %z')}"]
ok = True

ACCEPT = (
    "application/vnd.oci.image.index.v1+json, "
    "application/vnd.docker.distribution.manifest.list.v2+json, "
    "application/vnd.oci.image.manifest.v1+json, "
    "application/vnd.docker.distribution.manifest.v2+json"
)

def get(url, headers=None, timeout=45):
    req = urllib.request.Request(url, headers=headers or {})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, dict(r.headers), r.read(), None
    except urllib.error.HTTPError as e:
        return e.code, dict(e.headers), e.read(), str(e)
    except Exception as e:
        return 0, {}, b"", str(e)

def token(kind, repo):
    if kind == "ghcr":
        url = f"https://ghcr.io/token?service=ghcr.io&scope=repository:{repo}:pull"
    elif kind == "hub":
        url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repo}:pull"
    else:
        url = f"https://quay.io/v2/auth?service=quay.io&scope=repository:{repo}:pull"
    code, _, body, err = get(url)
    if code != 200:
        return None, f"token HTTP {code} {err}"
    data = json.loads(body)
    return data.get("token") or data.get("access_token"), None

def manifest_url(kind, repo, ref):
    if kind == "ghcr":
        return f"https://ghcr.io/v2/{repo}/manifests/{ref}"
    if kind == "hub":
        return f"https://registry-1.docker.io/v2/{repo}/manifests/{ref}"
    return f"https://quay.io/v2/{repo}/manifests/{ref}"

def display(kind, repo):
    if kind == "ghcr":
        return f"ghcr.io/{repo}"
    if kind == "hub":
        return f"docker.io/{repo}"
    return f"quay.io/{repo}"

def probe(kind, repo, ref, required=False):
    global ok
    tok, terr = token(kind, repo)
    headers = {"Accept": ACCEPT}
    if tok:
        headers["Authorization"] = f"Bearer {tok}"
    elif kind != "quay":
        msg = f"FAIL {display(kind, repo)}:{ref} {terr}"
        lines.append(msg)
        if required:
            ok = False
        return None
    code, hdrs, body, err = get(manifest_url(kind, repo, ref), headers=headers)
    name = f"{display(kind, repo)}:{ref}"
    if code != 200:
        snippet = body[:180].decode("utf-8", "replace") if body else ""
        lines.append(f"FAIL {name} HTTP {code} {err} {snippet}")
        if required:
            ok = False
        return {"ok": False, "code": code, "digest": None, "plats": []}
    digest = hdrs.get("Docker-Content-Digest") or hdrs.get("docker-content-digest")
    try:
        idx = json.loads(body)
    except Exception as e:
        lines.append(f"FAIL {name} parse {e}")
        if required:
            ok = False
        return None
    plats, children = [], []
    for m in idx.get("manifests") or []:
        p = m.get("platform") or {}
        os_, arch, var = p.get("os"), p.get("architecture"), p.get("variant")
        if os_ and os_ != "unknown":
            plat = f"{os_}/{arch}" + (f"/{var}" if var else "")
            plats.append(plat)
            children.append((plat, m.get("digest")))
    lines.append(f"OK {name}")
    lines.append(f"  Docker-Content-Digest: {digest}")
    if plats:
        lines.append(f"  platforms: {', '.join(plats)}")
        for plat, d in children:
            lines.append(f"    {plat}: {d}")
    return {"ok": True, "digest": digest, "plats": plats, "children": children, "code": code}

def expect_digest(result, expected, label):
    global ok
    if result and result.get("digest") == expected:
        lines.append(f"PASS {label} digest matches {expected}")
    else:
        got = result and result.get("digest")
        lines.append(f"FAIL {label} digest {got} != {expected}")
        ok = False

def expect_amd64(result, expected, label):
    global ok
    if not result:
        return
    hits = [d for plat, d in result.get("children") or [] if plat == "linux/amd64"]
    if hits and hits[0] == expected:
        lines.append(f"PASS {label} linux/amd64 child is {expected}")
    else:
        lines.append(f"WARN {label} linux/amd64 child {hits} != {expected}")

wanted = ["linux/amd64", "linux/arm64", "linux/arm/v7", "linux/riscv64"]

lines.append("")
lines.append("=== manager v3.0.1 (required) ===")
mgr = {}
for kind in ("ghcr", "hub", "quay"):
    mgr[kind] = probe(kind, "getarcaneapp/manager", "v3.0.1", required=True)
    expect_digest(mgr[kind], pin_mgr, f"{kind} manager:v3.0.1")
    expect_amd64(mgr[kind], pin_mgr_amd64, f"{kind} manager:v3.0.1")

lines.append("")
lines.append("=== agent v3.0.1 (required) ===")
agt = {}
for kind in ("ghcr", "hub", "quay"):
    agt[kind] = probe(kind, "getarcaneapp/agent", "v3.0.1", required=True)
    expect_digest(agt[kind], pin_agt, f"{kind} agent:v3.0.1")
    expect_amd64(agt[kind], pin_agt_amd64, f"{kind} agent:v3.0.1")

if mgr.get("ghcr") and set(wanted).issubset(set(mgr["ghcr"].get("plats") or [])):
    lines.append("PASS manager:v3.0.1 platforms include amd64, arm64, arm/v7, riscv64")
elif mgr.get("ghcr"):
    lines.append(f"WARN manager:v3.0.1 platforms are {mgr['ghcr'].get('plats')}")

lines.append("")
lines.append("=== moving tags (informational; do not pin these) ===")
for ref in ("v3", "latest"):
    r = probe("ghcr", "getarcaneapp/manager", ref)
    if r and r.get("digest") == pin_mgr:
        lines.append(f"NOTE ghcr manager:{ref} currently equals :v3.0.1 on this day; it is still a moving tag.")
    elif r and r.get("digest"):
        lines.append(f"NOTE ghcr manager:{ref} is {r['digest']} (no longer equal to :v3.0.1). This companion still pins v3.0.1.")

lines.append("")
lines.append("=== migration stepping-stone v2.17.3 (informational) ===")
for kind in ("ghcr", "hub", "quay"):
    r = probe(kind, "getarcaneapp/manager", "v2.17.3")
    if r and r.get("digest") == pin_v2173_mgr:
        lines.append(f"PASS {kind} manager:v2.17.3 digest matches {pin_v2173_mgr}")
probe("ghcr", "getarcaneapp/agent", "v2.17.3")

lines.append("")
lines.append("=== retired GHCR aliases (common trap) ===")
for repo, ref, expect_404, frozen in (
    ("getarcaneapp/arcane", "v3.0.1", True, None),
    ("getarcaneapp/arcane", "v3", True, None),
    ("getarcaneapp/arcane", "latest", False, pin_v2173_mgr),
    ("getarcaneapp/arcane", "v2.17.3", False, pin_v2173_mgr),
    ("getarcaneapp/arcane-headless", "v3.0.1", True, None),
    ("getarcaneapp/arcane-headless", "latest", False, pin_v2173_agt),
):
    r = probe("ghcr", repo, ref)
    name = f"ghcr.io/{repo}:{ref}"
    if expect_404:
        if r and r.get("code") == 404:
            lines.append(f"PASS {name} is gone (HTTP 404) — use manager/agent for v3")
        elif r and r.get("ok"):
            lines.append(f"WARN {name} unexpectedly resolved to {r.get('digest')}")
        else:
            lines.append(f"NOTE {name} did not 404 as expected: {r}")
    elif frozen and r and r.get("digest") == frozen:
        if ref == "latest":
            lines.append(f"PASS {name} still resolves, but the digest is the v2.17.3 image ({frozen}). Pulling :latest here will NOT give you v3.")
        else:
            lines.append(f"PASS {name} still resolves to the v2.17.3 digest ({frozen}), as expected for this 2.x tag.")
    elif r and r.get("ok"):
        lines.append(f"NOTE {name} digest {r.get('digest')} (compare with v2.17.3 / v3.0.1)")

text = "\n".join(lines) + "\n"
sys.stderr.write(text)
if out_path:
    open(out_path, "w").write(text)
sys.exit(0 if ok else 1)
PY
