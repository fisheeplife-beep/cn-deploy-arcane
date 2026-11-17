# 国内网络说明（Arcane）

官方把同一份 **v3.0.1** 多架构索引发布到三个注册表，2026-11-17 晚上在作者环境用匿名 token 读到的 **索引 digest 完全一致**：

| 注册表 | Manager 引用（钉 digest，不要只用浮动 tag） |
|--------|----------------------------------------------|
| GHCR（官网安装文档默认） | `ghcr.io/getarcaneapp/manager@sha256:80a2f71c60bc1bff3e618e6e71efec98ad365ba4f0395aa76e234d8ba75e5a99` |
| Docker Hub（上游仓库 `docker/examples/compose.basic.yaml` 默认） | `getarcaneapp/manager@sha256:80a2f71c60bc1bff3e618e6e71efec98ad365ba4f0395aa76e234d8ba75e5a99` |
| Quay | `quay.io/getarcaneapp/manager@sha256:80a2f71c60bc1bff3e618e6e71efec98ad365ba4f0395aa76e234d8ba75e5a99` |

Agent 同样三处一致：`…/agent@sha256:4285608a7a085acb8296c5a76261fd1b738a40760dcf46e48a4361240cd94692`。

平台：`linux/amd64`、`linux/arm64`、`linux/arm/v7`、`linux/riscv64`。家用 NAS 常见的 amd64 / arm64 都有官方镜像，不必自己 build。

## 你需要通的几条链路

1. **源码 / 文档**：`github.com/getarcaneapp/arcane`、`getarcane.app`（安装、迁移、反代文档只在英文站，仓库 README 没有中文部署入口）。
2. **拉镜像**：上面三选一。国内访问 GHCR 或 Docker Hub 都可能慢或失败，先用 `./scripts/probe-network.sh` 和 `./scripts/probe-images.sh` 看当前出口能不能读索引。读得下索引不等于 `docker pull` 一层层都顺利，后者本仓作者机因无 Docker 未能实测。
3. **可选出站**：模板市场、镜像更新检查会访问注册表和 [registry.getarcane.app](https://registry.getarcane.app)。默认还会向 `checkin.getarcane.app` 发匿名心跳（版本号、随机实例 ID、服务器类型）。面板本身不依赖这条链路才能打开；要关掉请设 `ARCANE_ANALYTICS_ENABLED=false`。**不要**再写 2.x 的 `ANALYTICS_DISABLED=true`，3.0 会忽略旧名，统计会悄悄重新打开。

## 推荐策略

- **优先换官方注册表，而不是改镜像名。** 三个仓库的 v3.0.1 索引 digest 相同，只要在 `local/.env` 里改 `ARCANE_IMAGE_REPO`（`ghcr.io/getarcaneapp/manager` / `getarcaneapp/manager` / `quay.io/getarcaneapp/manager`），compose 仍然钉同一 digest。
- 若必须走自建镜像缓存或 HTTP 代理，用官方支持的 `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`（大小写都可以），并把 localhost、内网网段和内建 registry 写进 `NO_PROXY`。说明见 [Outbound HTTP Proxy](https://getarcane.app/docs/networking/outbound-proxy)。本仓不提供绕过区域限制的做法。
- **不要**再用已退休的 GHCR 别名 `ghcr.io/getarcaneapp/arcane` 或 `ghcr.io/getarcaneapp/arcane-headless`。v3 的 tag 在这两个名字下是 404；它们的 `:latest` 在 2026-11-17 仍指向 **v2.17.3** 的 digest。照旧教程拉 `:latest`，看起来“成功”，其实还停在 2.x。
- 官方 `install.sh` 会按文档安装 Docker 并拉浮动 tag，国内弱网或已有 Docker 的机器更适合本仓的 digest 钉死 Compose。

## 家服 / NAS / 弱网

- 项目目录必须「宿主机绝对路径 = 容器内绝对路径」。群晖常见 `/volume1/docker`，Unraid 常见 `/mnt/user/appdata` 或自建 stacks 目录，极空间 / 绿联 / 飞牛也各自有一套。把 `ARCANE_PROJECTS_DIRECTORY`、compose 里的 volume、磁盘上的文件夹三处一起改。相对路径挂载会在「面板里改 compose、宿主机 Docker 真正启动」时指错地方。细节见 [socket-and-nas.md](./socket-and-nas.md)。
- `docker.sock` 默认仍是 `/var/run/docker.sock`；若 NAS 套件把 socket 放在别处，只改挂载路径，不要把 PGID 盲目改成网上流传的 `999`。官方镜像会自动把运行用户加入 socket 所属组。
- 弱网下先确认索引探针成功，再 `./scripts/up-manager.sh --pull`。一次拉不完就重试同一 digest，不要改成 `:latest` 碰运气。
- 面板能管整台机器的 Docker，**不要把 3552 直接映射到公网**。本仓默认绑 `127.0.0.1`。外网访问走 SSH 隧道或带 WebSocket 的反代，见 [reverse-proxy.md](./reverse-proxy.md)。

## 不要把密钥写进镜像或脚本

`ARCANE_ENCRYPTION_KEY`、初始管理员密码、Agent 注册令牌只放 `local/.env` 或 Docker secret，不要提交，也不要贴进 issue。迁移时更不能重新生成加密密钥，见 [migrate-v3.md](./migrate-v3.md)。
