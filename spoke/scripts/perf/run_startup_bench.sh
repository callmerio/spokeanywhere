#!/bin/bash
# Startup performance benchmark for SpokenAnyWhere.
# Runs repeated cold launches with synthetic pinned screenshot fixtures
# and emits a machine-readable JSON report.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

RUNS="${RUNS:-15}"
ITEM_COUNTS="${ITEM_COUNTS:-10 20 50}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-20}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"
REPORT_PATH="${REPORT_PATH:-docs/perf-startup-report.json}"
WORK_DIR="${WORK_DIR:-/tmp/spoke-perf-startup}"
LOG_DIR="$WORK_DIR/logs"
FIXTURE_BASE="$WORK_DIR/screenshot_data"

mkdir -p "$LOG_DIR" "$(dirname "$REPORT_PATH")"
rm -f "$LOG_DIR"/*.log 2>/dev/null || true

echo "== Startup bench =="
echo "ROOT_DIR: $ROOT_DIR"
echo "RUNS: $RUNS"
echo "ITEM_COUNTS: $ITEM_COUNTS"
echo "BUILD_CONFIG: $BUILD_CONFIG"
echo "REPORT_PATH: $REPORT_PATH"
echo

echo "[1/3] Building binary..."
swift build -c "$BUILD_CONFIG" >/dev/null
BIN_DIR="$(swift build -c "$BUILD_CONFIG" --show-bin-path)"
APP_BIN="$BIN_DIR/SpokenAnyWhere"
if [[ ! -x "$APP_BIN" ]]; then
  echo "ERROR: app binary not found: $APP_BIN"
  exit 1
fi

extract_metric() {
  local key="$1"
  local file="$2"
  rg -o "${key}=[0-9]+" "$file" | tail -n 1 | cut -d '=' -f2 || true
}

wait_for_metric() {
  local key="$1"
  local file="$2"
  local timeout="$3"
  local ticks=$((timeout * 10))
  local i
  for ((i = 0; i < ticks; i++)); do
    if rg -q "${key}=[0-9]+" "$file"; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

generate_fixture() {
  local count="$1"
  local screenshot_dir="$FIXTURE_BASE/Screenshots"
  local store_path="$FIXTURE_BASE/screenshot_items.json"

  rm -rf "$FIXTURE_BASE"
  mkdir -p "$screenshot_dir"

  swift - "$count" "$screenshot_dir" "$store_path" <<'SWIFT'
import Foundation
import CoreGraphics

struct FixtureItem: Codable {
    let id: UUID
    let createdAt: Date
    let imagePath: String
    let frame: CGRect
    let originalSize: CGSize
    let isPinned: Bool
    let isLocked: Bool
    let isMarked: Bool
    let opacity: Double
    let zoomLevel: Double
    let appearance: String
    let screenLocalizedName: String?
}

let args = CommandLine.arguments
let count = Int(args[1]) ?? 0
let screenshotDir = args[2]
let storePath = args[3]

let pngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/a3cAAAAASUVORK5CYII="
guard let pngData = Data(base64Encoded: pngBase64) else {
    fputs("invalid png fixture base64\n", stderr)
    exit(2)
}

var items: [FixtureItem] = []
items.reserveCapacity(count)

let now = Date()
for index in 0..<count {
    let id = UUID()
    let imagePath = "\(screenshotDir)/\(id.uuidString).png"
    try pngData.write(to: URL(fileURLWithPath: imagePath), options: .atomic)

    let frame = CGRect(x: 100 + (index % 5) * 24, y: 100 + (index / 5) * 24, width: 320, height: 180)
    let item = FixtureItem(
        id: id,
        createdAt: now.addingTimeInterval(Double(-index)),
        imagePath: imagePath,
        frame: frame,
        originalSize: CGSize(width: 320, height: 180),
        isPinned: true,
        isLocked: false,
        isMarked: false,
        opacity: 1.0,
        zoomLevel: 1.0,
        appearance: "default",
        screenLocalizedName: nil
    )
    items.append(item)
}

let encoder = JSONEncoder()
let data = try encoder.encode(items)
try data.write(to: URL(fileURLWithPath: storePath), options: .atomic)
print("fixture_items=\(count)")
SWIFT
}

summary_json() {
  local file="$1"
  local n
  n="$(wc -l <"$file" | tr -d ' ')"
  if [[ "$n" -eq 0 ]]; then
    echo '{"samples":0,"p50":0,"p95":0,"max":0,"mean":0}'
    return
  fi

  local sorted="${file}.sorted"
  sort -n "$file" >"$sorted"

  local p50_idx p95_idx p50 p95 max mean
  p50_idx=$(( (50 * (n - 1)) / 100 + 1 ))
  p95_idx=$(( (95 * (n - 1)) / 100 + 1 ))
  p50="$(sed -n "${p50_idx}p" "$sorted")"
  p95="$(sed -n "${p95_idx}p" "$sorted")"
  max="$(tail -n 1 "$sorted")"
  mean="$(awk '{sum += $1} END { printf "%.2f", sum / NR }' "$file")"
  rm -f "$sorted"

  echo "{\"samples\":$n,\"p50\":$p50,\"p95\":$p95,\"max\":$max,\"mean\":$mean}"
}

run_errors=0
cases_tmp="$WORK_DIR/cases.jsonl"
: >"$cases_tmp"

echo "[2/3] Running benchmark matrix..."
for count in $ITEM_COUNTS; do
  launch_values="$WORK_DIR/launch_${count}.txt"
  decode_values="$WORK_DIR/decode_${count}.txt"
  ui_values="$WORK_DIR/ui_${count}.txt"
  : >"$launch_values"
  : >"$decode_values"
  : >"$ui_values"

  restore_count_all_match=true

  echo "  - case item_count=$count"
  for run in $(seq 1 "$RUNS"); do
    generate_fixture "$count" >/dev/null
    log_file="$LOG_DIR/startup_items${count}_run${run}.log"

    (
      NSUnbufferedIO=YES \
      SPOKE_PERF_LOG=1 \
      SPOKE_SCREENSHOT_BASE_DIR="$FIXTURE_BASE" \
      "$APP_BIN" >"$log_file" 2>&1
    ) &
    app_pid=$!

    if ! wait_for_metric "launch_total_ms" "$log_file" "$TIMEOUT_SECONDS"; then
      echo "    run=$run ERROR: timeout waiting launch metric"
      run_errors=$((run_errors + 1))
      kill "$app_pid" 2>/dev/null || true
      wait "$app_pid" 2>/dev/null || true
      continue
    fi

    if ! wait_for_metric "restore_total_ms" "$log_file" "$TIMEOUT_SECONDS"; then
      echo "    run=$run ERROR: timeout waiting restore metric"
      run_errors=$((run_errors + 1))
      kill "$app_pid" 2>/dev/null || true
      wait "$app_pid" 2>/dev/null || true
      continue
    fi

    kill "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true

    launch_ms="$(extract_metric "launch_total_ms" "$log_file")"
    decode_ms="$(extract_metric "restore_decode_ms" "$log_file")"
    ui_ms="$(extract_metric "restore_ui_ms" "$log_file")"
    restored_count="$(extract_metric "restored_count" "$log_file")"

    if [[ -z "$launch_ms" || -z "$decode_ms" || -z "$ui_ms" ]]; then
      echo "    run=$run ERROR: missing metric(s), see $log_file"
      run_errors=$((run_errors + 1))
      continue
    fi

    echo "$launch_ms" >>"$launch_values"
    echo "$decode_ms" >>"$decode_values"
    echo "$ui_ms" >>"$ui_values"

    if [[ "$restored_count" != "$count" ]]; then
      restore_count_all_match=false
    fi

    echo "    run=$run launch=${launch_ms}ms decode=${decode_ms}ms ui=${ui_ms}ms restored=${restored_count:-NA}/$count"
  done

  launch_json="$(summary_json "$launch_values")"
  decode_json="$(summary_json "$decode_values")"
  ui_json="$(summary_json "$ui_values")"

  cat >>"$cases_tmp" <<EOF
{"item_count":$count,"runs":$RUNS,"restore_count_all_match":$restore_count_all_match,"launch_total_ms":$launch_json,"restore_decode_ms":$decode_json,"restore_ui_ms":$ui_json}
EOF
done

echo "[3/3] Writing report..."
{
  echo "{"
  echo "  \"generated_at\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
  echo "  \"config\": {"
  echo "    \"runs\": $RUNS,"
  echo "    \"item_counts\": [$(echo "$ITEM_COUNTS" | tr ' ' ',' )],"
  echo "    \"timeout_seconds\": $TIMEOUT_SECONDS,"
  echo "    \"build_config\": \"${BUILD_CONFIG}\""
  echo "  },"
  echo "  \"run_errors\": $run_errors,"
  echo "  \"cases\": ["
  first=1
  while IFS= read -r line; do
    if [[ $first -eq 1 ]]; then
      first=0
    else
      echo ","
    fi
    echo "    $line"
  done <"$cases_tmp"
  echo
  echo "  ]"
  echo "}"
} >"$REPORT_PATH"

echo "Report written to: $REPORT_PATH"
echo "Raw logs: $LOG_DIR"

if [[ "$run_errors" -gt 0 ]]; then
  echo "Completed with run_errors=$run_errors"
  exit 1
fi

echo "Startup benchmark completed successfully."
