#!/bin/bash
# ============================================================
# 自定义依赖安装（构建镜像时执行一次）
# 适用于 apt 装不了的东西：下载二进制、编译安装、语言运行时等
#
# 示例：
#   curl -fsSL -o /usr/local/bin/foo https://example.com/foo
#   chmod +x /usr/local/bin/foo
#
# 需要按架构区分时用 ${TARGETARCH}（amd64 / arm64）
# ============================================================
set -euo pipefail

echo "[install] 当前没有自定义依赖"
