# ============================================================
# 通用镜像模板（固定文件，无需修改）
#   构建期 -> install/：app.conf / install.sh / custom-install.sh
#   运行期 -> startup/：prepare.sh / once.sh / main.sh
#   入口   -> template/start.sh
#   以上文件构建时从仓库下载（REPO_URL 由 CI 传入）
# ============================================================

FROM xct258/debian-cn:latest

ENV DEBIAN_FRONTEND=noninteractive

# 下载脚本与配置的仓库地址（由 CI 传入，必须提供）
ARG REPO_URL

# 目标架构（buildx 按平台自动注入，供快捷安装脚本选择对应架构的包）
ARG TARGETARCH

# ------------------------------------------------------------
# 下载配置与启动脚本 + 依赖安装（合并为一个 RUN，减少镜像层数）
#   构建不启用缓存（CI 的 no-cache），因此每次都重新下载最新文件
# ------------------------------------------------------------
# 注意：wget 的 CA 证书属于 Recommended，--no-install-recommends 不会带上，
# 缺了会让 https 下载报证书错误（wget exit 5），所以这里固定一起装
RUN set -eux; \
    mkdir -p /app; \
    if ! command -v wget >/dev/null 2>&1 || [ ! -e /etc/ssl/certs/ca-certificates.crt ]; then \
        apt-get update; \
        apt-get install -y --no-install-recommends wget ca-certificates; \
        rm -rf /var/lib/apt/lists/*; \
    fi; \
    fetch() { \
        wget -nv --tries=3 --waitretry=5 --timeout=30 -O "$2" "$1" || { \
            echo "[fetch] 下载失败（exit $?）：$1" >&2; \
            exit 1; \
        }; \
    }; \
    fetch "${REPO_URL}/install/app.conf" /app/app.conf; \
    if ! wget -q --tries=3 --timeout=30 -O /app/custom-install.sh "${REPO_URL}/install/custom-install.sh"; then \
        rm -f /app/custom-install.sh; \
    fi; \
    mkdir -p /app/startup; \
    for f in prepare.sh once.sh main.sh; do \
        fetch "${REPO_URL}/startup/${f}" "/app/startup/${f}"; \
    done; \
    fetch "${REPO_URL}/install/install.sh" /tmp/install.sh; \
    chmod +x /tmp/install.sh; \
    /tmp/install.sh; \
    rm -f /tmp/install.sh; \
    fetch "${REPO_URL}/template/start.sh" /start.sh; \
    chmod +x /start.sh

# 工作目录不在这里固定，默认是 /；需要固定时用 compose 的 working_dir 指定
ENTRYPOINT ["/start.sh"]
