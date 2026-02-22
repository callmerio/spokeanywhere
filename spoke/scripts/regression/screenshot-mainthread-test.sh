#!/bin/bash
# 截图/图像增强链路主线程占用回归测试
# 验证主线程占用、saveAll 写入、blur 派发延迟

set -euo pipefail

# 配置
TEST_DURATION=${TEST_DURATION:-30}  # 测试时长（秒）
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/spoke-screenshot-mainthread}"
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
    echo "=== Screenshot Main Thread Baseline ==="
    echo "Test Time: $(date)"
    echo "Test Duration: ${TEST_DURATION}s"
    echo "App PID: ${APP_PID}"
    echo ""
    echo "=== Process Info ==="
    ps -p "${APP_PID}" -o pid,ppid,user,%cpu,%mem,vsz,rss,tt,stat,start,time,command
    echo ""
} > "${TEST_PACKAGE}/baseline.txt"

# 3. 记录测试开始时间（用于日志过滤）
log_info "记录测试开始时间..."
TEST_START_TIME=$(date +"%Y-%m-%d %H:%M:%S")
log_info "测试开始时间: ${TEST_START_TIME}"

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
log_info "提示：请在测试期间执行截图操作（触发 pin/unpin/mark 等动作以覆盖 saveAll 路径）"
wait "${SAMPLE_PID}" 2>/dev/null || true
wait "${RESOURCE_PID}" 2>/dev/null || true

# 7. 采集测试窗口内的日志
log_info "采集测试窗口日志..."
log show --predicate 'subsystem == "com.spokeanywhere" AND category == "ScreenshotManager"' \
    --style syslog \
    --info \
    --start "${TEST_START_TIME}" \
    > "${TEST_PACKAGE}/screenshot-log.txt" 2>&1

# 8. 分析日志
log_info "分析截图链路指标..."
{
    echo "=== Screenshot Main Thread Analysis ==="
    echo ""

    # 截图创建日志
    echo "=== Screenshot Created Events ==="
    grep -i "Screenshot created" "${TEST_PACKAGE}/screenshot-log.txt" || echo "No screenshot events found"
    echo ""

    # 错误与警告
    echo "=== Errors & Warnings ==="
    grep -E "❌|⚠️|Failed|Error" "${TEST_PACKAGE}/screenshot-log.txt" || echo "No errors found"
    echo ""

} > "${TEST_PACKAGE}/analysis.txt"

# 8. 提取主线程占用指标
log_info "提取主线程占用指标..."
{
    echo "=== Main Thread Metrics Extraction ==="
    echo ""

    # 提取最后一次截图创建日志（包含所有指标）
    SCREENSHOT_LINE=$(grep "Screenshot created" "${TEST_PACKAGE}/screenshot-log.txt" 2>/dev/null | tail -1 || true)

    if [ -n "${SCREENSHOT_LINE}" ]; then
        # 提取指标：capture_latency, enhancement_path, save_all_write_p95, blur_main_dispatch_p95, coverage_saveall, coverage_blur
        CAPTURE_LATENCY=$(echo "${SCREENSHOT_LINE}" | grep -oE 'capture_latency: [0-9]+' | grep -oE '[0-9]+' || echo "0")
        ENHANCEMENT_PATH=$(echo "${SCREENSHOT_LINE}" | grep -oE 'enhancement_path: [a-z-]+' | sed 's/enhancement_path: //' || echo "none")
        SAVE_ALL_WRITE_P95=$(echo "${SCREENSHOT_LINE}" | grep -oE 'save_all_write_p95: [0-9.]+' | grep -oE '[0-9.]+' || echo "0")
        BLUR_DISPATCH_P95=$(echo "${SCREENSHOT_LINE}" | grep -oE 'blur_main_dispatch_p95: [0-9.]+' | grep -oE '[0-9.]+' || echo "0")
        COVERAGE_SAVEALL=$(echo "${SCREENSHOT_LINE}" | grep -oE 'coverage_saveall: [01]' | grep -oE '[01]' || echo "0")
        COVERAGE_BLUR=$(echo "${SCREENSHOT_LINE}" | grep -oE 'coverage_blur: [01]' | grep -oE '[01]' || echo "0")

        echo "Raw metrics extracted:"
        echo "  capture_latency_ms: ${CAPTURE_LATENCY}"
        echo "  enhancement_path: ${ENHANCEMENT_PATH}"
        echo "  save_all_write_p95: ${SAVE_ALL_WRITE_P95}"
        echo "  blur_main_dispatch_p95: ${BLUR_DISPATCH_P95}"
        echo "  coverage_saveall: ${COVERAGE_SAVEALL}"
        echo "  coverage_blur: ${COVERAGE_BLUR}"
    else
        echo "⚠️  No screenshot created log found (no screenshot activity)"
        CAPTURE_LATENCY=0
        ENHANCEMENT_PATH="none"
        SAVE_ALL_WRITE_P95=0
        BLUR_DISPATCH_P95=0
        COVERAGE_SAVEALL=0
        COVERAGE_BLUR=0
    fi

    echo ""
} >> "${TEST_PACKAGE}/analysis.txt"

# 9. 计算固定输出指标
log_info "计算固定输出指标..."
{
    echo "=== Fixed Output Metrics ==="
    echo ""

    echo "capture_latency_ms: ${CAPTURE_LATENCY}"
    echo "enhancement_path: ${ENHANCEMENT_PATH}"
    echo "save_all_write_p95_ms: ${SAVE_ALL_WRITE_P95}"
    echo "blur_main_dispatch_p95_ms: ${BLUR_DISPATCH_P95}"
    echo "coverage_saveall: ${COVERAGE_SAVEALL}"
    echo "coverage_blur: ${COVERAGE_BLUR}"

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
    ERROR_COUNT=$(grep -cE "❌|Failed|Error" "${TEST_PACKAGE}/screenshot-log.txt" 2>/dev/null || echo "0")
    echo "  Count: ${ERROR_COUNT}"

    echo ""
} >> "${TEST_PACKAGE}/analysis.txt"

# 11. 生成摘要
log_info "生成测试摘要..."
{
    echo "=== Screenshot Main Thread Test Summary ==="
    echo "Test Package: ${TEST_PACKAGE}"
    echo "Test Duration: ${TEST_DURATION}s"
    echo "Timestamp: ${TIMESTAMP}"
    echo ""

    echo "=== Fixed Output Metrics ==="
    echo "capture_latency_ms=${CAPTURE_LATENCY}"
    echo "enhancement_path=${ENHANCEMENT_PATH}"
    echo "save_all_write_p95_ms=${SAVE_ALL_WRITE_P95}"
    echo "blur_main_dispatch_p95_ms=${BLUR_DISPATCH_P95}"
    echo "coverage_saveall=${COVERAGE_SAVEALL}"
    echo "coverage_blur=${COVERAGE_BLUR}"
    echo ""

    # 基线与阈值
    echo "=== Baseline & Thresholds ==="
    echo "Baseline (normal):"
    echo "  capture_latency_ms: 50-150"
    echo "  save_all_write_p95_ms: 1-10"
    echo "  blur_main_dispatch_p95_ms: 1-5"
    echo ""
    echo "Thresholds:"
    echo "  P0 (critical): capture_latency_ms>500 OR save_all_write_p95_ms>50 OR blur_main_dispatch_p95_ms>20"
    echo "  P1 (warning): capture_latency_ms>300 OR save_all_write_p95_ms>30 OR blur_main_dispatch_p95_ms>10"
    echo "  P2 (attention): capture_latency_ms>200 OR save_all_write_p95_ms>20 OR blur_main_dispatch_p95_ms>8"
    echo ""

    # 状态判定
    echo "=== Status Determination ==="
    STATUS="PASS"

    # 检查是否有截图活动
    if [ "${CAPTURE_LATENCY}" -eq 0 ]; then
        echo "⚠️  No screenshot activity detected"
        STATUS="SKIP"
    # 覆盖门禁：coverage=0 → WARN
    elif [ "${COVERAGE_SAVEALL}" -eq 0 ] || [ "${COVERAGE_BLUR}" -eq 0 ]; then
        echo "⚠️  WARN: Incomplete coverage (saveall=${COVERAGE_SAVEALL}, blur=${COVERAGE_BLUR})"
        STATUS="WARN"
    # P0 告警
    elif [ "${CAPTURE_LATENCY}" -gt 500 ] || \
         [ "$(echo "${SAVE_ALL_WRITE_P95} > 50" | bc -l 2>/dev/null || echo 0)" -eq 1 ] || \
         [ "$(echo "${BLUR_DISPATCH_P95} > 20" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
        echo "❌ FAIL (P0): Critical main thread blocking detected"
        STATUS="FAIL"
    # P1 告警
    elif [ "${CAPTURE_LATENCY}" -gt 300 ] || \
         [ "$(echo "${SAVE_ALL_WRITE_P95} > 30" | bc -l 2>/dev/null || echo 0)" -eq 1 ] || \
         [ "$(echo "${BLUR_DISPATCH_P95} > 10" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
        echo "⚠️  WARN (P1): Elevated main thread blocking"
        STATUS="WARN"
    # P2 告警
    elif [ "${CAPTURE_LATENCY}" -gt 200 ] || \
         [ "$(echo "${SAVE_ALL_WRITE_P95} > 20" | bc -l 2>/dev/null || echo 0)" -eq 1 ] || \
         [ "$(echo "${BLUR_DISPATCH_P95} > 8" | bc -l 2>/dev/null || echo 0)" -eq 1 ]; then
        echo "⚠️  WARN (P2): Moderate main thread blocking"
        STATUS="WARN"
    else
        echo "✅ PASS: Main thread occupancy within normal range"
    fi

    echo ""
    echo "Final Status: ${STATUS}"
    echo ""

    echo "=== Files Generated ==="
    ls -lh "${TEST_PACKAGE}"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Review analysis: cat ${TEST_PACKAGE}/analysis.txt"
    echo "2. Check screenshot logs: cat ${TEST_PACKAGE}/screenshot-log.txt"
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
        log_error "测试失败：检测到 P0 级别主线程阻塞"
        exit 1
        ;;
    SKIP)
        log_warn "测试跳过：未检测到截图活动"
        exit 2
        ;;
    *)
        log_error "未知状态: ${STATUS}"
        exit 3
        ;;
esac
