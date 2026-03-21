#!/bin/bash
# T002: Verify debug automation hooks are reachable in Debug and unreachable in Release.

set -euo pipefail

APP_NAME="${APP_NAME:-SpokenAnyWhere}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/spoke-t002-debug-isolation}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
REPORT_DIR="${OUTPUT_DIR}/${TIMESTAMP}"

mkdir -p "${REPORT_DIR}"

log() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; }

run_and_record() {
    local name="$1"
    shift
    local log_file="${REPORT_DIR}/${name}.log"
    set +e
    "$@" >"${log_file}" 2>&1
    local ec=$?
    set -e
    echo "${name}|${ec}|${log_file}" >> "${REPORT_DIR}/exit-codes.txt"
    return ${ec}
}

cd "${REPO_ROOT}"

run_and_record "01-swift-build-debug" swift build
run_and_record "02-swift-build-release" swift build -c release

DEBUG_BIN_DIR="$(swift build --show-bin-path)"
RELEASE_BIN_DIR="$(swift build -c release --show-bin-path)"
DEBUG_BIN="${DEBUG_BIN_DIR}/${APP_NAME}"
RELEASE_BIN="${RELEASE_BIN_DIR}/${APP_NAME}"

if [[ ! -x "${DEBUG_BIN}" ]]; then
    err "Debug binary not found: ${DEBUG_BIN}"
    exit 2
fi
if [[ ! -x "${RELEASE_BIN}" ]]; then
    err "Release binary not found: ${RELEASE_BIN}"
    exit 2
fi

strings "${DEBUG_BIN}" > "${REPORT_DIR}/03-debug.strings"
strings "${RELEASE_BIN}" > "${REPORT_DIR}/04-release.strings"
otool -s __TEXT __cstring "${DEBUG_BIN}" > "${REPORT_DIR}/05-debug.otool-cstring" 2>&1 || true
otool -s __TEXT __cstring "${RELEASE_BIN}" > "${REPORT_DIR}/06-release.otool-cstring" 2>&1 || true

MARKERS=(
    "com.spokeanywhere.debug.automation.trigger"
    "[DebugAutomation]"
    "recording.toggle"
    "caption.toggle"
    "screenshot.capture"
    "SPOKE_DEBUG_AUTOMATION"
)

DEBUG_HIT_COUNT=0
RELEASE_HIT_COUNT=0

{
    echo "debug_binary=${DEBUG_BIN}"
    echo "release_binary=${RELEASE_BIN}"
    echo "markers_checked=${#MARKERS[@]}"
} > "${REPORT_DIR}/summary.txt"

for marker in "${MARKERS[@]}"; do
    debug_hit="NO"
    release_hit="NO"

    if rg -F -q "${marker}" "${REPORT_DIR}/03-debug.strings"; then
        debug_hit="YES"
        DEBUG_HIT_COUNT=$((DEBUG_HIT_COUNT + 1))
    fi

    if rg -F -q "${marker}" "${REPORT_DIR}/04-release.strings"; then
        release_hit="YES"
        RELEASE_HIT_COUNT=$((RELEASE_HIT_COUNT + 1))
    fi

    echo "marker=${marker}|debug=${debug_hit}|release=${release_hit}" >> "${REPORT_DIR}/summary.txt"
done

STATUS="PASS"
if [[ ${DEBUG_HIT_COUNT} -eq 0 ]]; then
    STATUS="FAIL"
fi
if [[ ${RELEASE_HIT_COUNT} -ne 0 ]]; then
    STATUS="FAIL"
fi

{
    cat "${REPORT_DIR}/exit-codes.txt"
    echo "debug_hit_count=${DEBUG_HIT_COUNT}"
    echo "release_hit_count=${RELEASE_HIT_COUNT}"
    echo "final_status=${STATUS}"
} >> "${REPORT_DIR}/summary.txt"

cat "${REPORT_DIR}/summary.txt"
log "report_dir=${REPORT_DIR}"

if [[ "${STATUS}" == "PASS" ]]; then
    exit 0
fi
exit 1

