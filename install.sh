#!/bin/bash
# ============================================================
# 依赖安装（固定模板，无需修改）
#   配置在 app.conf：APT_PACKAGES / PYTHON_PACKAGES / CUSTOM_INSTALL
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
# 1. 收集 pip 依赖（非空则自动安装 Python）
# ------------------------------------------------------------
py_pkgs=()
if declare -p PYTHON_PACKAGES >/dev/null 2>&1; then
    for p in "${PYTHON_PACKAGES[@]}"; do
        if [ -n "$p" ]; then py_pkgs+=("$p"); fi
    done
fi

# ------------------------------------------------------------
# 2. 收集 apt 依赖（系统依赖 + 有 pip 依赖时的 Python 运行时）
# ------------------------------------------------------------
apt_pkgs=()
if declare -p APT_PACKAGES >/dev/null 2>&1; then
    for p in "${APT_PACKAGES[@]}"; do
        if [ -n "$p" ]; then apt_pkgs+=("$p"); fi
    done
fi
if [ "${#py_pkgs[@]}" -gt 0 ]; then
    apt_pkgs+=(python3 python3-pip python-is-python3)
fi

if [ "${#apt_pkgs[@]}" -gt 0 ]; then
    echo "[install] apt 安装: ${apt_pkgs[*]}"
    apt-get update
    apt-get install -y --no-install-recommends "${apt_pkgs[@]}"
    rm -rf /var/lib/apt/lists/*
fi

# ------------------------------------------------------------
# 3. Python 依赖（pip）
# ------------------------------------------------------------
if [ "${#py_pkgs[@]}" -gt 0 ]; then
    echo "[install] pip 安装: ${py_pkgs[*]}"
    # Debian 12+ 受 PEP 668 限制，需 --break-system-packages（容器内可接受）
    if ls /usr/lib/python3*/EXTERNALLY-MANAGED >/dev/null 2>&1; then
        pip3 install --no-cache-dir --break-system-packages "${py_pkgs[@]}"
    else
        pip3 install --no-cache-dir "${py_pkgs[@]}"
    fi
fi

# ------------------------------------------------------------
# 4. 自定义安装命令
# ------------------------------------------------------------
if declare -p CUSTOM_INSTALL >/dev/null 2>&1; then
    for cmd in "${CUSTOM_INSTALL[@]}"; do
        if [ -n "$cmd" ]; then
            echo "[install] 执行: ${cmd}"
            eval "$cmd"
        fi
    done
fi

echo "[install] 依赖安装完成"
