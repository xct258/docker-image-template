#!/bin/bash
# ============================================================
# 容器启动入口（固定模板，无需修改）
#   1. startup/prepare.sh  每次启动容器都执行（重启也执行）
#   2. startup/once.sh     只执行一次（标记文件 /data/.startup-once.done）
#   3. startup/main.sh     容器主进程（exec 前台运行）
#   三个脚本在仓库 startup/ 目录，构建时下载到 /opt/startup
# ============================================================
set -euo pipefail

DIR=/opt/startup
ONCE_MARK=/data/.startup-once.done

mkdir -p /data

# ------------------------------------------------------------
# 0. 补全 PATH
#    安装器（opencode / bun / uv 等）把可执行文件放在 $HOME 下的 bin 目录，
#    只把该目录写进 ~/.bashrc / ~/.profile；容器启动用的是非交互 shell，
#    不会加载这些文件，直接用命令会「未找到」。这里把目录加进 PATH，
#    命令就能直接运行。
# ------------------------------------------------------------
mapfile -t bin_dirs < <(find "${HOME:-/root}" -xdev -path '*/bin/*' \
    -type f -perm -u+x -printf '%h\n' 2>/dev/null | sort -u)
for dir in "${bin_dirs[@]}"; do
    PATH="${dir}:${PATH}"
done
export PATH

# ------------------------------------------------------------
# 0.1 步骤失败处理
#   启动阶段的错误（端口占用、配置写错、依赖没装）重试不会自己好，
#   反复拉起只会刷屏日志。这里打印是哪个脚本失败、退出码多少，然后退出。
#   需要自动拉起就把 compose 的 restart 改成 on-failure:3（见 README）
# ------------------------------------------------------------
run_step() {
    local name=$1 script=$2 code=0
    bash "$script" || code=$?
    if [ "$code" -ne 0 ]; then
        echo "[start] ${name} 失败（exit ${code}），容器退出；修复后执行 docker compose up -d" >&2
        exit "$code"
    fi
}

# ------------------------------------------------------------
# 1. 启动前的准备：每次启动都执行
# ------------------------------------------------------------
echo "[start] prepare"
run_step prepare "${DIR}/prepare.sh"

# ------------------------------------------------------------
# 2. 只执行一次：初始化数据等，成功后写标记，之后不再执行
#    要重新执行就删掉标记文件；标记在 /data 里，随数据卷保留
# ------------------------------------------------------------
if [ -f "$ONCE_MARK" ]; then
    echo "[start] once 已执行过，跳过"
else
    echo "[start] once"
    run_step once "${DIR}/once.sh"
    touch "$ONCE_MARK"
fi

# ------------------------------------------------------------
# 3. 主进程：必须前台运行，docker stop 才能优雅退出
# ------------------------------------------------------------
echo "[start] main"
exec bash "${DIR}/main.sh"
