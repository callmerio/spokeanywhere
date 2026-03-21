#!/bin/bash
# R2-3 Debug-only 自动化回归套件
# 覆盖录音/截图/字幕三条关键链路（触发链 + 完成链）。

set -euo pipefail

RUNS=${RUNS:-10}
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/spoke-r2-3-debug-automation}"
APP_NAME="${APP_NAME:-SpokenAnyWhere}"
APP_DOMAIN="${APP_DOMAIN:-}"
PING_WAIT_SECONDS="${PING_WAIT_SECONDS:-3}"
PING_LOOKBACK_SECONDS="${PING_LOOKBACK_SECONDS:-30}"
SCREENSHOT_WAIT_SECONDS="${SCREENSHOT_WAIT_SECONDS:-12}"
LISTENER_LOOKBACK_MINUTES="${LISTENER_LOOKBACK_MINUTES:-30}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")-$$"
TEST_PACKAGE="${OUTPUT_DIR}/${TIMESTAMP}"
HELPER_SWIFT="${TEST_PACKAGE}/post_debug_action.swift"
HELPER_BIN="${TEST_PACKAGE}/post_debug_action"
APP_BUNDLE_PATH="${APP_BUNDLE_PATH:-${REPO_ROOT}/.build/bundler/SpokenAnyWhere.app}"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
ENV_COUNT=0
TOTAL_DURATION=0
APP_PID=""
RECORDING_PERMISSION_ENV_COUNT=0
SCREENSHOT_PERMISSION_ENV_COUNT=0
SCREENSHOT_CONSUME_ENV_COUNT=0

mkdir -p "${TEST_PACKAGE}"

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARN] $1"; }
log_error() { echo "[ERROR] $1"; }

increment_final_status_counter() {
    local final_status="$1"
    case "${final_status}" in
        PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
        FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
        ENV)  ENV_COUNT=$((ENV_COUNT + 1)) ;;
        WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
        *)    FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    esac
}

classify_recording_status() {
    local start_count="$1"
    local stop_count="$2"
    local permission_denied_count="$3"

    if [[ "${start_count}" -gt 0 && "${stop_count}" -gt 0 ]]; then
        echo "PASS"
    elif [[ "${permission_denied_count}" -gt 0 ]]; then
        echo "ENV"
    else
        echo "FAIL"
    fi
}

classify_caption_status() {
    local show_count="$1"
    local hide_count="$2"

    if [[ "${show_count}" -gt 0 && "${hide_count}" -gt 0 ]]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
}

classify_screenshot_status() {
    local created_count="$1"
    local complete_count="$2"
    local permission_denied_count="$3"
    local trigger_count="$4"

    if [[ "${created_count}" -gt 0 && "${complete_count}" -gt 0 ]]; then
        echo "PASS"
    elif [[ "${permission_denied_count}" -gt 0 ]]; then
        echo "ENV"
    elif [[ "${trigger_count}" -gt 0 ]]; then
        echo "ENV"
    elif [[ "${created_count}" -gt 0 || "${complete_count}" -gt 0 ]]; then
        echo "WARN"
    else
        echo "FAIL"
    fi
}

classify_final_status() {
    local recording_status="$1"
    local caption_status="$2"
    local screenshot_status="$3"

    if [[ "${recording_status}" == "PASS" && "${caption_status}" == "PASS" && "${screenshot_status}" == "PASS" ]]; then
        echo "PASS"
    elif [[ "${recording_status}" == "FAIL" || "${caption_status}" == "FAIL" || "${screenshot_status}" == "FAIL" ]]; then
        echo "FAIL"
    elif [[ "${recording_status}" == "ENV" || "${caption_status}" == "ENV" || "${screenshot_status}" == "ENV" ]]; then
        echo "ENV"
    elif [[ "${recording_status}" == "WARN" || "${caption_status}" == "WARN" || "${screenshot_status}" == "WARN" ]]; then
        echo "WARN"
    else
        echo "FAIL"
    fi
}

classify_failure_details() {
    local final_status="$1"
    local recording_status="$2"
    local caption_status="$3"
    local screenshot_status="$4"
    local screenshot_permission_denied_count="$5"
    local screenshot_trigger_count="$6"

    local failure_class="none"
    local blocking_class="NONE"

    if [[ "${final_status}" == "PASS" ]]; then
        :
    elif [[ "${final_status}" == "WARN" ]]; then
        failure_class="screenshot_signal_partial"
        blocking_class="WARN_NON_BLOCKING"
    elif [[ "${recording_status}" == "ENV" ]]; then
        failure_class="recording_permission_denied"
        blocking_class="ENV_PERMISSION"
        RECORDING_PERMISSION_ENV_COUNT=$((RECORDING_PERMISSION_ENV_COUNT + 1))
    elif [[ "${recording_status}" != "PASS" ]]; then
        failure_class="recording_chain_missing"
        blocking_class="FAIL_FUNCTIONAL"
    elif [[ "${caption_status}" != "PASS" ]]; then
        failure_class="caption_chain_missing"
        blocking_class="FAIL_FUNCTIONAL"
    elif [[ "${screenshot_status}" == "ENV" && "${screenshot_permission_denied_count}" -gt 0 ]]; then
        failure_class="screenshot_permission_denied"
        blocking_class="ENV_PERMISSION"
        SCREENSHOT_PERMISSION_ENV_COUNT=$((SCREENSHOT_PERMISSION_ENV_COUNT + 1))
    elif [[ "${screenshot_status}" == "ENV" && "${screenshot_trigger_count}" -gt 0 ]]; then
        failure_class="screenshot_trigger_without_consume"
        blocking_class="ENV_CONSUME"
        SCREENSHOT_CONSUME_ENV_COUNT=$((SCREENSHOT_CONSUME_ENV_COUNT + 1))
    elif [[ "${screenshot_status}" != "PASS" && "${screenshot_trigger_count}" -eq 0 ]]; then
        failure_class="screenshot_trigger_missing"
        blocking_class="FAIL_FUNCTIONAL"
    else
        failure_class="screenshot_signal_missing"
        blocking_class="FAIL_FUNCTIONAL"
    fi

    printf '%s|%s\n' "${failure_class}" "${blocking_class}"
}

write_run_summary() {
    local run_summary="$1"
    local run_id="$2"
    local duration="$3"
    local start_time="$4"
    local end_time="$5"
    local recording_status="$6"
    local caption_status="$7"
    local screenshot_status="$8"
    local final_status="$9"
    local blocking_class="${10}"
    local failure_class="${11}"
    local recording_start_count="${12}"
    local recording_stop_count="${13}"
    local recording_permission_denied_count="${14}"
    local caption_show_count="${15}"
    local caption_hide_count="${16}"
    local screenshot_created_count="${17}"
    local screenshot_trigger_count="${18}"
    local screenshot_complete_count="${19}"
    local screenshot_permission_denied_count="${20}"

    {
        echo "run_id=${run_id}"
        echo "run_duration_s=${duration}"
        echo "window_start=${start_time}"
        echo "window_end=${end_time}"
        echo "path_recording=${recording_status}"
        echo "path_caption=${caption_status}"
        echo "path_screenshot=${screenshot_status}"
        echo "final_status=${final_status}"
        echo "blocking_class=${blocking_class}"
        echo "failure_class=${failure_class}"
        echo "recording_start_count=${recording_start_count}"
        echo "recording_stop_count=${recording_stop_count}"
        echo "recording_permission_denied_count=${recording_permission_denied_count}"
        echo "caption_show_count=${caption_show_count}"
        echo "caption_hide_count=${caption_hide_count}"
        echo "screenshot_created_count=${screenshot_created_count}"
        echo "screenshot_trigger_count=${screenshot_trigger_count}"
        echo "screenshot_complete_count=${screenshot_complete_count}"
        echo "screenshot_permission_denied_count=${screenshot_permission_denied_count}"
    } > "${run_summary}"
}

resolve_app_domain() {
    if [[ -n "${APP_DOMAIN}" ]]; then
        return
    fi

    local resolved
    resolved="$(/usr/bin/defaults read "${APP_BUNDLE_PATH}/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
    if [[ -n "${resolved}" ]]; then
        APP_DOMAIN="${resolved}"
    else
        APP_DOMAIN="com.spokeanywhere"
    fi
}

get_frontmost_app() {
    /usr/bin/osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null || echo "unknown"
}

permission_probe() {
    local mic="unknown"
    local screen="unknown"
    local ax="unknown"

    if tccutil list Microphone >/tmp/spoke-r2-3-mic.$$ 2>&1; then
        if grep -q "${APP_DOMAIN}" /tmp/spoke-r2-3-mic.$$; then mic="configured"; else mic="not_found"; fi
    fi
    if tccutil list ScreenCapture >/tmp/spoke-r2-3-screen.$$ 2>&1; then
        if grep -q "${APP_DOMAIN}" /tmp/spoke-r2-3-screen.$$; then screen="configured"; else screen="not_found"; fi
    fi
    if tccutil list Accessibility >/tmp/spoke-r2-3-ax.$$ 2>&1; then
        if grep -q "${APP_DOMAIN}" /tmp/spoke-r2-3-ax.$$; then ax="configured"; else ax="not_found"; fi
    fi

    rm -f /tmp/spoke-r2-3-mic.$$ /tmp/spoke-r2-3-screen.$$ /tmp/spoke-r2-3-ax.$$ || true
    echo "mic:${mic},screen:${screen},ax:${ax}"
}

read_hotkey_config() {
    local record_key record_mod caption_key caption_mod screenshot_key screenshot_mod
    record_key="$(defaults read "${APP_DOMAIN}" ShortcutKeyCode 2>/dev/null || echo "NA")"
    record_mod="$(defaults read "${APP_DOMAIN}" ShortcutModifiers 2>/dev/null || echo "NA")"
    caption_key="$(defaults read "${APP_DOMAIN}" LiveCaptionKeyCode 2>/dev/null || echo "NA")"
    caption_mod="$(defaults read "${APP_DOMAIN}" LiveCaptionModifiers 2>/dev/null || echo "NA")"
    screenshot_key="$(defaults read "${APP_DOMAIN}" ScreenshotKeyCode 2>/dev/null || echo "NA")"
    screenshot_mod="$(defaults read "${APP_DOMAIN}" ScreenshotModifiers 2>/dev/null || echo "NA")"

    if [[ "${record_key}" == "NA" || "${caption_key}" == "NA" || "${screenshot_key}" == "NA" ]]; then
        echo "key_source=hardcoded_fallback record=opt+R caption=opt+S screenshot=opt+A"
    else
        echo "key_source=defaults record=${record_key}/${record_mod} caption=${caption_key}/${caption_mod} screenshot=${screenshot_key}/${screenshot_mod}"
    fi
}

build_action_helper() {
    cat > "${HELPER_SWIFT}" <<'SWIFT'
import Foundation

guard CommandLine.arguments.count > 1 else {
    fputs("missing action\n", stderr)
    exit(2)
}

let action = CommandLine.arguments[1]
let name = Notification.Name("com.spokeanywhere.debug.automation.trigger")
DistributedNotificationCenter.default().postNotificationName(
    name,
    object: nil,
    userInfo: ["action": action],
    deliverImmediately: true
)
print("action=\(action)")
SWIFT

    swiftc "${HELPER_SWIFT}" -o "${HELPER_BIN}"
}

send_action() {
    local action="$1"
    "${HELPER_BIN}" "${action}" >/dev/null
}

collect_window_logs() {
    local start_time="$1"
    local end_time="$2"
    local output_file="$3"

    log show \
        --style syslog \
        --info \
        --start "${start_time}" \
        --end "${end_time}" \
        --predicate "subsystem == \"com.spokeanywhere\" AND process == \"${APP_NAME}\" AND processID == ${APP_PID} AND (category == \"Recording\" OR category == \"ScreenshotManager\" OR category == \"LiveCaptionWindow\" OR category == \"DebugAutomation\")" \
        > "${output_file}" 2>&1
}

assert_run() {
    local run_id="$1"
    local start_time="$2"
    local end_time="$3"
    local run_log="$4"
    local duration="$5"
    local run_summary="${TEST_PACKAGE}/run-${run_id}.summary"

    local recording_start_count recording_stop_count recording_permission_denied_count
    local caption_show_count caption_hide_count
    local screenshot_trigger_count screenshot_created_count screenshot_complete_count screenshot_permission_denied_count
    recording_start_count="$(grep -c "Recording started" "${run_log}" || true)"
    recording_stop_count="$(grep -c "Recording stopped" "${run_log}" || true)"
    recording_permission_denied_count="$(grep -c "AudioRecorderError.permissionDenied" "${run_log}" || true)"
    caption_show_count="$(grep -c "Live Caption window shown" "${run_log}" || true)"
    caption_hide_count="$(grep -c "Live Caption window hidden" "${run_log}" || true)"
    screenshot_trigger_count="$(grep -c "action=screenshot.capture" "${run_log}" || true)"
    screenshot_created_count="$(grep -c "Screenshot created" "${run_log}" || true)"
    screenshot_complete_count="$(grep -c "screenshot.capture complete" "${run_log}" || true)"
    screenshot_permission_denied_count="$(grep -c "Screen capture permission not granted" "${run_log}" || true)"

    local recording_status caption_status screenshot_status final_status failure_class blocking_class details
    recording_status="$(classify_recording_status "${recording_start_count}" "${recording_stop_count}" "${recording_permission_denied_count}")"
    caption_status="$(classify_caption_status "${caption_show_count}" "${caption_hide_count}")"
    screenshot_status="$(classify_screenshot_status "${screenshot_created_count}" "${screenshot_complete_count}" "${screenshot_permission_denied_count}" "${screenshot_trigger_count}")"
    final_status="$(classify_final_status "${recording_status}" "${caption_status}" "${screenshot_status}")"
    increment_final_status_counter "${final_status}"

    details="$(classify_failure_details "${final_status}" "${recording_status}" "${caption_status}" "${screenshot_status}" "${screenshot_permission_denied_count}" "${screenshot_trigger_count}")"
    failure_class="${details%%|*}"
    blocking_class="${details#*|}"

    write_run_summary \
        "${run_summary}" \
        "${run_id}" \
        "${duration}" \
        "${start_time}" \
        "${end_time}" \
        "${recording_status}" \
        "${caption_status}" \
        "${screenshot_status}" \
        "${final_status}" \
        "${blocking_class}" \
        "${failure_class}" \
        "${recording_start_count}" \
        "${recording_stop_count}" \
        "${recording_permission_denied_count}" \
        "${caption_show_count}" \
        "${caption_hide_count}" \
        "${screenshot_created_count}" \
        "${screenshot_trigger_count}" \
        "${screenshot_complete_count}" \
        "${screenshot_permission_denied_count}"

    echo "${run_id},${final_status},${recording_status},${caption_status},${screenshot_status},${duration},${blocking_class},${failure_class}" >> "${TEST_PACKAGE}/runs.csv"
}

run_once() {
    local run_id="$1"
    local run_start_epoch run_end_epoch duration
    local window_start window_end
    local run_log="${TEST_PACKAGE}/run-${run_id}.log"

    run_start_epoch="$(date +%s)"
    window_start="$(date +"%Y-%m-%d %H:%M:%S")"

    send_action "recording.toggle"
    sleep 1.2
    send_action "recording.toggle"

    sleep 0.6
    send_action "caption.toggle"
    sleep 0.6
    send_action "caption.toggle"

    sleep 0.6
    send_action "screenshot.capture"
    sleep "${SCREENSHOT_WAIT_SECONDS}"

    window_end="$(date +"%Y-%m-%d %H:%M:%S")"
    run_end_epoch="$(date +%s)"
    duration=$((run_end_epoch - run_start_epoch))
    TOTAL_DURATION=$((TOTAL_DURATION + duration))

    collect_window_logs "${window_start}" "${window_end}" "${run_log}"
    assert_run "${run_id}" "${window_start}" "${window_end}" "${run_log}" "${duration}"
}

main() {
    log_info "测试包目录: ${TEST_PACKAGE}"

    if ! pgrep -x "${APP_NAME}" >/dev/null; then
        log_error "${APP_NAME} 未运行"
        exit 1
    fi

    resolve_app_domain
    APP_PID="$(pgrep -x "${APP_NAME}" | head -1)"
    if [[ -z "${APP_PID}" ]]; then
        log_error "未找到 ${APP_NAME} 进程 PID"
        exit 1
    fi

    local git_head frontmost_app permission_state
    git_head="$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
    frontmost_app="$(get_frontmost_app)"
    permission_state="$(permission_probe)"

    build_action_helper

    echo "run_id,final_status,path_recording,path_caption,path_screenshot,run_duration_s,blocking_class,failure_class" > "${TEST_PACKAGE}/runs.csv"

    local ping_start ping_end ping_log ping_window_start pong_pid
    local listener_start listener_end listener_log listener_status

    listener_start="$(date -v-"${LISTENER_LOOKBACK_MINUTES}"M +"%Y-%m-%d %H:%M:%S")"
    listener_end="$(date +"%Y-%m-%d %H:%M:%S")"
    listener_log="${TEST_PACKAGE}/preflight-listener.log"
    collect_window_logs "${listener_start}" "${listener_end}" "${listener_log}"
    if grep -q "listener started" "${listener_log}"; then
        listener_status="PASS"
    else
        listener_status="MISS"
    fi

    ping_start="$(date +"%Y-%m-%d %H:%M:%S")"
    send_action "ping"
    sleep "${PING_WAIT_SECONDS}"
    ping_end="$(date +"%Y-%m-%d %H:%M:%S")"
    ping_log="${TEST_PACKAGE}/preflight-ping.log"
    ping_window_start="$(date -v-"${PING_LOOKBACK_SECONDS}"S +"%Y-%m-%d %H:%M:%S")"
    collect_window_logs "${ping_window_start}" "${ping_end}" "${ping_log}"

    local ping_status
    pong_pid="$(sed -n 's/.*pong pid=\([0-9][0-9]*\).*/\1/p' "${ping_log}" | tail -1)"
    if [[ -n "${pong_pid}" && "${pong_pid}" == "${APP_PID}" ]]; then
        ping_status="PASS"
    else
        ping_status="ENV"
        ENV_COUNT=$((ENV_COUNT + 1))
    fi

    if [[ "${listener_status}" != "PASS" ]]; then
        log_warn "listener-ready 未在日志窗口命中（pid=${APP_PID}），以 ping 断言为准"
    fi

    {
        echo "window_start=${ping_start}"
        echo "window_end=${ping_end}"
        echo "pid=${APP_PID}"
        echo "git_head=${git_head}"
        echo "frontmost_app=${frontmost_app}"
        echo "app_domain=${APP_DOMAIN}"
        echo "permission_state=${permission_state}"
        echo "listener_status=${listener_status}"
        echo "ping_status=${ping_status}"
        echo "pong_pid=${pong_pid:-NA}"
        read_hotkey_config
    } > "${TEST_PACKAGE}/preflight.txt"

    if [[ "${ping_status}" != "PASS" ]]; then
        log_warn "preflight ping 失败，判定 ENV，停止正式轮次"
        {
            echo "final_status=ENV"
            echo "blocking_class=ENV_HANDSHAKE"
            echo "pass=${PASS_COUNT}"
            echo "warn=${WARN_COUNT}"
            echo "fail=${FAIL_COUNT}"
            echo "skip=${SKIP_COUNT}"
            echo "env=${ENV_COUNT}"
            echo "runs_executed=0"
        } > "${TEST_PACKAGE}/SUMMARY.txt"
        cat "${TEST_PACKAGE}/SUMMARY.txt"
        exit 3
    fi

    local run_id
    for run_id in $(seq 1 "${RUNS}"); do
        log_info "执行 run ${run_id}/${RUNS}"
        run_once "${run_id}"
    done

    local avg_duration success_rate final_status blocking_class
    avg_duration="$(awk "BEGIN { if (${RUNS} > 0) printf \"%.2f\", ${TOTAL_DURATION}/${RUNS}; else print \"0.00\" }")"
    success_rate="$(awk "BEGIN { if (${RUNS} > 0) printf \"%.2f\", ((${PASS_COUNT}+${WARN_COUNT})/${RUNS})*100; else print \"0.00\" }")"

    final_status="PASS"
    if [[ "${FAIL_COUNT}" -gt 0 ]]; then
        final_status="FAIL"
    elif [[ "${ENV_COUNT}" -gt 0 ]]; then
        final_status="ENV"
    elif [[ "${WARN_COUNT}" -gt 0 ]]; then
        final_status="WARN"
    fi

    blocking_class="NONE"
    if [[ "${final_status}" == "FAIL" ]]; then
        blocking_class="FAIL_FUNCTIONAL"
    elif [[ "${final_status}" == "ENV" ]]; then
        if [[ "${RECORDING_PERMISSION_ENV_COUNT}" -gt 0 || "${SCREENSHOT_PERMISSION_ENV_COUNT}" -gt 0 ]]; then
            blocking_class="ENV_PERMISSION"
        elif [[ "${SCREENSHOT_CONSUME_ENV_COUNT}" -gt 0 ]]; then
            blocking_class="ENV_CONSUME"
        else
            blocking_class="ENV_OTHER"
        fi
    elif [[ "${final_status}" == "WARN" ]]; then
        blocking_class="WARN_NON_BLOCKING"
    fi

    {
        echo "window_start=$(date +"%Y-%m-%d %H:%M:%S")"
        echo "window_end=$(date +"%Y-%m-%d %H:%M:%S")"
        echo "pid=${APP_PID}"
        echo "git_head=${git_head}"
        echo "frontmost_app=${frontmost_app}"
        echo "app_domain=${APP_DOMAIN}"
        echo "permission_state=${permission_state}"
        echo "pass=${PASS_COUNT}"
        echo "warn=${WARN_COUNT}"
        echo "fail=${FAIL_COUNT}"
        echo "skip=${SKIP_COUNT}"
        echo "env=${ENV_COUNT}"
        echo "runs_executed=${RUNS}"
        echo "success_rate=${success_rate}"
        echo "avg_duration_s=${avg_duration}"
        echo "final_status=${final_status}"
        echo "blocking_class=${blocking_class}"
    } > "${TEST_PACKAGE}/SUMMARY.txt"

    cat "${TEST_PACKAGE}/SUMMARY.txt"

    case "${final_status}" in
        PASS|WARN)
            exit 0
            ;;
        FAIL)
            exit 1
            ;;
        SKIP)
            exit 2
            ;;
        ENV)
            exit 3
            ;;
        *)
            exit 4
            ;;
    esac
}

main "$@"
