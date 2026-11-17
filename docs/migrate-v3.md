# 从 Arcane 2.x 迁到 3.0（与新装分开）

这是给**已经在跑 2.x** 的实例看的。新装请走仓库主文的路径 A，不要和这一章混用。

作者环境没有 Docker，也没有一份可升级的 2.x 数据，**下列步骤来自官方 [Migrate to 3.0](https://getarcane.app/docs/get-started/migrate-v3) 与镜像索引实测，全流程标未验证**。回退只能靠你在换 3.0 镜像之前做的备份。

## 先记住的三件事

1. **必须先升到 v2.17.3 并成功启动一次 Manager 和每一个 Agent**，再改 3.0 镜像。更老的数据库会被 3.0 拒绝；日志里可能写 `upgrade to Arcane v2.17.1 first`——这是官方文档记录的报错原文，实际要求仍是先到 **2.17.3**，不要看到 2.17.1 就停。
2. **加密密钥不能新生成。** 把原有的 `ENCRYPTION_KEY`（或 `ENCRYPTION_KEY_FILE`）改名为 `ARCANE_ENCRYPTION_KEY`（或 `ARCANE_ENCRYPTION_KEY_FILE`），**值保持不变**。换一把新密钥，已加密的面板数据和「尚未迁到 recovery key」的旧卷备份可能无法打开。官方备份文档要求：在确认旧卷备份能用 recovery key 打开之前，一直保留原来的加密密钥。
3. Manager、每一个 Agent、以及本机的 `arcane-cli` **必须一起到 3.0**。只升面板、远程 Agent 还停在 2.x，权限检查会对不上。

v2.17.3 的 Manager 索引 digest（三个注册表一致，仅作过渡，不是本仓生产钉）：

`getarcaneapp/manager@sha256:2e0dc9f5ef03599181a49baf6470055d82e24d9cb15bbc62498ea642c0f882a7`

对应 Agent：`…/agent@sha256:3005364d5aa603a8fe8b51bee26413b473965c3c2dc6c152b0016dd1cdda1cf4`。

## 官方要求的顺序

按这个顺序做，再改生产 tag：

1. 把 Manager 和所有 Agent 升到 **2.17.3**，各启动一次。
2. 处理完标记为 Needs attention 的任务运行（3.0 去掉了 Resolve after review）。
3. 备份：数据库、`/app/data`、compose 与 env 文件、项目目录，**以及当前的 `ENCRYPTION_KEY` 值**。
4. 按下一节改每一份 compose（Manager + 每个 Agent）。
5. `docker compose down` 再 `up -d` 重启 Manager。若直接退出，日志会列出要改名的变量。
6. 再重启每个 Agent。以前的 **direct agent**（`AGENT_MODE=true`）不会自动上线，要按官方 [Remote Agents](https://getarcane.app/docs/remote/agents) 重新注册；原来的 `edge://` Agent 会自动变成 `agent://`，一般不必重注册。
7. 检查自定义角色，并到 System → Notifications **重新配置通知**（3.0 改为 Manager 全局，不再按环境各配一份）。
8. 把 `arcane-cli` 升到 3.0，命令 `environments` 改成 `agents`，脚本里的 API 路径 `/api/environments` 改成 `/api/agents`。

回到 2.x 只能恢复第 3 步的备份。官方允许在明确设置 `ARCANE_ALLOW_DOWNGRADE` 的情况下降级，但那不是默认安全路径，本仓未验证。

## Compose 必须改的四处

每一份文件都要改，缺一处就会在启动时失败，或悄悄改变行为：

1. **镜像名。** GHCR 上不要再写 `ghcr.io/getarcaneapp/arcane` / `arcane-headless`，改成 `manager` / `agent`，并建议钉 `v3.0.1` 的 digest（见主文）。Docker Hub 和 Quay 本来就用新名字，那里通常只改 tag。特别容易踩的坑：2026-11-17 实测，`ghcr.io/getarcaneapp/arcane:latest` 和 `arcane-headless:latest` **仍然能拉到**，但 digest 等于 **v2.17.3**；这两个名字下的 `v3` / `v3.0.1` 是 404。所以「继续用旧名字 + latest」不会把你送进 3.0。
2. **变量加 `ARCANE_` 前缀。** 只写旧名、不写新名，进程会拒绝启动，日志为 `legacy environment variables are no longer read`，并列出 `rename X to ARCANE_X`。`PUID`、`PGID`、`TZ`、`DOCKER_HOST`、`DOCKER_CONFIG`、`HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`、`OTEL_*` 保持原名。
3. **删掉已移除的变量。** `JWT_SECRET`、`EDGE_MUX_DISABLED`、`EDGE_TRANSPORT=poll`。`JWT_SECRET` 在 3.0 会被忽略并打启动警告（会话改由 Arcane 自己的 ML-DSA-87 密钥签发），留着它不会让 3.0「更安全」，只是制造噪音。Agent 也不要再对 3553 做健康检查，v3 Agent 不再侦听端口。
4. **极性反转的开关。** `ANALYTICS_DISABLED=true` 改成 `ARCANE_ANALYTICS_ENABLED=false`；`UPDATE_CHECK_DISABLED=true` 改成 `ARCANE_UPDATE_CHECK_ENABLED=false`。旧名被忽略，等于把统计和更新检查重新打开。

Manager 侧常见对应（值原样保留）：

| 2.x | 3.0 |
|-----|-----|
| `APP_URL` | `ARCANE_APP_URL` |
| `ENCRYPTION_KEY` / `ENCRYPTION_KEY_FILE` | `ARCANE_ENCRYPTION_KEY` / `ARCANE_ENCRYPTION_KEY_FILE` |
| `PROJECTS_DIRECTORY` | `ARCANE_PROJECTS_DIRECTORY` |
| `JWT_SECRET` | 删除 |
| `ANALYTICS_DISABLED=true` | `ARCANE_ANALYTICS_ENABLED=false` |
| `UPDATE_CHECK_DISABLED=true` | `ARCANE_UPDATE_CHECK_ENABLED=false` |

Agent 侧：

| 2.x | 3.0 |
|-----|-----|
| `EDGE_AGENT=true` | `ARCANE_AGENT=true` |
| `MANAGER_API_URL` | `ARCANE_MANAGER_API_URL` |
| `AGENT_TOKEN` | `ARCANE_AGENT_TOKEN` |
| `EDGE_TRANSPORT` / `EDGE_RECONNECT_INTERVAL` / `EDGE_MTLS_*` | `ARCANE_AGENT_TRANSPORT` / `ARCANE_AGENT_RECONNECT_INTERVAL` / `ARCANE_AGENT_MTLS_*` |
| `EDGE_TRANSPORT=poll`、`EDGE_MUX_DISABLED` | 删除；传输默认 `auto` |
| `AGENT_MODE=true` 或单独的 `ARCANE_AGENT_MODE=true` | 会直接拒绝启动（`direct agents were removed in v3`），按官方步骤重新签发注册令牌 |

`ARCANE_EDGE_*` 或残留的 `EDGE_*` 也会按「改名为 `ARCANE_AGENT_*`」报错。`_FILE` 形式同样要加前缀。

## 迁完以后还要看的行为变化

- 环境切换器没了，列表和仪表盘按 Agent 列展示；书签里的旧详情 URL 会失效（需要 `?env=`）。
- 通知改为 Manager 全局，要在 System → Notifications 重配。
- 权限名有拆分和更名，已保存的角色会在启动时迁移；若你的脚本写死了旧权限名，对照官方 Permissions 一节。内置 Deployer 角色不再包含 `containers:update`。
- Cron 从六段（含秒）改成五段；已保存的六段计划会自动丢掉秒字段。脚本里的 `0 0 2 * * *` 要改成 `0 2 * * *`。
- 新项目不再自动生成空的 `.env`，默认模板也不再带 `env_file: .env`。

## 和过时中文教程的关系

照 [远影归灯 v2.17.2 长文](https://yuanyinglight.com/1740.html) 的 compose 直接把镜像改成 3.0，会因为仍使用 `APP_URL` / `ENCRYPTION_KEY` / `PROJECTS_DIRECTORY` 而无法启动；那篇也还写默认口令 `arcane` / `arcane-admin`。先到 2.17.3，再按本章改名并保留原密钥。

[科技喵仔的 3.0.1 新装实测](https://www.kejimiaozai.com/archives/1690) 已经提示「已在跑 2.x 的要先到 2.17.3」，但作者明确走的是全新安装，没有把迁移跑一遍。不要把那篇的「生成一把新 `ARCANE_ENCRYPTION_KEY`」用在旧库上。
