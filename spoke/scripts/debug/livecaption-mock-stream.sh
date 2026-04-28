#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

HELPER_SWIFT="$(mktemp /tmp/livecaption-debug-action-XXXXXX.swift)"
HELPER_BIN="$(mktemp /tmp/livecaption-debug-action-XXXXXX)"

cleanup() {
  rm -f "$HELPER_SWIFT" "$HELPER_BIN"
}
trap cleanup EXIT

cat > "$HELPER_SWIFT" <<'SWIFT'
import Foundation

let name = Notification.Name("com.spokeanywhere.debug.automation.trigger")
DistributedNotificationCenter.default().postNotificationName(
    name,
    object: nil,
    userInfo: ["action": "caption.mock.long_translation"],
    deliverImmediately: true
)
print("action=caption.mock.long_translation")
SWIFT

swiftc "$HELPER_SWIFT" -o "$HELPER_BIN"
"$HELPER_BIN"

cat <<EOF
[NEXT]
- 更稳的自动 mock 入口：\`APP_LAUNCH_MODE=exec SPOKE_DEBUG_AUTOMATION=1 SPOKE_DEBUG_LIVECAPTION_SCENARIO=long_translation ./dev.sh\`
- 若应用已在带 debug automation 的 exec 模式中运行，也可以继续使用本脚本直接发送 \`caption.mock.long_translation\`。
- 当前仓库根目录: $ROOT_DIR
EOF
