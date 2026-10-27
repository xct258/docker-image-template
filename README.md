# Docker 镜像模板

只通过 GitHub Actions 构建：**改文件 → push → 在 Actions 页面手动触发构建多架构镜像并推送 Docker Hub**，本地不需要安装 Docker。

## 目录结构

```
.
├── app.conf              # 配置：镜像名/架构/依赖
├── custom-install.sh     # 可选：构建时执行一次（apt / pip 之外）
├── startup/              # 启动流程，按需修改
│   ├── prepare.sh        # 每次启动都执行
│   ├── once.sh           # 只执行一次
│   └── main.sh           # 容器主进程
├── template/             # 固定模板，无需修改
│   ├── Dockerfile
│   ├── install.sh        # 依赖安装（读取 app.conf）
│   └── start.sh          # 依次调用 startup/ 下的三个脚本
├── docker-compose.yml    # 部署示例
└── .github/workflows/build-image.yml
```

`template/` 下的文件构建时从仓库下载，**不需要改**。

## 启动流程

容器启动时 `template/start.sh` 按顺序执行 `startup/` 下的三个脚本：

| 脚本 | 执行时机 | 放什么 |
|---|---|---|
| `prepare.sh` | **每次**启动（含 `docker restart`） | 设密码、改配置、建目录等可重复执行的操作 |
| `once.sh` | **只执行一次**（标记文件 `/data/.startup-once.done`） | 初始化数据、生成配置、建表/迁移等不能重复执行的操作 |
| `main.sh` | 每次启动，作为容器主进程 | 真正的启动命令，最后一行用 `exec` |

- `once.sh` 成功后才写标记；想重新执行就删掉 `/data/.startup-once.done` 再重启
- 标记在 `/data` 里，跟着数据卷走；没挂卷时等同于每个容器一次
- 任一脚本失败（非 0 退出）容器就不会启动，便于尽早发现错误

## 一次性准备

1. 修改 `app.conf` 里的 `IMAGE_REPO`（例如 `你的账号/镜像名`）
2. 仓库 Settings → Secrets and variables → Actions，添加：
   - `DOCKERACC`：Docker Hub 账号
   - `DOCKERPWD`：Docker Hub 密码或 Access Token
3. `docker-compose.yml` 里的默认镜像名同步改成一样（或部署时用 `IMAGE_REF` 覆盖）

## 构建

| 触发方式 | 说明 |
|---|---|
| Actions 页面 → Run workflow | 手动构建（唯一触发方式） |

每次构建推送三个标签：

```
<IMAGE_REPO>:<IMAGE_TAG>
<IMAGE_REPO>:latest
<IMAGE_REPO>:sha-<7位提交号>
```

构建失败或日志都在仓库的 Actions 页面查看。

## 部署

```bash
docker compose up -d
```

端口、挂载在 `docker-compose.yml` 里按需取消注释：

```yaml
    ports:
      - "8080:80"
    volumes:
      - ./data:/data
```

## 环境变量

在 `docker-compose.yml` 的 `environment:` 下面加键值，容器里直接就能用：

```yaml
    environment:
      TZ: Asia/Shanghai
      PORT: 8080
```

改完 `docker compose up -d` 生效，不用重建镜像。容器里的脚本/程序按变量名读取：

```bash
# startup/prepare.sh
[ -z "${OPENCODE_PASSWORD:-}" ] || opencode service set password "$OPENCODE_PASSWORD"

# startup/main.sh
exec opencode serve --port "${PORT:-8080}"
```

## app.conf 约定

| 配置项 | 作用 |
|---|---|
| `IMAGE_REPO` | 推送到 Docker Hub 的镜像名，如 `账号/镜像名` |
| `IMAGE_TAG` | 镜像标签 |
| `PLATFORMS` | 构建架构，如 `linux/amd64,linux/arm64` |
| `APT_PACKAGES` | apt 系统依赖，**一行一个** |
| `INSTALL_7Z` | 快捷安装 7-Zip（`true` / `false`，自动按架构下载最新版） |
| `PYTHON_PACKAGES` | Python 依赖（pip 包，**一行一个**）；非空时自动安装 Python3 并 pip 安装 |
| `INSTALL_CUSTOM` | 是否执行 `custom-install.sh`（`true` / `false`），构建时执行一次 |

- `PYTHON_PACKAGES` 非空时会自动安装 `python3`、`pip3`，并提供 `python` 命令

- 多个常驻进程请拆成多个容器，或用进程管理工具；`main.sh` 必须前台运行（`exec`），否则 `docker stop` 无法优雅退出
- apt / pip 装不了的东西写进 `custom-install.sh`，脚本内可用 `${TARGETARCH}` 区分 `amd64` / `arm64`
- 项目命名不是 `amd64` / `arm64` 时用脚本里的 `arch_name` 映射，如 `arch_name x64 aarch64`
- `custom-install.sh` 里装完依赖记得清理临时文件，减小镜像体积

## 说明

- 构建流水线在 `.github/workflows/build-image.yml`，读取 `app.conf` 的配置，通常无需修改
- 构建前会自动校验：必备文件齐全、`app.conf` / `custom-install.sh` 语法正确、`DOCKERACC` / `DOCKERPWD` secrets 已配置，校验失败会给出明确错误
- 构建时不用 `COPY`，而是由 CI 生成 `REPO_URL`（当前仓库的 raw 地址），Dockerfile 用 `wget` 下载 `app.conf` / `custom-install.sh` / `startup/*.sh` / `template/install.sh` / `template/start.sh`（`custom-install.sh` 缺失时自动跳过）
- 构建**完全不使用缓存**（CI 构建设 `no-cache`），每次构建都全新执行，保证 wget 下载到最新文件
- 因此**仓库需要是公开的**（private 仓库的 raw 地址需要鉴权，wget 无法直接访问）
- 基础镜像固定为 `xct258/debian-cn`（Debian 系）；要换基础镜像需改 `template/Dockerfile` 的 `FROM`，且新镜像要带 `apt-get`
- Actions 构建多架构时会自动安装 QEMU，无需本地处理
