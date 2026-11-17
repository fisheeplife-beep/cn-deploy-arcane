# 反代与 WebSocket（进阶）

作者环境没有反代、也没有把面板真正跑起来，这一章是对照官方 [Reverse Proxy Setup](https://getarcane.app/docs/networking/reverse-proxy) 整理的中文要点，**整段配置未验证**。需要完整 Nginx / Apache / Traefik 示例时请打开英文原文，不要只靠这里的摘要。

## 必须同时做的三件事

1. **反代要转发 WebSocket**，否则界面里的实时更新（容器状态、日志流）会断。Nginx 至少需要 `proxy_http_version 1.1`、`Upgrade`、`Connection "upgrade"` 和 `proxy_cache_bypass`。Caddy 的 `reverse_proxy`、Traefik 的普通 web router 默认会升级 WebSocket。
2. **`ARCANE_APP_URL` 写成用户在浏览器里打开的公网 URL**，例如 `https://arcane.example.com`，不要带内部端口 `:3552`。
3. **`ARCANE_TRUSTED_PROXIES` 写成反代所在网段（CIDR，必须带前缀长度）。** 不设的话，登录限流会按反代自己的 IP 计数，既削弱暴力破解保护，也可能把反代后面的所有用户一起锁住。条目写成 `172.18.0.0/16` 或单机 `10.0.0.5/32`；没有 `/32`、`/128` 这类前缀的地址会被忽略并打警告。

同机反代且 Arcane 以字面量 `ARCANE_LISTEN=127.0.0.1` 监听时，官方会自动信任 loopback，不必再填 `ARCANE_TRUSTED_PROXIES`。写成主机名 `localhost` 不算。

本仓路径 A 默认把 3552 绑在 `127.0.0.1`，正好适合「本机 Nginx / Caddy → 回环上的 Arcane」。不要为了省事把端口改成 `0.0.0.0:3552` 再在公网裸奔。

## Traefik + 远程 Agent 多一步

Agent 默认传输是 `auto`：能走 gRPC 就走 gRPC，失败再回退 WebSocket。gRPC 隧道打在 `POST /api/tunnel/connect`，Traefik 需要：

- 单独一条优先匹配这条路径、且 `Content-Type` 为 gRPC 的 router，backend scheme 为 `h2c`；
- 把 HTTPS entrypoint 的 `respondingtimeouts.readtimeout` 设成 `0s`，否则默认 60 秒会掐断长连接。

成功时 Agent 日志是 `Agent tunnel connected to manager` 且 `transport=grpc`；失败常见 `gRPC agent tunnel connection failed, falling back to websocket transport`。没有远程 Agent 时，只配 web router 即可。

`ARCANE_MANAGER_API_URL` 应与 Manager 的 `ARCANE_APP_URL` 一致。

## 登录失败、报请求头过大

3.0 用 ML-DSA-87 签会话。当前新会话通常一个 cookie 就够，但从旧版本留下来的会话可能拆成最多四个 cookie。Nginx 需要加大 `large_client_header_buffers` 一类限制，否则表现为莫名其妙登录失败。

## TCP 层反代

HAProxy 或 Traefik TCP router 若不加 `X-Forwarded-For`，改用 PROXY protocol（v1 或 v2），同时把对端写进 `ARCANE_TRUSTED_PROXIES`。这个列表里只要有一条格式无效，PROXY protocol 会整段关闭。
