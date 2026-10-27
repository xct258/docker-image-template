#!/bin/bash
# ============================================================
# 自定义安装脚本（构建时执行一次）
#   apt / pip 之外的操作写在这里：下载二进制、编译安装等
#   由 template/install.sh 在 apt / pip 之后调用
#   不需要时把 app.conf 的 INSTALL_CUSTOM 设为 false
# ============================================================
set -euo pipefail

# 目标架构：buildx 注入 TARGETARCH（amd64 / arm64）；单独执行时回退 uname
target_arch="${TARGETARCH:-}"
if [ -z "$target_arch" ]; then
    case "$(uname -m)" in
        x86_64) target_arch=amd64 ;;
        aarch64|arm64) target_arch=arm64 ;;
        *) target_arch="$(uname -m)" ;;
    esac
fi
echo "[custom] 目标架构: ${target_arch}"

# ------------------------------------------------------------
# 示例：按架构下载单个二进制（OpenList）
#   资产名 = openlist-linux-${target_arch}.tar.gz，包内只有 openlist 一个文件
#   加 -lite 后缀可换成精简版（体积更小）
# ------------------------------------------------------------
# echo "[custom] 正在安装 OpenList..."
# url="https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-${target_arch}.tar.gz"
# curl -fsSL --retry 3 --retry-delay 5 "$url" | tar -xzO openlist > /usr/local/bin/openlist
# chmod +x /usr/local/bin/openlist
# echo "[custom] OpenList 安装完成"

echo "[custom] 自定义安装完成"
