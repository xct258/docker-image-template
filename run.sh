#!/usr/bin/env bash
# ============================================================
# 本地运行：前台启动容器
# 额外参数用 -- 分隔，会原样传给 docker run
#   ./run.sh -- -p 8080:80 -v "$PWD/data:/data"
# ============================================================
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

[ -f "${ROOT}/image.conf" ] || {
    printf '[run] 错误: 未找到 image.conf\n' >&2
    exit 1
}
# shellcheck source=/dev/null
source "${ROOT}/image.conf"

shift || true
[ "${1:-}" = "--" ] && shift

IMAGE_TAG="${IMAGE_TAG:-latest}"
# shellcheck disable=SC2153  # 变量来自 source 的 image.conf
IMAGE_REF="${IMAGE_REPO}:${IMAGE_TAG}"
CONTAINER_NAME="${CONTAINER_NAME:-app}"

printf '[run] 启动 %s（Ctrl+C 停止）\n' "${IMAGE_REF}"
exec docker run --rm -it \
    --name "${CONTAINER_NAME}" \
    "${IMAGE_REF}" "$@"
