#!/bin/bash
# ============================================================
# 容器启动命令（固定模板，无需修改）
#   实际配置在 app.conf：START_PREPARE / START_CMD
# ============================================================
set -euo pipefail

CONF=/app/app.conf
if [ ! -f "$CONF" ]; then
    echo "[start] 错误：未找到 ${CONF}" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$CONF"

# ------------------------------------------------------------
# 1. 启动前准备
# ------------------------------------------------------------
mkdir -p /data
if declare -p START_PREPARE >/dev/null 2>&1; then
    for cmd in "${START_PREPARE[@]}"; do
        [ -n "$cmd" ] && { echo "[start] 执行: ${cmd}"; eval "$cmd"; }
    done
fi

# ------------------------------------------------------------
# 2. 启动服务（必须前台运行，docker stop 才能优雅退出）
# ------------------------------------------------------------
exec ${START_CMD:-sleep infinity}
