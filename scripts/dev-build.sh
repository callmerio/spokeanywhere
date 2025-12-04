#!/bin/bash
# 开发构建脚本
# Usage: ./scripts/dev-build.sh
#
# 流程: 构建 → 签名(开发者证书) → 启动
# 关键: 使用固定开发者证书签名，TCC 会认为是同一个应用，无需重复授权

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SPOKE_DIR="$PROJECT_ROOT/spoke"
BUILD_DIR="$SPOKE_DIR/.build/bundler"
APP_PATH="$BUILD_DIR/SpokenAnyWhere.app"
BUNDLE_ID="app.spokenly"
SIGN_IDENTITY="Apple Development"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[DEV]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
err() { echo -e "${RED}[ERR]${NC} $1"; exit 1; }

# 1. 终止旧进程
pkill -f "SpokenAnyWhere" 2>/dev/null || true

# 2. 构建
log "构建 App..."
cd "$SPOKE_DIR"

if ! command -v swift-bundler &> /dev/null; then
    err "swift-bundler 未安装. 运行: brew install stackotter/tap/swift-bundler"
fi

swift-bundler bundle -c debug 2>&1 | tail -5
ok "构建完成"

# 3. 签名 (必须使用开发者证书，这样 TCC 才会认为是同一个应用)
log "签名 App..."
if codesign --force --deep --sign "$SIGN_IDENTITY" --identifier "$BUNDLE_ID" "$APP_PATH" 2>&1; then
    ok "签名完成 (开发者证书)"
else
    err "签名失败！请确保已安装开发者证书: security find-identity -v -p codesigning"
fi

# 4. 启动
log "启动 App..."
open "$APP_PATH"

ok "完成! 权限保持不变，无需重新授权。"
