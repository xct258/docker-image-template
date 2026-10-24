# ============================================================
# 通用镜像模板
#   系统依赖 -> packages.txt
#   自定义依赖 -> install.sh
#   启动命令 -> start.sh
# ============================================================

ARG BASE_IMAGE=xct258/debian-cn:latest
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# 1. 系统依赖
# ------------------------------------------------------------
COPY packages.txt /tmp/packages.txt
RUN set -eux; \
    packages="$(grep -vE '^[[:space:]]*(#|$)' /tmp/packages.txt | tr '\n' ' ')"; \
    if [ -n "${packages}" ]; then \
        apt-get update; \
        apt-get install -y --no-install-recommends ${packages}; \
        rm -rf /var/lib/apt/lists/*; \
    fi; \
    rm -f /tmp/packages.txt

# ------------------------------------------------------------
# 2. 自定义依赖
# ------------------------------------------------------------
COPY install.sh /tmp/install.sh
RUN chmod +x /tmp/install.sh && /tmp/install.sh && rm -f /tmp/install.sh

# ------------------------------------------------------------
# 3. 启动命令
# ------------------------------------------------------------
COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /app
ENTRYPOINT ["/start.sh"]
