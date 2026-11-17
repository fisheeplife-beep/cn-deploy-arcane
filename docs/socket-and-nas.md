# Docker socket 权限与家服 / NAS 路径（进阶）

作者机没有 Docker，socket 权限、NAS 套件路径和 socket 代理都**未实测**。这里只把官方文档里容易在家服上踩偏的点写成中文对照。

## socket 等于这台机器的 Docker root

路径 A 默认把 `/var/run/docker.sock` 挂进容器。谁能登录面板，谁就能起停容器、挂载宿主机目录。所以：

- 默认只把 3552 绑在 `127.0.0.1`，不要对公网裸奔；
- 初始密码从 `initial-admin-password` 读取后立刻改掉，不要用网上仍在流传的 `arcane-admin`；
- compose 里给 socket 加 `:ro` **不会**让 API 变成只读，只是不让容器改 socket 这个文件。官方 [Socket Proxy](https://getarcane.app/docs/security/socket-proxy) 写得很清楚：只要允许创建容器，攻击者仍然可以挂载宿主机根目录。代理只是收窄 API 面，不是把 Arcane 从「准 root」降成普通用户。

## 不必把 PGID 写成 999

不少旧笔记把 `PGID` 设成宿主机 `docker` 组（常见 999 / 998），否则就报 permission denied。官方 v3.0.1 的 `docker/examples/compose.basic.yaml` 写明：挂上 Docker socket 时，**Arcane 会自动把运行用户映射进 socket 所属组**。`PUID` / `PGID` 用来控制 Arcane 自己创建的文件属主；省略则默认 `65532:65532`。

仍然要核对的是：**socket 的宿主机路径**是否真是 `/var/run/docker.sock`。部分 NAS 套件会放在别的位置，只改 volume 源路径即可。

SELinux 主机不要只靠自动加组。官方建议改走 socket 代理，或对 Arcane 容器 `security_opt: [label:disable]`，并把项目目录等 bind mount 加上 `:z`。

## 想收紧 API 时再加 socket 代理

官方主推 [wollomatic/socket-proxy](https://getarcane.app/docs/security/socket-proxy)，实例生成器也用它；已在使用 Tecnativa 的可以沿用。要点：

- Arcane 侧设 `DOCKER_HOST=tcp://docker-socket-proxy:2375`，不要再直接挂 socket；
- 代理与 Arcane 放在同一用户定义网络；
- wollomatic 的 `-allowfrom=` 要同时包含 `arcane` 和 `arcane-upgrader`（自升级助手的临时别名）。旧实例若只有 `arcane`，需要改代理并先用 Compose 重建一次 Arcane，否则后续自升级会失败。

本仓没有附一份代理 compose，避免和官方 allowlist 再维护一份副本。需要时按英文文档生成，不要从过时博客抄一份过短的允许列表。

## 项目目录：三处同一绝对路径

官方要求把项目文件夹**以同一绝对路径**挂进容器，并把 `ARCANE_PROJECTS_DIRECTORY` 设成这条路径。这样 `./config` 这类相对挂载在面板里和在宿主机 Docker 里解析结果一致，也能管到目录里已有的 compose 项目。

建议一次改三处：

1. 磁盘上的文件夹（先建好，权限给 `PUID`/`PGID` 能写）；
2. compose 的 volume 左右两侧；
3. `ARCANE_PROJECTS_DIRECTORY`。

如果容器内路径不得不不同（例如挂成 `/opt/docker:/app/data/projects`），3.0 会尝试自动翻译；也可以显式写成 `ARCANE_PROJECTS_DIRECTORY=宿主机路径:容器路径`。未设置时默认 `/app/data/projects`。多个目录用 `ARCANE_PROJECTS_DIRECTORIES`。

家服上常见的宿主机路径（只是举例，以你机器上实际目录为准）：

| 环境 | 常见项目目录 |
|------|----------------|
| 普通 Linux | `/opt/docker`（官方示例） |
| 群晖 DSM | `/volume1/docker` 或你建的共享文件夹 |
| Unraid | `/mnt/user/appdata/...` 或单独的 stacks 目录 |
| QNAP | `/share/Container` 或 `/share/CACHEDEVx_DATA/...` |
| 极空间 / 绿联 / 飞牛等 | 以套件展示的「容器目录 / 映射目录」为准 |

少数派 2026-04 的介绍是在极空间上用官网实例生成器部署的，但文中仍写默认密码 `arcane-admin`，且没有强调「冒号两侧绝对路径必须一致」。3.0 新装请按本章和路径 A 来，不要只复制生成器里过期的默认口令说明。

可选挂载：`/builds`（镜像构建上下文）、`/backups`（本地备份）。命名卷在删除时会连备份一起消失，重要数据不要只放在和容器生命周期绑死的卷里。
