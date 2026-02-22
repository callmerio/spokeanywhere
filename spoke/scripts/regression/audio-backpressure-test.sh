#!/bin/bash
# 音频链路背压回归测试
# 验证音频缓冲区管理、丢帧率、延迟指标

set -euo pipefail

# 配置
TEST_DURATION=${TEST_DURATION:-30}  # 测试时长（秒）
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/spoke-audio-backpressure}"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
TEST_PACKAGE="${OUTPUT_DIR}/${TIMESTAMP}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 创建测试目录
mkdir -p "${TEST_PACKAGE}"
log_info "测试包目录: ${TEST_PACKAGE}"

# 1. 检查应用是否运行
log_info "检查应用状态..."
if ! pgrep -x "SpokenAnyWhere" > /dev/null; then
    log_error "SpokenAnyWhere 未运行，请先启动应用"
    exit 1
fi

APP_PID=$(pgrep -x "SpokenAnyWhere")
log_info "应用 PID: ${APP_PID}"

# 2. 收集基线指标
log_info "收集基线指标..."
{
    echo "=== Audio Backpressure Baseline ==="
    echo "Test Time: $(date)"
    echo "Test Duration: ${TEST_DURATION}s"
    echo "App PID: ${APP_PID}"
    echo ""
    echo "=== Process Info ==="
    ps -p "${APP_PID}" -o pid,ppid,user,%cpu,%mem,vsz,rss,tt,stat,start,time,command
    echo ""
} > "${TEST_PACKAGE}/baseline.txt"

# 3. 启动日志采集
log_info "启动日志采集（${TEST_DURATION}秒）..."
log show --predicate 'subsystem == "com.spokeanywhere" AND (category == "Audio" OR category == "Launch")' \
    --style syslog \
    --last "${TEST_DURATION}s" \
    > "${TEST_PACKAGE}/audio-log.txt" 2>&1 &
LOG_PID=$!

# 4. 启动性能采样
log_info "启动性能采样..."
sample "${APP_PID}" "${TEST_DURATION}" -file "${TEST_PACKAGE}/sample.txt" 2>&1 &
SAMPLE_PID=$!

# 5. 监控资源使用
log_info "监控资源使用..."
{
    for i in $(seq 1 "${TEST_DURATION}"); do
        echo "=== Sample $i ($(date +%H:%M:%S)) ==="
        ps -p "${APP_PID}" -o %cpu,%mem,vsz,rss
        sleep 1
    done
} > "${TEST_PACKAGE}/resource-usage.txt" 2>&1 &
RESOURCE_PID=$!

# 6. 等待测试完成
log_info "等待测试完成（${TEST_DURATION}秒）..."
wait "${LOG_PID}" 2>/dev/null || true
wait "${SAMPLE_PID}" 2>/dev/null || true
wait "${RESOURCE_PID}" 2>/dev/null || true

# 7. 分析日志
log_info "分析音频链路指标..."
{
    echo "=== Audio Backpressure Analysis ==="
    echo ""

    # 缓冲区状态
    echo "=== Buffer Status ==="
    grep -i "buffered chunks" "${TEST_PACKAGE}/audio-log.txt" || echo "No buffer status found"
    echo ""

    # 引擎准备时间
    echo "=== Engine Preparation ==="
    grep -i "engine ready\|preparing transcription" "${TEST_PACKAGE}/audio-log.txt" || echo "No engine preparation logs"
    echo ""

    # 错误与警告
    echo "=== Errors & Warnings ==="
    grep -E "❌|⚠️|Failed|Error" "${TEST_PACKAGE}/audio-log.txt" || echo "No errors found"
    echo ""

    # 崩溃恢复写入
    echo "=== Crash Recovery Writes ==="
    grep -i "crash recovery\|write" "${TEST_PACKAGE}/audio-log.txt" | head -20 || echo "No crash recovery logs"
    echo ""

} > "${TEST_PACKAGE}/analysis.txt"

# 8. 提取背压指标
log_info "提取背压指标..."
{
    echo "=== Backpressure Metrics Extraction ==="
    echo ""

    # 提取引擎准备日志行（|| true 避免 grep 无匹配时触发 errexit）
    ENGINE_READY_LINE=$(grep "Engine ready, sending.*buffered chunks" "${TEST_PACKAGE}/audio-log.txt" 2>/dev/null | tail -1 || true)

    if [ -n "${ENGINE_READY_LINE}" ]; then
        # 提取指标：prepare: Xms, peak: X, drops: X, recovery_drops: X
        PREPARE_MS=$(echo "${ENGINE_READY_LINE}" | grep -oE 'prepare: [0-9]+' | grep -oE '[0-9]+' || echo "0")
        PEAK=$(echo "${ENGINE_READY_LINE}" | grep -oE 'peak: [0-9]+' | grep -oE '[0-9]+' || echo "0")
        DROPS=$(echo "${ENGINE_READY_LINE}" | grep -oE 'drops: [0-9]+' | grep -oE '[0-9]+' || echo "0")
        RECOVERY_DROPS=$(echo "${ENGINE_READY_LINE}" | grep -oE 'recovery_drops: [0-9]+' | grep -oE '[0-9]+' || echo "0")

        echo "Raw metrics extracted:"
        echo "  prepare_ms: ${PREPARE_MS}"
        echo "  peak: ${PEAK}"
        echo "  drops: ${DROPS}"
        echo "  recovery_drops: ${RECOVERY_DROPS}"
    else
        echo "⚠️  No engine ready log found (no recording activity)"
        PREPARE_MS=0
        PEAK=0
        DROPS=0
        RECOVERY_DROPS=0
    fi

    echo ""
} >> "${TEST_PACKAGE}/analysis.txt"

# 9. 计算固定输出指标
log_info "计算固定输出指标..."
{
    echo "=== Fixed Output Metrics ==="
    echo ""

    # backlog_depth: 引擎准备前缓冲区峰值
    BACKLOG_DEPTH=${PEAK}

    # drop_rate: 丢帧率 = drops / (peak + drops) * 100
    if [ $((PEAK + DROPS)) -gt 0 ]; then
        DROP_RATE=$(awk "BEGIN {printf \"%.2f\", (${DROPS} / (${PEAK} + ${DROPS})) * 100}")
    else
        DROP_RATE="0.00"
    fi

    # p95_latency_ms: 引擎准备延迟（当前为单次测量，P95 需多次采样）
    P95_LATENCY_MS=${PREPARE_MS}

    echo "backlog_depth: ${BACKLOG_DEPTH}"
    echo "drop_rate: ${DROP_RATE}%"
    echo "p95_latency_ms: ${P95_LATENCY_MS}"
    echo "recovery_write_drops: ${RECOVERY_DROPS}"

    echo ""
} >> "${TEST_PACKAGE}/analysis.txt"

# 10. 计算资源指标
log_info "计算资源指标..."
{
    echo "=== Resource Metrics ==="
    echo ""

    # CPU 使用率（平均值）
    echo "CPU Usage:"
    awk '/Sample/ {getline; sum+=$1; count++} END {if(count>0) print "  Average: " sum/count "%"}' \
        "${TEST_PACKAGE}/resource-usage.txt"

    # 内存使用（平均值）
    echo "Memory Usage:"
    awk '/Sample/ {getline; sum+=$2; count++} END {if(count>0) print "  Average: " sum/count "%"}' \
        "${TEST_PACKAGE}/resource-usage.txt"

    # 错误次数
    echo "Errors:"
    ERROR_COUNT=$(grep -cE "❌|Failed|Error" "${TEST_PACKAGE}/audio-log.txt" 2>/dev/null || echo "0")
    echo "  Count: ${ERROR_COUNT}"

    echo ""
} >> "${TEST_PACKAGE}/analysis.txt"

# 11. 生成摘要
log_info "生成测试摘要..."
{
    echo "=== Audio Backpressure Test Summary ==="
    echo "Test Package: ${TEST_PACKAGE}"
    echo "Test Duration: ${TEST_DURATION}s"
    echo "Timestamp: ${TIMESTAMP}"
    echo ""

    echo "=== Fixed Output Metrics ==="
    echo "backlog_depth=${BACKLOG_DEPTH}"
    echo "drop_rate=${DROP_RATE}"
    echo "p95_latency_ms=${P95_LATENCY_MS}"
    echo "recovery_write_drops=${RECOVERY_DROPS}"
    echo ""

    # 基线与阈值
    echo "=== Baseline & Thresholds ==="
    echo "Baseline (normal):"
    echo "  backlog_depth: 10-50"
    echo "  drop_rate: 0%"
    echo "  p95_latency_ms: 1000-2000"
    echo ""
    echo "Thresholds:"
    echo "  P0 (critical): backlog_depth>=128 OR drop_rate>0 OR p95_latency_ms>10000"
    echo "  P1 (warning): backlog_depth>100 OR p95_latency_ms>5000"
    echo "  P2 (attention): backlog_depth>50 OR p95_latency_ms>3000"
    echo ""

    # 状态判定
    echo "=== Status Determination ==="
    STATUS="PASS"

    # 检查是否有录音活动
    if [ "${BACKLOG_DEPTH}" -eq 0 ] && [ "${P95_LATENCY_MS}" -eq 0 ]; then
        echo "⚠️  No recording activity detected"
        STATUS="SKIP"
    # P0 告警
    elif [ "${BACKLOG_DEPTH}" -ge 128 ] || \
         [ "$(echo "${DROP_RATE} > 0" | bc -l 2>/dev/null || echo 0)" -eq 1 ] || \
         [ "${P95_LATENCY_MS}" -gt 10000 ]; then
        echo "❌ FAIL (P0): Critical backpressure detected"
        STATUS="FAIL"
    # P1 告警
    elif [ "${BACKLOG_DEPTH}" -gt 100 ] || [ "${P95_LATENCY_MS}" -gt 5000 ]; then
        echo "⚠️  WARN (P1): Elevated backpressure"
        STATUS="WARN"
    # P2 告警
    elif [ "${BACKLOG_DEPTH}" -gt 50 ] || [ "${P95_LATENCY_MS}" -gt 3000 ]; then
        echo "⚠️  WARN (P2): Moderate backpressure"
        STATUS="WARN"
    else
        echo "✅ PASS: Backpressure within normal range"
    fi

    echo ""
    echo "Final Status: ${STATUS}"
    echo ""

    echo "=== Files Generated ==="
    ls -lh "${TEST_PACKAGE}"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Review analysis: cat ${TEST_PACKAGE}/analysis.txt"
    echo "2. Check audio logs: cat ${TEST_PACKAGE}/audio-log.txt"
    echo "3. Review sample: open ${TEST_PACKAGE}/sample.txt"

} > "${TEST_PACKAGE}/SUMMARY.txt"

# 输出摘要
cat "${TEST_PACKAGE}/SUMMARY.txt"

log_info "测试完成！测试包: ${TEST_PACKAGE}"

# 根据状态返回退出码
case "${STATUS}" in
    PASS)
        exit 0
        ;;
    WARN)
        exit 0  # Warning 不阻塞，但可通过检查输出识别
        ;;
    FAIL)
        log_error "测试失败：检测到 P0 级别背压问题"
        exit 1
        ;;
    SKIP)
        log_warn "测试跳过：未检测到录音活动"
        exit 2
        ;;
    *)
        log_error "未知状态: ${STATUS}"
        exit 3
        ;;
esac
