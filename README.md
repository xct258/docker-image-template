# Docker 镜像模板

只通过 GitHub Actions 构建：**改文件 → push → Actions 自动构建多架构镜像并推送 Docker Hub**，本地不需要安装 Docker。

## 需要改的文件

| 文件 | 作用 |
|---|---|
| `packages.txt` | 系统依赖列表（apt 包名，一行一个） |
| `install.sh` | 自定义依赖安装（下载二进制、编译等，可选） |
| `start.sh` | 容器启动时执行的命令 |
| `image.conf` | 镜像名、基础镜像、构建架构 |

## 一次性准备

1. 修改 `image.conf` 里的 `IMAGE_REPO`（例如 `你的账号/镜像名`）
2. 仓库 Settings → Secrets and variables → Actions，添加：
   - `DOCKERACC`：Docker Hub 账号
   - `DOCKERPWD`：Docker Hub 密码或 Access Token
3. `docker-compose.yml` 里的默认镜像名同步改成一样（或部署时用 `IMAGE_REF` 覆盖）

## 构建

| 触发方式 | 说明 |
|---|---|
| push 到 `main` | 自动构建并推送 |
| Actions 页面 → Run workflow | 手动构建 |
| 每月 1 日 | 定时重建，跟进基础镜像更新 |

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

## start.sh 约定

- 按顺序写命令即可
- 最后一条命令必须 `exec`（前台运行），否则 `docker stop` 无法优雅退出
- 多个常驻进程请拆成多个容器，或用进程管理工具

## install.sh 约定

- 构建镜像时执行一次，适合 apt 装不了的东西
- 可用 `TARGETARCH` 区分 `amd64` / `arm64`
- 记得清理临时文件，减小镜像体积

## 说明

- 基础镜像默认 `xct258/debian-cn`（Debian 系），换镜像时确保有 `apt-get`
- Actions 构建多架构时会自动安装 QEMU，无需本地处理
