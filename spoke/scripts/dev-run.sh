#!/bin/bash
# 稳定的本地调试运行入口：
# 1. Swift Bundler 打包
# 2. 复制到固定路径的开发版 App
# 3. 用 Apple Development 证书重签
# 4. 启动日志采集
# 5. 启动应用
#
# 默认行为：
# - 固定安装路径: ~/Applications/SpokenAnyWhere Dev.app
# - 默认启动模式: open
#
# 可选环境变量：
# - SWIFT_BUNDLER_BIN
# - APP_SIGN_IDENTITY
# - APP_INSTALL_PATH
# - APP_LAUNCH_MODE=open|exec
# - LOG_DIR
# - KEEP_LOG_COUNT
# - DRY_RUN=1
#
# 如果需要把 SPOKE_* 环境变量传给应用，请使用：
#   APP_LAUNCH_MODE=exec SPOKE_DEBUG_AUTOMATION=1 ./dev.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="SpokenAnyWhere"
APP_BUNDLE_ID="com.spokeanywhere"
BUNDLER="${SWIFT_BUNDLER_BIN:-$HOME/.local/bin/swift-bundler}"
BUILD_APP="$ROOT_DIR/.build/bundler/${APP_NAME}.app"
INSTALL_APP="${APP_INSTALL_PATH:-$HOME/Applications/${APP_NAME} Dev.app}"
INSTALL_BIN="$INSTALL_APP/Contents/MacOS/${APP_NAME}"
LOG_DIR="${LOG_DIR:-$ROOT_DIR/../.tmp_frames}"
KEEP_LOG_COUNT="${KEEP_LOG_COUNT:-20}"
LAUNCH_MODE="${APP_LAUNCH_MODE:-open}"
DRY_RUN="${DRY_RUN:-0}"
CURRENT_LOG_FILE=""
CURRENT_LOG_PID=""

log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

run_cmd() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[DRY-RUN] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

require_bundler() {
  if [[ ! -x "$BUNDLER" ]]; then
    log_error "Swift Bundler 未安装: $BUNDLER"
    echo "请先安装 swift-bundler："
    echo "  git clone https://github.com/stackotter/swift-bundler /tmp/swift-bundler"
    echo "  cd /tmp/swift-bundler && swift build -c release"
    echo "  mkdir -p ~/.local/bin && cp .build/release/swift-bundler ~/.local/bin/"
    exit 1
  fi
}

find_sign_identity() {
  if [[ -n "${APP_SIGN_IDENTITY:-}" ]]; then
    echo "$APP_SIGN_IDENTITY"
    return 0
  fi

  security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development/ {print $2; exit}'
}

stop_running_instances() {
  log_info "停止旧实例..."
  run_cmd pkill -x "$APP_NAME" || true
  sleep 0.5
}

bundle_app() {
  log_info "构建应用包..."
  run_cmd "$BUNDLER" bundle
}

install_app_bundle() {
  if [[ ! -d "$BUILD_APP" ]]; then
    log_error "打包产物不存在: $BUILD_APP"
    exit 1
  fi

  log_info "同步到固定开发路径: $INSTALL_APP"
  run_cmd mkdir -p "$(dirname "$INSTALL_APP")"
  run_cmd rm -rf "$INSTALL_APP"
  run_cmd ditto "$BUILD_APP" "$INSTALL_APP"
}

sign_app_bundle() {
  local identity="$1"
  if [[ -z "$identity" ]]; then
    log_error "未找到可用的 Apple Development 签名证书"
    echo "请在钥匙串中安装开发证书，或显式设置 APP_SIGN_IDENTITY"
    exit 1
  fi

  log_info "使用开发证书签名: $identity"
  run_cmd codesign --force --deep --sign "$identity" --identifier "$APP_BUNDLE_ID" "$INSTALL_APP"

  if [[ "$DRY_RUN" != "1" ]]; then
    codesign --verify --deep --strict "$INSTALL_APP"
  fi
}

prepare_logs() {
  CURRENT_LOG_FILE="$LOG_DIR/dev-$(date +%Y%m%d-%H%M%S).log"
  run_cmd mkdir -p "$LOG_DIR"
  run_cmd /bin/sh -c "ls -t \"$LOG_DIR\"/dev-*.log 2>/dev/null | tail -n +$((KEEP_LOG_COUNT + 1)) | xargs rm -f 2>/dev/null || true"

  log_info "日志输出到: $CURRENT_LOG_FILE"
  echo "       tail -f \"$CURRENT_LOG_FILE\""

  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi

  /usr/bin/log stream --level debug --style compact --predicate '
    process == "'"$APP_NAME"'" AND (
      subsystem BEGINSWITH "com.spokeanywhere" OR
      (messageType == error) OR
      (messageType == fault)
    )
  ' > "$CURRENT_LOG_FILE" 2>&1 &
  CURRENT_LOG_PID="$!"
}

launch_app_bundle() {
  if [[ "$LAUNCH_MODE" == "exec" ]]; then
    log_info "以 exec 模式启动应用..."
    if [[ "$DRY_RUN" == "1" ]]; then
      printf '[DRY-RUN] '
      printf '%q ' env \
        PATH="$PATH" \
        HOME="$HOME" \
        USER="${USER:-}" \
        SHELL="${SHELL:-/bin/zsh}" \
        SPOKE_DEBUG_AUTOMATION="${SPOKE_DEBUG_AUTOMATION:-}" \
        SPOKE_SKIP_ACCESSIBILITY_ALERTS="${SPOKE_SKIP_ACCESSIBILITY_ALERTS:-}" \
        SPOKE_AUDIO_WARMUP="${SPOKE_AUDIO_WARMUP:-}" \
        SPOKE_STARTUP_LOG="${SPOKE_STARTUP_LOG:-}" \
        SPOKE_PERF_LOG="${SPOKE_PERF_LOG:-}" \
        "$INSTALL_BIN"
      printf '\n'
    else
      env \
        PATH="$PATH" \
        HOME="$HOME" \
        USER="${USER:-}" \
        SHELL="${SHELL:-/bin/zsh}" \
        SPOKE_DEBUG_AUTOMATION="${SPOKE_DEBUG_AUTOMATION:-}" \
        SPOKE_SKIP_ACCESSIBILITY_ALERTS="${SPOKE_SKIP_ACCESSIBILITY_ALERTS:-}" \
        SPOKE_AUDIO_WARMUP="${SPOKE_AUDIO_WARMUP:-}" \
        SPOKE_STARTUP_LOG="${SPOKE_STARTUP_LOG:-}" \
        SPOKE_PERF_LOG="${SPOKE_PERF_LOG:-}" \
        "$INSTALL_BIN" &
    fi
    return 0
  fi

  log_info "以 open 模式启动应用..."
  run_cmd open "$INSTALL_APP"
}

print_next_steps() {
  cat <<EOF

[NEXT]
- 稳定调试入口: ./dev.sh
- 固定开发版路径: $INSTALL_APP
- bundle id: $APP_BUNDLE_ID

[PERMISSIONS]
请在“系统设置 -> 隐私与安全性 -> 辅助功能”中为下面这个固定路径授权：
  $INSTALL_APP

如果权限状态混乱，可先执行：
  tccutil reset Accessibility $APP_BUNDLE_ID

如果要把 SPOKE_* 环境变量传给应用，请这样运行：
  APP_LAUNCH_MODE=exec SPOKE_DEBUG_AUTOMATION=1 ./dev.sh
EOF
}

main() {
  require_bundler

  local identity
  identity="$(find_sign_identity)"

  stop_running_instances
  bundle_app
  install_app_bundle
  sign_app_bundle "$identity"

  prepare_logs
  if [[ "$DRY_RUN" != "1" ]]; then
    trap '[[ -n "$CURRENT_LOG_PID" ]] && kill "$CURRENT_LOG_PID" 2>/dev/null || true' EXIT
  fi

  launch_app_bundle
  print_next_steps
}

main "$@"
