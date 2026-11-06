#!/bin/bash
# ============================================================
# 项目专属：声明要启动的进程（多进程模板）
#
# 约定：
#   SERVICE_NAMES=(名称1 名称2 ...)
#   SERVICE_STOP_TIMEOUT=([名称1]=秒 [名称2]=秒)   # 可选
#   start_<名称>() { run_service <名称> <命令...>; }
#   stop_<名称>()  { ...; }                        # 可选，默认只发 TERM
#
# 每个服务的 stdout/stderr 自动写到 /data/logs/service/<名称>.log。
# 任一服务退出 → 全部停止 → 容器退出 → 由 restart 策略拉起。
# 更新装好后收到 USR1 → 全部停止再重新启动（容器不动）。
# ============================================================

# ------------------------------------------------------------
# 默认单服务示例：直接替换成你自己的命令
# ------------------------------------------------------------
SERVICE_NAMES=(app)
SERVICE_STOP_TIMEOUT=([app]=5)

start_app() {
    run_service app sleep infinity
}

# 需要专用停止命令时取消注释（默认 supervisor 会给进程发 TERM）
# stop_app() {
#     my-service stop
# }

# ------------------------------------------------------------
# 多进程示例：取消注释后把上面的默认示例替换掉
# ------------------------------------------------------------
# SERVICE_NAMES=(mqtt api)
# SERVICE_STOP_TIMEOUT=([mqtt]=5 [api]=15)
#
# start_mqtt() {
#     run_service mqtt mosquitto -c /data/mosquitto.conf
# }
# stop_mqtt() { :; }
#
# start_api() {
#     run_service api uvicorn main:app \
#         --app-dir /data \
#         --host 0.0.0.0 \
#         --port "${PORT:-8080}"
# }
# stop_api() { :; }
