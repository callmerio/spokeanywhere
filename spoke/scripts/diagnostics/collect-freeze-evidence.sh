#!/bin/bash
# Freeze/Hang 证据采集脚本
# 用于收集启动卡死、运行时卡顿的诊断证据

set -euo pipefail

# 配置
EVIDENCE_DIR="${EVIDENCE_DIR:-/tmp/spoke-freeze-evidence}"
APP_NAME="SpokenAnyWhere"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
EVIDENCE_PACKAGE="${EVIDENCE_DIR}/${TIMESTAMP}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建证据包目录
mkdir -p "${EVIDENCE_PACKAGE}"
log_info "证据包目录: ${EVIDENCE_PACKAGE}"

# 1. 系统信息
log_info "收集系统信息..."
{
    echo "=== System Information ==="
    echo "Date: $(date)"
    echo "macOS Version: $(sw_vers -productVersion)"
    echo "Build: $(sw_vers -buildVersion)"
    echo "Hostname: $(hostname)"
    echo ""
} > "${EVIDENCE_PACKAGE}/system-info.txt"

# 2. 进程信息
log_info "收集进程信息..."
if pgrep -x "${APP_NAME}" > /dev/null; then
    APP_PID=$(pgrep -x "${APP_NAME}")
    log_info "发现进程 PID: ${APP_PID}"

    # 进程状态
    ps -p "${APP_PID}" -o pid,ppid,user,%cpu,%mem,vsz,rss,tt,stat,start,time,command > "${EVIDENCE_PACKAGE}/process-info.txt"

    # 线程信息
    ps -M -p "${APP_PID}" > "${EVIDENCE_PACKAGE}/thread-info.txt" 2>&1 || log_warn "无法获取线程信息"

    # 打开的文件描述符
    lsof -p "${APP_PID}" > "${EVIDENCE_PACKAGE}/open-files.txt" 2>&1 || log_warn "无法获取文件描述符信息"

    # 采样（5秒）
    log_info "采样进程（5秒）..."
    sample "${APP_PID}" 5 -file "${EVIDENCE_PACKAGE}/sample.txt" 2>&1 || log_warn "采样失败"

    # 堆栈快照（非交互模式，避免阻塞）
    log_info "获取堆栈快照..."
    if sudo -n spindump "${APP_PID}" -file "${EVIDENCE_PACKAGE}/spindump.txt" 2>&1; then
        log_info "spindump 成功"
    else
        log_warn "spindump 失败（需要 sudo 权限或使用 sudo -v 预授权）"
    fi
else
    log_warn "未找到运行中的 ${APP_NAME} 进程"
    echo "Process not running at collection time" > "${EVIDENCE_PACKAGE}/process-info.txt"
fi

# 3. 系统日志（最近 5 分钟）
log_info "收集系统日志..."
log show --predicate 'subsystem == "com.spokeanywhere"' --last 5m --style syslog > "${EVIDENCE_PACKAGE}/system-log.txt" 2>&1 || log_warn "无法获取系统日志"

# 4. Console 日志（启动相关）
log_info "收集启动日志..."
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "Launch"' --last 10m --style syslog > "${EVIDENCE_PACKAGE}/launch-log.txt" 2>&1 || log_warn "无法获取启动日志"

# 5. 崩溃报告（如果有）
log_info "检查崩溃报告..."
CRASH_DIR="${HOME}/Library/Logs/DiagnosticReports"
if [ -d "${CRASH_DIR}" ]; then
    find "${CRASH_DIR}" -name "${APP_NAME}*.crash" -mtime -1 -exec cp {} "${EVIDENCE_PACKAGE}/" \; 2>&1 || log_warn "无法复制崩溃报告"
fi

# 6. 开发日志（如果存在）
log_info "检查开发日志..."
# 基于脚本目录推导 repo 根路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEV_LOG_DIR="${DEV_LOG_DIR:-${REPO_ROOT}/.tmp_frames}"
if [ -d "${DEV_LOG_DIR}" ]; then
    find "${DEV_LOG_DIR}" -name "dev-*.log" -mtime -1 -exec cp {} "${EVIDENCE_PACKAGE}/" \; 2>&1 || log_warn "无法复制开发日志"
else
    log_warn "开发日志目录不存在: ${DEV_LOG_DIR}"
fi

# 7. 资源使用情况
log_info "收集资源使用情况..."
{
    echo "=== CPU & Memory ==="
    top -l 1 -n 10 -o cpu
    echo ""
    echo "=== Disk Usage ==="
    df -h
    echo ""
    echo "=== Memory Pressure ==="
    vm_stat
} > "${EVIDENCE_PACKAGE}/resource-usage.txt"

# 8. 音频设备状态
log_info "收集音频设备状态..."
{
    echo "=== Audio Devices ==="
    system_profiler SPAudioDataType
} > "${EVIDENCE_PACKAGE}/audio-devices.txt" 2>&1 || log_warn "无法获取音频设备信息"

# 9. 权限状态
log_info "检查权限状态..."
{
    echo "=== TCC Permissions ==="
    echo "Microphone:"
    tccutil list Microphone 2>&1 || echo "无法查询"
    echo ""
    echo "Screen Recording:"
    tccutil list ScreenCapture 2>&1 || echo "无法查询"
    echo ""
    echo "Accessibility:"
    tccutil list Accessibility 2>&1 || echo "无法查询"
} > "${EVIDENCE_PACKAGE}/permissions.txt"

# 10. 生成摘要
log_info "生成证据摘要..."
{
    echo "=== Freeze/Hang Evidence Summary ==="
    echo "Collection Time: ${TIMESTAMP}"
    echo "Evidence Package: ${EVIDENCE_PACKAGE}"
    echo ""
    echo "=== Collected Files ==="
    ls -lh "${EVIDENCE_PACKAGE}"
    echo ""
    echo "=== Quick Checks ==="
    if [ -f "${EVIDENCE_PACKAGE}/process-info.txt" ]; then
        echo "Process Status:"
        cat "${EVIDENCE_PACKAGE}/process-info.txt"
    fi
    echo ""
    if [ -f "${EVIDENCE_PACKAGE}/sample.txt" ]; then
        echo "Sample collected: Yes (see sample.txt)"
    else
        echo "Sample collected: No"
    fi
    echo ""
    if [ -f "${EVIDENCE_PACKAGE}/spindump.txt" ]; then
        echo "Spindump collected: Yes (see spindump.txt)"
    else
        echo "Spindump collected: No (requires sudo)"
    fi
} > "${EVIDENCE_PACKAGE}/SUMMARY.txt"

# 打包（可选）
if command -v tar &> /dev/null; then
    log_info "打包证据..."
    tar -czf "${EVIDENCE_PACKAGE}.tar.gz" -C "${EVIDENCE_DIR}" "${TIMESTAMP}"
    log_info "证据包已打包: ${EVIDENCE_PACKAGE}.tar.gz"
fi

# 输出摘要
log_info "证据采集完成！"
echo ""
cat "${EVIDENCE_PACKAGE}/SUMMARY.txt"
echo ""
log_info "证据包位置: ${EVIDENCE_PACKAGE}"
if [ -f "${EVIDENCE_PACKAGE}.tar.gz" ]; then
    log_info "打包文件: ${EVIDENCE_PACKAGE}.tar.gz"
fi
echo ""
log_info "下一步："
echo "  1. 查看 SUMMARY.txt 了解快速概览"
echo "  2. 查看 sample.txt 或 spindump.txt 分析卡顿原因"
echo "  3. 查看 launch-log.txt 检查启动步骤耗时"
echo "  4. 参考 docs/diagnostics/startup-log-interpretation.md 判读日志"
