# cn-deploy-arcane

Chinese, follow-along **deployment companion** for [getarcaneapp/arcane](https://github.com/getarcaneapp/arcane) (self-hosted Docker / Compose management panel) — not an official fork, and not a verbatim copy of upstream docs or third-party Chinese write-ups.

**Start here (ZH):** [README.zh-CN.md](./README.zh-CN.md)

Arcane is a **long-running self-hosted app**. The official recommended path is a published `manager` image on port **3552**, with the Docker socket and a projects folder mounted at the same absolute path inside the container.

### What you get

- Preflight + network / multi-registry digest probes for the official **v3 Manager** image (path A) and a thin Compose wrapper that pins the digest
- Pin-tag shallow clone (`v3.0.1`)
- A separate v2→v3 migration chapter (upgrade to 2.17.3 first; do not mint a new encryption key)
- Notes on China registry reachability (GHCR / Docker Hub / Quay share the same index digest), the retired `arcane` / `arcane-headless` GHCR aliases (their `:latest` is frozen at v2.17.3), socket permissions, reverse-proxy WebSockets, remote agents, and typical NAS paths
- Honest verification boundary (author box has no Docker Engine)

### Verification snapshot (author box, 2026-11-17, Asia/Shanghai, Linux x86_64)

| Path | Status |
|------|--------|
| Upstream BSD-3-Clause identity + pin `v3.0.1` / manager index digest `sha256:80a2f71c60bc…` | **Confirmed** |
| Network probes (GitHub / getarcane.app / GHCR · Docker Hub · Quay tokens) | **Verified** |
| Image indexes: GHCR = Docker Hub = Quay for `manager:v3.0.1` and `agent:v3.0.1`; old GHCR aliases' `:latest` still equals v2.17.3 | **Verified** |
| Shallow clone `v3.0.1` (`c614e0d2df6d…`) | **Verified** |
| Path A: Docker pull + Compose + `/api/health` + first login | **Not verified** (no Docker Engine) |
| v2→v3 migration, remote Agent, reverse-proxy WebSockets, socket proxy, NAS | **Not verified** (no Docker; no existing 2.x data) |

Pinned baseline: source **`v3.0.1`** (`c614e0d2df6d6bcb6188c1af249f457000c7e96c`), manager **`ghcr.io/getarcaneapp/manager@sha256:80a2f71c60bc1bff3e618e6e71efec98ad365ba4f0395aa76e234d8ba75e5a99`**, agent **`ghcr.io/getarcaneapp/agent@sha256:4285608a7a085acb8296c5a76261fd1b738a40760dcf46e48a4361240cd94692`**. The same two index digests were also served by Docker Hub and Quay on the same day. Details in `examples/`.

`:v3` and `:latest` currently equal `:v3.0.1`, but they are moving tags. This companion does not pin them.

### Quick start (path A intent)

```bash
./scripts/preflight.sh
./scripts/clone-upstream.sh
./scripts/probe-network.sh
./scripts/probe-images.sh
# on a machine with Docker:
./scripts/generate-key.sh          # openssl; do not run this on an existing database
# create ARCANE_PROJECTS_DIRECTORY (default /opt/docker) and fill local/.env
./scripts/up-manager.sh --pull
./scripts/up-manager.sh
./scripts/smoke.sh
```

v2→v3 is documented separately in [docs/migrate-v3.md](./docs/migrate-v3.md). Do not mix it with the new-install compose.

### License

Companion scripts/docs: **MIT**. Upstream Arcane: **BSD-3-Clause** (Copyright (c) 2025, Kyle Mendell). This companion does not re-license upstream code or images, and is not official.
