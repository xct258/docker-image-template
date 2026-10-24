# Docker 镜像模板

一个极简模板：改三个文件，一条命令出镜像。

| 文件 | 作用 |
|---|---|
| `packages.txt` | 系统依赖列表（apt 包名，一行一个） |
| `install.sh` | 自定义依赖安装（下载二进制、编译等，可选） |
| `start.sh` | 容器启动时执行的命令 |

镜像名、基础镜像、架构、端口在 `image.conf`。

## 使用

```bash
# 1. 写依赖
vim packages.txt

# 2. 写启动命令
vim start.sh

# 3. 构建并运行
./build.sh
./run.sh
```

用 compose：

```bash
./build.sh --env
docker compose up -d
```

## 命令

| 命令 | 说明 |
|---|---|
| `./build.sh` | 构建当前架构，打 `IMAGE_TAG` 和 `dev` 标签 |
| `./build.sh --push` | 多架构构建并推送 `IMAGE_TAG`、`sha-xxx`、日期 |
| `./build.sh --check` | 校验配置和脚本语法 |
| `./build.sh --env` | 生成 `.env` |
| `./build.sh --shell` | 构建后进入容器 `/bin/bash` |
| `./build.sh --no-cache` | 禁用缓存 |
| `./build.sh --tag v1.0.0` | 覆盖 tag |

## start.sh 约定

- 按顺序写命令即可
- 最后一条命令必须 `exec`（前台运行），否则 `docker stop` 无法优雅退出
- 需要多个常驻进程时，自己起守护或拆成多个容器

## 说明

- 基础镜像默认 `xct258/debian-cn`（Debian 系），换镜像时确保有 `apt-get`
- 多架构推送前先 `docker login`
- 本地跨架构构建需要 binfmt/QEMU；CI 里通常由 runner 提供
- `install.sh` 里可用 `TARGETARCH` 区分 amd64 / arm64
