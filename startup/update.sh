#!/bin/bash
# ============================================================
# 自动更新（可选，启动时执行；设置 UPDATE_INTERVAL_DAYS 后运行期也按天执行）
#   由 template/start.sh 在 prepare 之后、once 之前调用；UPDATE_INTERVAL_DAYS > 0
#   时还会在后台按固定天数重复调用。由这个脚本自己决定查什么、怎么更新。
#   退出码约定：
#     0    -> 没有变化（已是最新）
#     10   -> 装了新版本（启动时直接生效；定时检查在 UPDATE_CHECK_AT，装好立即重启）
#     其它 -> 失败：启动时默认只告警、旧版本继续启动（UPDATE_STRICT=1 才阻塞）
#     超过 UPDATE_TIMEOUT（默认 60s） -> 被终止，按失败处理
#   写这个脚本时注意：
#     * 没有网络时要尽快跳过，别把启动拖住（curl 加 --max-time）
#     * 只在真的有更新时用 log -f，正常检查用 log info（只进文件）
#     * 运行期更新时服务正在跑：用 mv 原子替换二进制，别直接写原文件
#       （正在执行的文件会 ETXTBSY）。返回 10 后模板默认会自动重启服务
#       （UPDATE_RESTART=0 可关闭，改成下次重启时机生效）
#     * 更新装进容器层，重建容器会回到镜像里的版本；要保留就装到挂载卷
#       （如 /data/bin），再用 EXTRA_PATH_DIRS 加进 PATH
#     * 多实例共用 /data 时模板已经用 flock 串行，脚本里不用再加锁
# ============================================================
set -euo pipefail

# 日志模块（构建时下载到 /opt/startup/log.sh）
. "$(dirname "${BASH_SOURCE[0]}")/log.sh"

# ------------------------------------------------------------
# 示例 1：opencode
#   当前版本用 --version 取；最新版本取自安装器的更新接口；
#   安装时固定到该版本，避免检查完又装成另一个版本。
#   注意：装到 $HOME/.opencode/bin，重建容器会回滚到镜像里的版本。
# ------------------------------------------------------------
# cur=$(opencode --version 2>/dev/null | awk '{print $NF}' | sed 's/^v//' || true)
# latest=$(curl -fsSL --max-time 10 https://opencode.ai/update/api/latest/cli/npm 2>/dev/null \
#     | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' | head -1)
# if [ -z "$latest" ]; then
#     log -f warn "获取 opencode 最新版本失败，跳过更新"
# elif [ "$cur" = "$latest" ]; then
#     log info "opencode 已是最新（${cur}）"
# else
#     log -f success "更新 opencode：${cur:-未安装} -> ${latest}"
#     curl -fsSL --max-time 300 https://opencode.ai/v2/install | bash -s -- --version "$latest"
#     exit 10   # 告诉模板「装了新版本」
# fi

# ------------------------------------------------------------
# 示例 2：GitHub Releases
#   asset 名里带版本号时，先从 releases/latest 的 tag 取版本再拼 URL。
#   这里用 sed 解析 JSON，免装 jq。
# ------------------------------------------------------------
# repo=owner/foo
# arch=$(uname -m)
# case "$arch" in
#     x86_64) arch=amd64 ;;
#     aarch64 | arm64) arch=arm64 ;;
# esac
# cur=$(foo --version 2>/dev/null | awk '{print $NF}' || true)
# latest=$(curl -fsSL --max-time 10 "https://api.github.com/repos/${repo}/releases/latest" \
#     | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1)
# if [ -z "$latest" ]; then
#     log -f warn "查询 ${repo} 最新版本失败，跳过更新"
# elif [ "$cur" = "$latest" ]; then
#     log info "foo 已是最新（${cur}）"
# else
#     log -f success "更新 foo：${cur:-未安装} -> ${latest}"
#     tmp=$(mktemp)
#     curl -fsSL --max-time 300 \
#         "https://github.com/${repo}/releases/download/v${latest}/foo_${latest}_linux_${arch}.tar.gz" \
#         | tar -xzO foo > "$tmp"
#     chmod +x "$tmp"
#     mv "$tmp" /usr/local/bin/foo   # 原子替换，不会影响正在运行的旧进程
#     exit 10   # 告诉模板「装了新版本」
# fi

# 示例都没启用时保持空操作。启用上面任意一段后删掉这行。
log info "没有配置更新逻辑，跳过"
