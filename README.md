# Docker 镜像模板

只通过 GitHub Actions 构建：**改文件 → push → 在 Actions 页面手动触发构建多架构镜像并推送 Docker Hub**，本地不需要安装 Docker。

## 需要改的文件

| 文件 | 作用 |
|---|---|
| `app.conf` | **应用配置**：apt 依赖、自定义安装命令、启动前准备、启动命令 |
| `image.conf` | 构建配置：镜像名、构建架构 |

`install.sh` / `start.sh` 是固定模板，构建时从仓库下载，**无需修改**。

## 一次性准备

1. 修改 `image.conf` 里的 `IMAGE_REPO`（例如 `你的账号/镜像名`）
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
| `APT_PACKAGES` | apt 系统依赖，空格分隔 |
| `CUSTOM_INSTALL` | 自定义安装命令数组，构建时执行一次（下载二进制、编译等） |
| `START_PREPARE` | 启动前准备命令数组，容器每次启动时执行 |
| `START_CMD` | 启动命令，必须前台运行（`exec`），否则 `docker stop` 无法优雅退出 |

- 多个常驻进程请拆成多个容器，或用进程管理工具
- 自定义安装可用 `TARGETARCH` 区分 `amd64` / `arm64`
- 装完依赖记得清理临时文件，减小镜像体积

## 说明

- 构建流水线在 `.github/workflows/build-image.yml`，读取 `image.conf` 的配置，通常无需修改
- 构建前会自动校验：必备文件齐全、`app.conf` / `image.conf` 语法正确、`DOCKERACC` / `DOCKERPWD` secrets 已配置，校验失败会给出明确错误
- 构建时不用 `COPY`，而是由 CI 生成 `REPO_URL`（当前仓库的 raw 地址），Dockerfile 用 `wget` 下载 `app.conf` / `install.sh` / `start.sh`
- 构建**完全不使用缓存**（CI 构建设 `no-cache`），每次构建都全新执行，保证 wget 下载到最新文件
- 因此**仓库需要是公开的**（private 仓库的 raw 地址需要鉴权，wget 无法直接访问）
- 基础镜像固定为 `xct258/debian-cn`（Debian 系）；要换基础镜像需改 `Dockerfile` 的 `FROM`，且新镜像要带 `apt-get`
- Actions 构建多架构时会自动安装 QEMU，无需本地处理
