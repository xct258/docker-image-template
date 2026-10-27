# Docker 镜像模板

只通过 GitHub Actions 构建：**改文件 → push → 在 Actions 页面手动触发构建多架构镜像并推送 Docker Hub**，本地不需要安装 Docker。

## 目录结构

```
.
├── app.conf              # 唯一配置：镜像名/架构/依赖/启动命令
├── custom-install.sh     # 可选：apt / pip 之外的操作
├── template/             # 固定模板，无需修改
│   ├── Dockerfile
│   ├── install.sh        # 依赖安装（读取 app.conf）
│   └── start.sh          # 容器启动（读取 app.conf）
├── docker-compose.yml    # 部署示例
└── .github/workflows/build-image.yml
```

`template/` 下的文件构建时从仓库下载，**不需要改**；自己的安装步骤写在 `custom-install.sh`，其余都改 `app.conf`。

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
| `START_PREPARE` | 启动前准备命令数组，容器每次启动时执行 |
| `START_CMD` | 启动命令，必须前台运行（`exec`），否则 `docker stop` 无法优雅退出 |

- `PYTHON_PACKAGES` 非空时会自动安装 `python3`、`pip3`，并提供 `python` 命令

- 多个常驻进程请拆成多个容器，或用进程管理工具
- apt / pip 装不了的东西写进 `custom-install.sh`，脚本内可用 `${TARGETARCH}` 区分 `amd64` / `arm64`
- `custom-install.sh` 里装完依赖记得清理临时文件，减小镜像体积

## 说明

- 构建流水线在 `.github/workflows/build-image.yml`，读取 `app.conf` 的配置，通常无需修改
- 构建前会自动校验：必备文件齐全、`app.conf` / `custom-install.sh` 语法正确、`DOCKERACC` / `DOCKERPWD` secrets 已配置，校验失败会给出明确错误
- 构建时不用 `COPY`，而是由 CI 生成 `REPO_URL`（当前仓库的 raw 地址），Dockerfile 用 `wget` 下载 `app.conf` / `custom-install.sh` / `template/install.sh` / `template/start.sh`（`custom-install.sh` 缺失时自动跳过）
- 构建**完全不使用缓存**（CI 构建设 `no-cache`），每次构建都全新执行，保证 wget 下载到最新文件
- 因此**仓库需要是公开的**（private 仓库的 raw 地址需要鉴权，wget 无法直接访问）
- 基础镜像固定为 `xct258/debian-cn`（Debian 系）；要换基础镜像需改 `template/Dockerfile` 的 `FROM`，且新镜像要带 `apt-get`
- Actions 构建多架构时会自动安装 QEMU，无需本地处理
