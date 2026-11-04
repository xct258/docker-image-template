#!/bin/bash
# ============================================================
# 服务管理脚本：启动服务、保持运行、按需重启
#   只需要改 start_service / stop_service 两个函数。
#   模板行为：
#     - 启动后调用 start_service，然后等它启动的进程退出
#     - 更新装好后收到 USR1：stop_service，再重新 start_service
#     - docker stop 收到 TERM：stop_service，然后退出
#   服务自己退出（崩溃）时脚本跟着退出，容器由 restart 策略拉起。
# ============================================================
set -euo pipefail

# 日志模块（构建时下载到 /opt/startup/log.sh）
. "$(dirname "${BASH_SOURCE[0]}")/log.sh"

# ------------------------------------------------------------
# 服务日志：服务的 stdout/stderr 全部写文件，不进 docker logs
#   docker logs 只保留 log -f 的状态行（启动/重启/退出/错误）
#   每天 00:00 把当天的日志归档为 <SERVICE_LOG>-YYYY-MM-DD，
#   只保留最新 SERVICE_LOG_KEEP_DAYS 天（默认 15）
# ------------------------------------------------------------
SERVICE_LOG=${SERVICE_LOG:-/data/logs/service/service.log}
SERVICE_LOG_KEEP_DAYS=${SERVICE_LOG_KEEP_DAYS:-15}
mkdir -p "$(dirname "$SERVICE_LOG")"

rotate_service_log() {
    local archive
    [ -s "$SERVICE_LOG" ] || return 0

    # 00:00 执行，归档的是昨天那一份
    archive="${SERVICE_LOG}-$(date -d yesterday '+%Y-%m-%d')"
    # copytruncate：服务用 >> 打开文件，截断后仍能继续写
    cp "$SERVICE_LOG" "$archive" && : > "$SERVICE_LOG"

    # 只保留最新 N 天
    ls -1t -- "${SERVICE_LOG}"-* 2>/dev/null \
        | tail -n +"$(( SERVICE_LOG_KEEP_DAYS + 1 ))" \
        | xargs -r rm -f --
}

sleep_until_midnight() {
    local now target
    now=$(date +%s)
    target=$(date -d "tomorrow 00:00" +%s 2>/dev/null || echo 0)
    if [ "$target" -gt "$now" ]; then
        sleep "$(( target - now ))"
    else
        sleep 86400
    fi
}

log_rotate_loop() {
    while :; do
        sleep_until_midnight
        rotate_service_log
    done
}

# ------------------------------------------------------------
# 启动后打印一次服务信息到 docker logs（地址 / 端口 / 密码）
#   其余时间 docker logs 只输出：更新重启、异常退出
# ------------------------------------------------------------
print_start_info() {
    log -f success "服务已启动（PID ${svc_pid}）"
    [ -z "${SERVICE_PORT:-}" ] || log -f info "访问端口: ${SERVICE_PORT}"
    [ -z "${SERVICE_PASSWORD:-}" ] || log -f info "密码: ${SERVICE_PASSWORD}"
}

svc_pid=""

# ------------------------------------------------------------
# 自定义区：改成你的启动 / 停止命令
#   启动命令放后台，输出重定向到 $SERVICE_LOG，把 PID 记到 svc_pid。
#   例：my-service --port "${PORT:-8080}" >> "$SERVICE_LOG" 2>&1 &
# ------------------------------------------------------------
start_service() {
    sleep infinity >> "$SERVICE_LOG" 2>&1 &
    svc_pid=$!
}

stop_service() {
    # 有专用停止命令就写在这里；默认给进程发 TERM
    [ -z "$svc_pid" ] || kill -TERM "$svc_pid" 2>/dev/null || true
    [ -z "$svc_pid" ] || wait "$svc_pid" 2>/dev/null || true
}
# ------------------------------------------------------------

log_rotate_loop &
restart_requested=0
first_start=1
trap 'restart_requested=1; stop_service' USR1
trap 'stop_service; exit 143' TERM INT

while :; do
    restart_requested=0
    start_service
    if [ -z "$svc_pid" ]; then
        log -f error "start_service 没有设置 svc_pid"
        exit 1
    fi

    if [ "$first_start" -eq 1 ]; then
        print_start_info
        first_start=0
    else
        log info "服务已重启（PID ${svc_pid}）"
    fi

    code=0
    wait "$svc_pid" 2>/dev/null || code=$?

    if [ "$restart_requested" -eq 1 ]; then
        log -f success "重启服务（应用更新）"
        continue
    fi

    if [ "$code" -ne 0 ]; then
        log -f error "服务异常退出（exit ${code}），容器结束"
    else
        log info "服务已退出（exit 0），容器结束"
    fi
    exit "$code"
done
