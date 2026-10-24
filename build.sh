#!/usr/bin/env bash
# ============================================================
# 构建入口
#   ./build.sh            本地构建（当前架构）
#   ./build.sh --push     多架构构建并推送
# ============================================================
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

PUSH=0
CHECK_ONLY=0
ENV_ONLY=0
SHELL_MODE=0
NO_CACHE=0
TAG_OVERRIDE=""

die() { printf '[build] 错误: %s\n' "$*" >&2; exit 1; }
info() { printf '[build] %s\n' "$*"; }
warn() { printf '[build] 警告: %s\n' "$*" >&2; }

usage() {
    cat <<'EOF'
用法: ./build.sh [选项]

选项:
  --push         多架构构建并推送（需 docker login）
  --tag TAG      覆盖镜像 tag
  --check        只做配置和脚本校验
  --env          生成 .env（供 docker compose 使用）
  --shell        构建后进入容器 /bin/bash
  --no-cache     不使用构建缓存
  -h, --help     显示帮助
EOF
}

while (($# > 0)); do
    case "$1" in
        --push)     PUSH=1 ;;
        --check)    CHECK_ONLY=1 ;;
        --env)      ENV_ONLY=1 ;;
        --shell)    SHELL_MODE=1 ;;
        --no-cache) NO_CACHE=1 ;;
        --tag)      shift; (($# > 0)) || die "--tag 缺少参数"; TAG_OVERRIDE="$1" ;;
        --tag=*)    TAG_OVERRIDE="${1#*=}" ;;
        -h|--help)  usage; exit 0 ;;
        *)          die "未知参数: $1（--help 查看用法）" ;;
    esac
    shift
done

[ -f "${ROOT}/image.conf" ] || die "缺少 image.conf"

# shellcheck source=/dev/null
source "${ROOT}/image.conf"

[ -n "${IMAGE_REPO:-}" ] || die "image.conf 缺少 IMAGE_REPO"
IMAGE_TAG="${IMAGE_TAG:-latest}"
BASE_IMAGE="${BASE_IMAGE:-xct258/debian-cn:latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
CONTAINER_NAME="${CONTAINER_NAME:-app}"
PORT="${PORT:-}"

case "${BASE_IMAGE}" in
    *@sha256:*|*:*) ;;
    *) die "BASE_IMAGE 必须指定 tag 或 digest: ${BASE_IMAGE}" ;;
esac

if [ -n "${PORT}" ]; then
    [[ "${PORT}" =~ ^[0-9]+$ ]] || die "PORT 必须是数字: ${PORT}"
    ((PORT >= 1 && PORT <= 65535)) || die "PORT 超出范围(1-65535): ${PORT}"
fi

for f in packages.txt install.sh start.sh; do
    [ -f "${ROOT}/${f}" ] || die "缺少 ${f}"
done

for f in install.sh start.sh; do
    bash -n "${ROOT}/${f}" || die "语法错误: ${f}"
    [ -x "${ROOT}/${f}" ] || warn "未设置可执行位: ${f}（建议 chmod +x）"
done
bash -n "${ROOT}/build.sh" || die "语法错误: build.sh"

info "配置校验通过: ${IMAGE_REPO}"

if [ "${CHECK_ONLY}" = "1" ]; then
    exit 0
fi

IMAGE_VERSION="${TAG_OVERRIDE:-${IMAGE_TAG}}"
REVISION="$(git -C "${ROOT}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
BUILD_DATE="$(date +%Y%m%d)"

if [ "${ENV_ONLY}" = "1" ]; then
    cat > "${ROOT}/.env" <<EOF
# 由 build.sh 生成，请勿提交
IMAGE_REF=${IMAGE_REPO}:${IMAGE_VERSION}
CONTAINER_NAME=${CONTAINER_NAME}
PORT=${PORT}
EOF
    info "已生成 .env"
    exit 0
fi

command -v docker >/dev/null 2>&1 || die "未找到 docker"
docker buildx version >/dev/null 2>&1 || die "需要 docker buildx"

TAGS=("${IMAGE_REPO}:${IMAGE_VERSION}")
if [ "${PUSH}" = "1" ]; then
    TAGS+=("${IMAGE_REPO}:sha-${REVISION}" "${IMAGE_REPO}:${BUILD_DATE}")
else
    TAGS+=("${IMAGE_REPO}:dev")
fi

BUILD_ARGS=(
    --build-arg "BASE_IMAGE=${BASE_IMAGE}"
)

COMMON=(
    --file "${ROOT}/Dockerfile"
    "${BUILD_ARGS[@]}"
)

[ "${NO_CACHE}" = "1" ] && COMMON+=(--no-cache)

for tag in "${TAGS[@]}"; do
    COMMON+=(--tag "${tag}")
done

if [ "${PUSH}" = "1" ]; then
    BUILDER_NAME="${BUILDX_BUILDER:-docker-template-multiarch}"
    BUILDER_ARGS=()
    if [ "${BUILDER_NAME}" != "default" ]; then
        if ! docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
            info "创建 buildx 构建器: ${BUILDER_NAME}"
            docker buildx create --name "${BUILDER_NAME}" --driver docker-container >/dev/null
        fi
        BUILDER_ARGS=(--builder "${BUILDER_NAME}")
    fi

    info "多架构构建并推送: ${PLATFORMS}"
    info "标签: ${TAGS[*]}"
    docker buildx build \
        "${BUILDER_ARGS[@]}" \
        "${COMMON[@]}" \
        --platform "${PLATFORMS}" \
        --push \
        "${ROOT}"
else
    case "$(uname -m)" in
        x86_64|amd64)  HOST_PLATFORM="linux/amd64" ;;
        aarch64|arm64) HOST_PLATFORM="linux/arm64" ;;
        *)             HOST_PLATFORM="linux/amd64" ;;
    esac
    info "本地构建（${HOST_PLATFORM}）"
    info "标签: ${TAGS[*]}"
    docker buildx build \
        "${COMMON[@]}" \
        --platform "${HOST_PLATFORM}" \
        --load \
        "${ROOT}"
fi

info "构建完成"

if [ "${SHELL_MODE}" = "1" ]; then
    exec docker run --rm -it --entrypoint /bin/bash "${IMAGE_REPO}:${IMAGE_VERSION}"
fi
