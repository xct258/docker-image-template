#!/bin/bash
# ============================================================
# 依赖安装（构建镜像时执行一次）
# 负责所有依赖：系统依赖（apt 包）+ 自定义依赖（下载二进制、编译安装等）
#
# 1) 系统依赖：把 apt 包名直接写在脚本里
#    apt-get update
#    apt-get install -y --no-install-recommends 包名1 包名2
#
# 2) 自定义依赖：apt 装不了的东西
#    curl -fsSL -o /usr/local/bin/foo https://example.com/foo
#    chmod +x /usr/local/bin/foo
#
# 需要按架构区分时用 ${TARGETARCH}（amd64 / arm64）
# 记得清理临时文件（apt 缓存、下载的压缩包等），减小镜像体积
# ============================================================
set -euo pipefail

# 系统依赖
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl
rm -rf /var/lib/apt/lists/*

echo "[install] 依赖安装完成"
