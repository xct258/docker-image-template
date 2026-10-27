# ============================================================
# 通用镜像模板
#   依赖安装 -> install.sh（构建时从仓库下载）
#   启动命令 -> start.sh（构建时从仓库下载）
#   下载地址由 Actions 通过 build-args 传入 REPO_URL
# ============================================================

FROM xct258/debian-cn:latest

ENV DEBIAN_FRONTEND=noninteractive

# 下载 install.sh / start.sh 的仓库地址（由 CI 传入，必须提供）
ARG REPO_URL

# ------------------------------------------------------------
# 1. 依赖安装（apt 系统依赖 + 自定义依赖，构建时执行一次）
# ------------------------------------------------------------
RUN set -eux; \
    if ! command -v wget >/dev/null 2>&1; then \
        apt-get update; \
        apt-get install -y --no-install-recommends wget; \
        rm -rf /var/lib/apt/lists/*; \
    fi; \
    wget -qO /tmp/install.sh "${REPO_URL}/install.sh"; \
    chmod +x /tmp/install.sh; \
    /tmp/install.sh; \
    rm -f /tmp/install.sh

# ------------------------------------------------------------
# 2. 启动命令
# ------------------------------------------------------------
RUN set -eux; \
    wget -qO /start.sh "${REPO_URL}/start.sh"; \
    chmod +x /start.sh

WORKDIR /app
ENTRYPOINT ["/start.sh"]
