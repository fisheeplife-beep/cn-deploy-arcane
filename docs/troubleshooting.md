# 排障（Arcane v3.0.1）

先看验证边界：作者机没有 Docker，起栈、登录、socket 权限和反代都未在本环境复现。下面是对照官方文档与镜像探针整理出的常见失败形态，方便对照日志，不是把官方手册再抄一遍。

## 镜像能拉或不能拉

- **旧名字 + `:latest` 拉成功，但面板还是 2.x。** 2026-11-17 实测 `ghcr.io/getarcaneapp/arcane:latest` 的 digest 等于 **v2.17.3**，`v3` / `v3.0.1` 在该名字下是 404。改用 `manager` / `agent`，并钉本仓写明的 digest。
- **GHCR 超时、Docker Hub 也慢。** 三个注册表的 v3.0.1 索引 digest 相同，换 `ARCANE_IMAGE_REPO` 即可，见 [china-network.md](./china-network.md)。
- **只改了 tag、忘了改变量前缀。** 3.0 会拒绝启动，日志含 `legacy environment variables are no longer read`。见 [migrate-v3.md](./migrate-v3.md)。

## 容器起来了，但登录不了

- 用户名仍是 `arcane`（除非你设了 `ARCANE_DEFAULT_ADMIN_USERNAME`）。密码**不是** `arcane-admin`。把 `/app/data/initial-admin-password` 拷出来：
  `docker compose cp arcane:/app/data/initial-admin-password .`
  第一次登录会强制改密。自行指定的初始密码须满足策略（至少 12 位，含大小写、数字和符号），且不会写进那个文件。
- 浏览器打开的地址必须和 `ARCANE_APP_URL` 一致。走反代时写成 `https://你的域名`，不要带着内部的 `:3552`。
- 反代后面登录失败、提示请求头过大：旧会话的 ML-DSA-87 cookie 可能拆成多块，需加大 `large_client_header_buffers` 一类限制。见 [reverse-proxy.md](./reverse-proxy.md)。
- 反代后所有人共用一个限流桶、容易被锁：没设 `ARCANE_TRUSTED_PROXIES`（同机 loopback 代理且 `ARCANE_LISTEN=127.0.0.1` 时除外）。

## 面板是空的，管不到 Docker

- compose 里漏了 docker.sock，或 NAS 上 socket 路径不是 `/var/run/docker.sock`。
- 不要指望给 socket 加 `:ro` 就变成只读——那只阻止改 socket 文件本身，允许的 `POST` / `DELETE` 照样会改变 Docker。
- 官方镜像会自动把运行用户加入 socket 所属组，不必把 `PGID` 写成网上常见的 `999`。`PUID` / `PGID` 主要用于 Arcane 自己写出的文件属主；省略时默认 `65532:65532`。
- 用了 socket 代理却没设 `DOCKER_HOST=tcp://docker-socket-proxy:2375`，或代理 allowlist 没覆盖 Arcane 需要的路由。见 [socket-and-nas.md](./socket-and-nas.md)。
- SELinux 主机直接挂 socket 时，按官方文档加 `security_opt: [label:disable]`，项目目录加 `:z`；或改走 socket 代理。

## 项目目录 / 相对路径挂载错乱

`ARCANE_PROJECTS_DIRECTORY` 必须和 bind mount 的容器内路径是同一绝对路径。只改其中一处，面板里写的 `./config` 在宿主机 Docker 看来就不是同一位置。家服路径见 [socket-and-nas.md](./socket-and-nas.md)。

## 健康检查

官方内建命令是 `./arcane health --timeout 2s`，检查的是 `/api/health`。`start_period: 15s` 是为了给首次数据库迁移留时间。Agent **不要**再探 3553：v3 Agent 不侦听端口，看 Manager 里的在线状态即可。

## 迁到 3.0 后立刻退出

对照日志原文：

| 日志 / 现象 | 常见原因 |
|-------------|----------|
| `upgrade to Arcane v2.17.1 first` | 数据库还没在 2.17.3 上启动过（报错写 2.17.1，要求仍是先到 2.17.3） |
| `legacy environment variables are no longer read` / `rename X to ARCANE_X` | 旧变量名没有对应的 `ARCANE_` 新名 |
| `direct agents were removed in v3` | 还在用 `AGENT_MODE` / `ARCANE_AGENT_MODE`，需要重新注册 |
| 统计或更新检查又打开了 | 仍写着 `ANALYTICS_DISABLED` / `UPDATE_CHECK_DISABLED`，3.0 忽略旧名 |
| Agent 每次重启都重新注册失败 | `/app/data` 没持久化，一次性 enrollment token 第二次作废 |

## 销毁项目

「停止」只停容器。「销毁」可能把项目目录里的 compose 一起删掉。科技喵仔在 3.0.1 上观察到：弹窗即使不勾「删除数据卷」，项目文件夹也会消失。本仓未复现，但操作前先把 compose 和 `.env` 复制出来更稳妥。
