#!/bin/bash
# T003 gate wrapper:
# - reuses r2-3 debug automation suite
# - enforces success-rate / duration thresholds
# - requires all three paths to have PASS evidence

set -euo pipefail

RUNS="${RUNS:-10}"
SUCCESS_RATE_THRESHOLD="${SUCCESS_RATE_THRESHOLD:-90}"
MAX_AVG_DURATION_S="${MAX_AVG_DURATION_S:-300}"

APP_NAME="${APP_NAME:-SpokenAnyWhere}"
APP_BUNDLE_PATH="${APP_BUNDLE_PATH:-}"
AUTO_START_APP="${AUTO_START_APP:-0}"

RAW_OUTPUT_DIR="${RAW_OUTPUT_DIR:-/tmp/spoke-r2-3-debug-automation}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/spoke-t003-e2e-gate}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SUITE_SCRIPT="${SCRIPT_DIR}/r2-3-debug-automation-suite.sh"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
REPORT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"

mkdir -p "${REPORT_DIR}"

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

record_kv() {
    local key="$1"
    local value="$2"
    echo "${key}=${value}" >> "${REPORT_DIR}/SUMMARY.txt"
}

parse_kv() {
    local file="$1"
    local key="$2"
    sed -n "s/^${key}=//p" "${file}" | tail -n 1
}

maybe_start_app() {
    if pgrep -x "${APP_NAME}" >/dev/null; then
        return 0
    fi

    if [[ "${AUTO_START_APP}" != "1" ]]; then
        return 1
    fi

    local app_path="${APP_BUNDLE_PATH}"
    if [[ -z "${app_path}" ]]; then
        app_path="${REPO_ROOT}/.build/bundler/SpokenAnyWhere.app"
    fi

    if [[ ! -d "${app_path}" ]]; then
        log_error "app bundle not found: ${app_path}"
        return 1
    fi

    log_info "auto-start app: ${app_path}"
    open -a "${app_path}"

    local i
    for i in $(seq 1 30); do
        if pgrep -x "${APP_NAME}" >/dev/null; then
            return 0
        fi
        sleep 1
    done

    return 1
}

evaluate_path_coverage() {
    local package_dir="$1"
    local path_key="$2"
    local count=0
    local file

    shopt -s nullglob
    for file in "${package_dir}"/run-*.summary; do
        if grep -q "^${path_key}=PASS$" "${file}"; then
            count=$((count + 1))
        fi
    done
    shopt -u nullglob

    echo "${count}"
}

main() {
    : > "${REPORT_DIR}/SUMMARY.txt"

    if ! maybe_start_app; then
        log_error "${APP_NAME} not running (set AUTO_START_APP=1 to auto launch)"
        record_kv "final_status" "ENV"
        record_kv "reason" "app_not_running"
        record_kv "runs_required" "${RUNS}"
        cat "${REPORT_DIR}/SUMMARY.txt"
        exit 3
    fi

    local suite_log="${REPORT_DIR}/suite.log"
    local suite_ec
    set +e
    RUNS="${RUNS}" OUTPUT_DIR="${RAW_OUTPUT_DIR}" APP_NAME="${APP_NAME}" "${SUITE_SCRIPT}" > "${suite_log}" 2>&1
    suite_ec=$?
    set -e

    local package_dir
    package_dir="$(sed -n 's/.*测试包目录: //p' "${suite_log}" | tail -n 1)"
    if [[ -z "${package_dir}" || ! -d "${package_dir}" ]]; then
        package_dir="$(ls -dt "${RAW_OUTPUT_DIR}"/* 2>/dev/null | head -n 1 || true)"
    fi

    if [[ -z "${package_dir}" || ! -d "${package_dir}" ]]; then
        log_error "suite output package not found"
        record_kv "final_status" "FAIL"
        record_kv "reason" "missing_suite_package"
        record_kv "suite_exit_code" "${suite_ec}"
        cat "${REPORT_DIR}/SUMMARY.txt"
        exit 1
    fi

    local suite_summary="${package_dir}/SUMMARY.txt"
    local preflight_file="${package_dir}/preflight.txt"
    if [[ ! -f "${suite_summary}" ]]; then
        log_error "suite summary missing: ${suite_summary}"
        record_kv "final_status" "FAIL"
        record_kv "reason" "missing_suite_summary"
        record_kv "suite_exit_code" "${suite_ec}"
        record_kv "suite_package" "${package_dir}"
        cat "${REPORT_DIR}/SUMMARY.txt"
        exit 1
    fi

    local success_rate avg_duration final_status runs_executed pass_count warn_count fail_count env_count suite_blocking_class
    success_rate="$(parse_kv "${suite_summary}" "success_rate")"
    avg_duration="$(parse_kv "${suite_summary}" "avg_duration_s")"
    final_status="$(parse_kv "${suite_summary}" "final_status")"
    suite_blocking_class="$(parse_kv "${suite_summary}" "blocking_class")"
    runs_executed="$(parse_kv "${suite_summary}" "runs_executed")"
    pass_count="$(parse_kv "${suite_summary}" "pass")"
    warn_count="$(parse_kv "${suite_summary}" "warn")"
    fail_count="$(parse_kv "${suite_summary}" "fail")"
    env_count="$(parse_kv "${suite_summary}" "env")"

    local recording_pass_runs caption_pass_runs screenshot_pass_runs
    recording_pass_runs="$(evaluate_path_coverage "${package_dir}" "path_recording")"
    caption_pass_runs="$(evaluate_path_coverage "${package_dir}" "path_caption")"
    screenshot_pass_runs="$(evaluate_path_coverage "${package_dir}" "path_screenshot")"

    local success_gate duration_gate coverage_gate
    if awk "BEGIN {exit !(${success_rate:-0} >= ${SUCCESS_RATE_THRESHOLD})}"; then
        success_gate="PASS"
    else
        success_gate="FAIL"
    fi

    if awk "BEGIN {exit !(${avg_duration:-999999} <= ${MAX_AVG_DURATION_S})}"; then
        duration_gate="PASS"
    else
        duration_gate="FAIL"
    fi

    if [[ "${recording_pass_runs}" -gt 0 && "${caption_pass_runs}" -gt 0 && "${screenshot_pass_runs}" -gt 0 ]]; then
        coverage_gate="PASS"
    else
        coverage_gate="FAIL"
    fi

    local gate_status="PASS"
    local blocking_class="NONE"
    if [[ "${suite_ec}" -eq 3 || "${final_status}" == "ENV" ]]; then
        gate_status="ENV"
        if [[ -n "${suite_blocking_class}" ]]; then
            blocking_class="${suite_blocking_class}"
        else
            blocking_class="ENV_OTHER"
        fi
    elif [[ "${suite_ec}" -ne 0 ]]; then
        gate_status="FAIL"
        blocking_class="FAIL_FUNCTIONAL"
    elif [[ "${success_gate}" != "PASS" || "${duration_gate}" != "PASS" || "${coverage_gate}" != "PASS" ]]; then
        gate_status="FAIL"
        blocking_class="FAIL_THRESHOLD"
    fi

    local pid git_head window_start window_end
    if [[ -f "${preflight_file}" ]]; then
        pid="$(parse_kv "${preflight_file}" "pid")"
        git_head="$(parse_kv "${preflight_file}" "git_head")"
        window_start="$(parse_kv "${preflight_file}" "window_start")"
        window_end="$(parse_kv "${preflight_file}" "window_end")"
    else
        pid=""
        git_head=""
        window_start=""
        window_end=""
    fi

    record_kv "window_start" "${window_start}"
    record_kv "window_end" "${window_end}"
    record_kv "pid" "${pid}"
    record_kv "git_head" "${git_head}"
    record_kv "suite_exit_code" "${suite_ec}"
    record_kv "suite_package" "${package_dir}"
    record_kv "runs_required" "${RUNS}"
    record_kv "runs_executed" "${runs_executed}"
    record_kv "pass" "${pass_count}"
    record_kv "warn" "${warn_count}"
    record_kv "fail" "${fail_count}"
    record_kv "env" "${env_count}"
    record_kv "success_rate" "${success_rate}"
    record_kv "success_rate_threshold" "${SUCCESS_RATE_THRESHOLD}"
    record_kv "avg_duration_s" "${avg_duration}"
    record_kv "avg_duration_threshold_s" "${MAX_AVG_DURATION_S}"
    record_kv "path_recording_pass_runs" "${recording_pass_runs}"
    record_kv "path_caption_pass_runs" "${caption_pass_runs}"
    record_kv "path_screenshot_pass_runs" "${screenshot_pass_runs}"
    record_kv "path_status" "recording:${recording_pass_runs},caption:${caption_pass_runs},screenshot:${screenshot_pass_runs}"
    record_kv "success_gate" "${success_gate}"
    record_kv "duration_gate" "${duration_gate}"
    record_kv "coverage_gate" "${coverage_gate}"
    record_kv "final_status" "${gate_status}"
    record_kv "blocking_class" "${blocking_class}"

    cat "${REPORT_DIR}/SUMMARY.txt"

    case "${gate_status}" in
        PASS)
            exit 0
            ;;
        FAIL)
            exit 1
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
