#!/bin/bash
# ============================================================
# 依赖安装（固定模板，无需修改）
#   实际配置在 app.conf：APT_PACKAGES / CUSTOM_INSTALL
# ============================================================
set -euo pipefail

CONF=/app/app.conf
if [ ! -f "$CONF" ]; then
    echo "[install] 错误：未找到 ${CONF}" >&2
    exit 1
fi
# shellcheck disable=SC1090
source "$CONF"

# ------------------------------------------------------------
# 1. 系统依赖（apt）
# ------------------------------------------------------------
if [ -n "${APT_PACKAGES:-}" ]; then
    echo "[install] apt 安装: ${APT_PACKAGES}"
    apt-get update
    # shellcheck disable=SC2086
    apt-get install -y --no-install-recommends ${APT_PACKAGES}
    rm -rf /var/lib/apt/lists/*
fi

# ------------------------------------------------------------
# 2. 自定义安装命令
# ------------------------------------------------------------
if declare -p CUSTOM_INSTALL >/dev/null 2>&1; then
    for cmd in "${CUSTOM_INSTALL[@]}"; do
        [ -n "$cmd" ] && { echo "[install] 执行: ${cmd}"; eval "$cmd"; }
    done
fi

echo "[install] 依赖安装完成"
