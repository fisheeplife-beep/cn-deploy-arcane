# Arcane 国内可跟做部署配套

> 上游仓库：[getarcaneapp/arcane](https://github.com/getarcaneapp/arcane)（**BSD-3-Clause**，Copyright (c) 2025, Kyle Mendell；约 9064 星，2026-11-17 晚上实测）
> 产品 / 文档：[getarcane.app](https://getarcane.app) · [安装](https://getarcane.app/docs/get-started/installation) · [迁到 3.0](https://getarcane.app/docs/get-started/migrate-v3)
> 发行页：[Release v3.0.1](https://github.com/getarcaneapp/arcane/releases/tag/v3.0.1)（2026-11-15T17:05:31Z，即 2026-11-16 01:05:31 Asia/Shanghai）
> 镜像（三个注册表的索引 digest 在 2026-11-17 一致）：
> `ghcr.io/getarcaneapp/manager@sha256:80a2f71c60bc1bff3e618e6e71efec98ad365ba4f0395aa76e234d8ba75e5a99`
> `ghcr.io/getarcaneapp/agent@sha256:4285608a7a085acb8296c5a76261fd1b738a40760dcf46e48a4361240cd94692`
> 本仓性质：**独立中文部署配套**（预检 / 钉 tag 浅克隆 / 多注册表探针 / 薄 Compose / 国内网络与 v2→v3 踩坑），**不是**官方镜像或 fork，也**不会**整页搬运上游 README 或他人中文文。上游是 BSD-3-Clause，本配套仓自身是 MIT，并不重新授权上游代码或镜像。

Arcane 是自托管的 Docker / Compose 管理面板，常被拿来对标 Portainer / Dockge。官方推荐的自托管路径是 **已发布的 `manager` 镜像**（不是自己 build，也不是已退休的 GHCR 名 `arcane`），入口在 **3552**，挂上 Docker socket，并把项目目录以**同一绝对路径**挂进容器。

系列索引：[cn-deploy](https://github.com/fisheeplife-beep/cn-deploy)

---

## 验证边界（请先看）

| 路径 | 本仓作者环境验证状态（2026-11-17，Asia/Shanghai，Linux x86_64） |
|------|----------------------------------------------------------------|
| **上游身份 / 许可证** | ✅ **已确认** — `getarcaneapp/arcane` 为 **BSD-3-Clause**；钉源码 **`v3.0.1`**（`c614e0d2df6d…`）；Manager 索引 digest **`sha256:80a2f71c60bc…`**（与当天的 `:v3` / `:latest` 一致，但后两者是浮动 tag） |
| **文档 / GitHub / 三个注册表 HTTP** | ✅ **已验证** — 见 [`examples/network-probe.txt`](./examples/network-probe.txt) |
| **GHCR / Docker Hub / Quay 匿名读索引** | ✅ **已验证** — `manager:v3.0.1` 与 `agent:v3.0.1` 三处 digest 相同，平台为 amd64 + arm64 + arm/v7 + riscv64；旧 GHCR 别名 `arcane` / `arcane-headless` 的 `:v3.0.1` 为 404，其 `:latest` 仍等于 **v2.17.3**。见 [`examples/image-probe.txt`](./examples/image-probe.txt) |
| **浅克隆钉 tag** | ✅ **已验证** — 见 [`examples/clone-upstream.txt`](./examples/clone-upstream.txt) |
| **路径 A：Docker pull + Compose 起栈 + `/api/health` + 首次登录** | ⚠️ **未验证** — 作者机 **无 Docker Engine**。脚本已写好，待有 Docker 的机器回填 [`examples/up-manager-pull.txt`](./examples/up-manager-pull.txt) / [`examples/smoke.txt`](./examples/smoke.txt) |
| **v2→v3 真实迁移、远程 Agent、反代 WebSocket、socket 代理、NAS 套件** | ⚠️ **未验证** — 无 Docker，也没有一份可升级的 2.x 数据。步骤见 [`docs/migrate-v3.md`](./docs/migrate-v3.md) 等，来自官方文档与索引实测，不是本机跑通的记录 |

摘要：[`examples/verification-boundary.txt`](./examples/verification-boundary.txt) · 主机快照：[`examples/host-snapshot.txt`](./examples/host-snapshot.txt)

---

## 相对官方英文文档和已有中文文章，本仓多写什么？

官方英文站已经把安装、迁移、反代、socket 代理和远程 Agent 写全了。UI 可通过 Crowdin 显示中文，但**仓库和文档站没有中文部署入口**。站外中文也不是空白，请不要把本仓当成「第一篇 3.0 中文安装文」：

- [科技喵仔《Arcane 3.0 实测》](https://www.kejimiaozai.com/archives/1690)（2026-11-17）已经在有 Docker 的机器上按官方 compose 做过 **3.0.1 全新安装**：纠正了旧变量名、默认密码不再是 `arcane-admin`、统计开关要反转，也建议把端口绑在 `127.0.0.1`。作者写明自己**没走 2.x 升级**，模板市场、Git 同步和远程 Agent 也没测；镜像用的是浮动 `:latest`。
- [远影归灯长文](https://yuanyinglight.com/1740.html) 钉死 **`v2.17.2`**（不是迁移要求的 2.17.3），compose 仍用 `APP_URL` / `ENCRYPTION_KEY` / `PROJECTS_DIRECTORY`，并写默认口令 `arcane` / `arcane-admin`。镜像名已经是 `manager`，但按这份变量表去跑 3.0 会直接拒绝启动。
- [少数派 · 熊猫不是猫](https://sspai.com/post/108314)（2026-04-06）是极空间上的功能介绍，仍写默认密码 `arcane-admin`，不是迁移或 digest 钉死的跟做记录。
- 选题时还看到论坛里流传带 `JWT_SECRET`、旧镜像名 `ghcr.io/getarcaneapp/arcane` 的 compose 片段。本次检索未能定位到仍可公开打开的原帖，故不给具体 URL；官方迁移文档已要求删除 `JWT_SECRET`，3.0 只会忽略它并打警告。

**请去上游看功能说明。** 本仓刻意错位，只补跟做时更容易踩、而上面这些文章没有实测或已经过时的点：

1. **钉已发布的 `v3.0.1` 索引 digest**（GHCR / Docker Hub / Quay 同一天读到的值相同），并写明 `:v3` / `:latest` 当天虽相等也仍是浮动 tag；
2. **旧 GHCR 别名的陷阱**：`arcane` / `arcane-headless` 下没有 v3 tag，它们的 `:latest` 冻在 v2.17.3，拉「成功」不等于已经在 3.0；
3. **v2→v3 单独成章**：必须先到 2.17.3；**加密密钥只能改名、不能新生成**；direct Agent 要重注册；报错原文可能写 `upgrade to Arcane v2.17.1 first`；
4. **国内网络**：三个官方注册表可互换；出站代理用官方的 `HTTP_PROXY` 变量；默认统计心跳走 `checkin.getarcane.app`；
5. **socket 权限、反代 WebSocket、远程 Agent、家服/NAS 绝对路径**（进阶，作者机未跑通，只把官方易踩偏的点写成中文对照）；
6. **诚实验证边界**（作者机无 Docker 则标未验证）。

本仓**不整页翻译**上游或他人中文文。需要完整配置项时请打开钉 tag 对应的英文文档。

---

## 选哪条路？

| 场景 | 推荐 |
|------|------|
| **有 Docker，要新装一台单机面板** | **路径 A：官方 v3 Manager Compose**（本仓主推） |
| **已经在跑 2.x** | 不要走路径 A 的「生成新密钥」。先读 [`docs/migrate-v3.md`](./docs/migrate-v3.md)，升到 2.17.3 再进 3.0 |
| **要管其它 Docker 主机** | 进阶：远程 Agent（[`compose/docker-compose.agent.yml`](./compose/docker-compose.agent.yml)，本仓未跑通） |
| **要收窄 Docker API、或上 SELinux** | 进阶：官方 socket 代理，见 [`docs/socket-and-nas.md`](./docs/socket-and-nas.md) |
| **要自定义域名 / TLS** | 进阶：反代 + WebSocket，见 [`docs/reverse-proxy.md`](./docs/reverse-proxy.md) |
| **愿意让官方脚本顺手装 Docker** | 备选：`curl -fsSL https://getarcane.app/install.sh \| sudo bash`（浮动 tag，本仓不推荐当生产钉） |
| **只测网络 / 拉源码 / 核对 digest** | `./scripts/probe-network.sh` / `./scripts/probe-images.sh` / `./scripts/clone-upstream.sh` |

**主推：路径 A（新装）。** 这是官网 Installation 写的那条路：不用克隆，不用本地 build，一个端口 3552。

---

## 环境要求（路径 A）

- Docker Engine + Compose v2
- 能挂上 Docker socket（常见路径 `/var/run/docker.sock`）
- 一个用来放 Compose 项目的**绝对路径**目录（官方示例 `/opt/docker`；NAS 路径见 [`docs/socket-and-nas.md`](./docs/socket-and-nas.md)）
- 官方镜像架构：`linux/amd64`、`linux/arm64`、`linux/arm/v7`、`linux/riscv64`
- 32 字符以上的 `ARCANE_ENCRYPTION_KEY`（或 `hex:` / `base64:` 前缀的 32 字节密钥）。新装用 `./scripts/generate-key.sh`（OpenSSL，官方认可的替代方式）；**已有数据库不要重新生成**

---

## 路径 A｜官方 v3 Manager Compose（本仓主推）

```bash
./scripts/preflight.sh
./scripts/clone-upstream.sh
./scripts/probe-network.sh
./scripts/probe-images.sh
# 以下需要 Docker；作者机未跑通
cp local/.env.example local/.env
# 按实际访问地址改 ARCANE_APP_URL，按实际项目目录改 ARCANE_PROJECTS_DIRECTORY
./scripts/generate-key.sh
# 需要时：sudo mkdir -p /opt/docker   # 或你在 local/.env 里写的那条绝对路径
./scripts/up-manager.sh --pull
./scripts/up-manager.sh
./scripts/smoke.sh
```

本仓的 [`compose/docker-compose.yml`](./compose/docker-compose.yml) 是官方安装步骤的薄包装：钉死 v3.0.1 索引 digest、默认把 3552 绑在 `127.0.0.1`、密钥只从 `local/.env` 读。换注册表时改 `ARCANE_IMAGE_REPO` 即可（`ghcr.io/getarcaneapp/manager`、`getarcaneapp/manager` 或 `quay.io/getarcaneapp/manager`），digest 保持不变。

启动后：

1. 浏览器打开 `ARCANE_APP_URL`（默认 `http://localhost:3552`；若只绑了回环、你人在另一台电脑，用 SSH 隧道：`ssh -N -L 3552:127.0.0.1:3552 用户@主机`）。
2. 用户名 `arcane`。密码从容器里拷出，**不要再试 `arcane-admin`**：
   `docker compose -f compose/docker-compose.yml --env-file local/.env cp arcane:/app/data/initial-admin-password .`
3. 按提示改成符合策略的新密码（至少 12 位，含大小写、数字和符号）。那个密码文件不要提交。
4. 可选健康检查：`curl http://127.0.0.1:3552/api/health`，官方期望 JSON 里有 `"status":"UP"`（本仓未实测）。

官网文档示例把端口写成 `3552:3552`（听所有接口）。本仓默认加 `127.0.0.1:`，因为面板能指挥整台 Docker。局域网访问再改 `ARCANE_BIND`，公网请走反代。

可选：`ARCANE_ANALYTICS_ENABLED=false` 关闭对 `checkin.getarcane.app` 的匿名心跳。不要写已经失效的 `ANALYTICS_DISABLED=true`。

---

## 备选与进阶（本仓未跑通）

- **Linux 安装脚本**：`https://getarcane.app/install.sh`，会安装 Docker 并用浮动 tag 拉镜像。卸载脚本同样在官网。适合全新机器，不适合想钉 digest 或已经有 Docker 的环境。
- **远程 Agent**：在 Manager 里生成一次性注册令牌，到远端跑 [`compose/docker-compose.agent.yml`](./compose/docker-compose.agent.yml)。必须持久化 `/app/data`，否则下次启动会再次注册（一次性令牌会被拒绝）。v3 Agent 不侦听 3553。旧的 direct Agent 要重注册；原来的 edge Agent 一般会自动改名。见官方 [Remote Agents](https://getarcane.app/docs/remote/agents)。
- **socket 代理 / 家服路径**：[`docs/socket-and-nas.md`](./docs/socket-and-nas.md)
- **反代 WebSocket**：[`docs/reverse-proxy.md`](./docs/reverse-proxy.md)
- **外挂 Postgres**：设 `ARCANE_DATABASE_URL`，见官方安装文档的 External Postgres 一节。本仓未测。

---

## 国内网络 / 排障 / 迁移

- 国内拉镜像、三个注册表互换、弱网与 NAS：[docs/china-network.md](./docs/china-network.md)
- v2→v3（含密钥不能新生成、先到 2.17.3）：[docs/migrate-v3.md](./docs/migrate-v3.md)
- 登录、socket、健康检查：[docs/troubleshooting.md](./docs/troubleshooting.md)

---

## 安全注意

- 挂上 `docker.sock` ≈ 这台机器的 Docker root。默认只绑回环；改密、限制来源、必要时再加 socket 代理。
- `ARCANE_ENCRYPTION_KEY`、初始密码、Agent token 只放 `local/.env` 或 secret，**不要提交**。迁移时保留原密钥。
- 备份 `/app/data` 时把加密密钥一起存好。启用官方 recovery key 之前，旧卷备份仍可能依赖这把密钥。

---

## 开源边界

本配套仓：**MIT**（Copyright (c) 2026 fisheeplife-beep）。  
上游 Arcane：**BSD-3-Clause**（Copyright (c) 2025, Kyle Mendell）。本仓不重新授权上游源码、镜像或二进制，也不是官方项目、镜像或 fork。

---

## 系列

索引：[cn-deploy](https://github.com/fisheeplife-beep/cn-deploy)
