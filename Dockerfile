# ============================================================
# 通用镜像模板
#   应用配置 -> app.conf（唯一需要修改的文件）
#   依赖安装 -> install.sh（固定模板，读取 app.conf）
#   启动命令 -> start.sh（固定模板，读取 app.conf）
#   三个文件构建时从仓库下载（REPO_URL 由 CI 传入）
# ============================================================

FROM xct258/debian-cn:latest

ENV DEBIAN_FRONTEND=noninteractive

# 下载 install.sh / start.sh / app.conf 的仓库地址（由 CI 传入，必须提供）
ARG REPO_URL

# ------------------------------------------------------------
# 0. 应用配置（构建时 install.sh 读取，运行时 start.sh 读取）
# ------------------------------------------------------------
RUN set -eux; \
    mkdir -p /app; \
    wget -qO /app/app.conf "${REPO_URL}/app.conf"

# ------------------------------------------------------------
# 1. 依赖安装（构建时执行一次）
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
