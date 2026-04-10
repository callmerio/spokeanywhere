#!/bin/bash

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TIMESTAMP="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT_BASE="${OUTPUT_DIR:-$ROOT/verify/quality-gate}"
RUN_DIR="$OUTPUT_BASE/$TIMESTAMP"
SUMMARY_PATH="$RUN_DIR/summary.md"

mkdir -p "$RUN_DIR" 2>/dev/null || {
  echo "❌ [环境失败] 无法创建日志目录: $RUN_DIR"
  exit 1
}

fail_gate() {
  local category="$1"
  local detail="$2"

  {
    echo "# Architecture Quality Gate"
    echo ""
    echo "- status: failed"
    echo "- category: $category"
    echo "- detail: $detail"
    echo "- log_dir: $RUN_DIR"
  } > "$SUMMARY_PATH"

  echo "❌ [$category] $detail"
  echo "日志目录: $RUN_DIR"
  exit 1
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || fail_gate "环境失败" "缺少命令: $name"
}

run_step() {
  local label="$1"
  local category="$2"
  shift 2

  local log_path="$RUN_DIR/${label}.log"
  if "$@" >"$log_path" 2>&1; then
    echo "✅ $label 通过"
    return 0
  fi

  echo "❌ $label 失败"
  tail -n 40 "$log_path" 2>/dev/null || true
  fail_gate "$category" "$label 失败，详见 $(basename "$log_path")"
}

count_matches() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo 0
    return 0
  fi

  local count
  count="$(grep -cve '^[[:space:]]*$' "$path" 2>/dev/null || true)"
  echo "${count:-0}"
}

require_command swift
require_command rg
[[ -f "$ROOT/Tests/run-concurrency-check.sh" ]] || fail_gate "环境失败" "缺少 Tests/run-concurrency-check.sh"

cd "$ROOT" || fail_gate "环境失败" "无法进入仓库根目录"

echo "▶ Architecture quality gate"
echo "日志目录: $RUN_DIR"

run_step "build" "构建失败" swift build
run_step "test" "测试失败" swift test
run_step "concurrency" "并发失败" bash Tests/run-concurrency-check.sh

rg -n '\.shared\.' App Core Services UI >"$RUN_DIR/shared-scan.log" 2>&1 || true
rg -n 'NotificationCenter\.default\.(addObserver|post)' App Core Services UI >"$RUN_DIR/notification-scan.log" 2>&1 || true

SHARED_MATCHES="$(count_matches "$RUN_DIR/shared-scan.log")"
NOTIFICATION_MATCHES="$(count_matches "$RUN_DIR/notification-scan.log")"

{
  echo "# Architecture Quality Gate"
  echo ""
  echo "- status: passed"
  echo "- mode: provider-neutral"
  echo "- log_dir: $RUN_DIR"
  echo "- hard_fail_checks:"
  echo "  - swift build"
  echo "  - swift test"
  echo "  - bash Tests/run-concurrency-check.sh"
  echo "- report_only_scans:"
  echo "  - shared matches: $SHARED_MATCHES"
  echo "  - notification matches: $NOTIFICATION_MATCHES"
  echo ""
  echo "## Files"
  echo ""
  echo "- build.log"
  echo "- test.log"
  echo "- concurrency.log"
  echo "- shared-scan.log"
  echo "- notification-scan.log"
} > "$SUMMARY_PATH"

echo "ℹ️ report-only scan: .shared matches = $SHARED_MATCHES"
echo "ℹ️ report-only scan: NotificationCenter matches = $NOTIFICATION_MATCHES"
echo "✅ Quality gate passed"
echo "摘要: $SUMMARY_PATH"
