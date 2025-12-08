#!/bin/bash
# 开发调试脚本 - 使用 Swift Bundler 构建并运行 .app
# macOS 26+ 要求使用 .app 包才能正确获得屏幕录制权限
# 参考: https://developer.apple.com/forums/thread/807898

set -e

BUNDLER="$HOME/.local/bin/swift-bundler"

# 检查 swift-bundler 是否安装
if [ ! -f "$BUNDLER" ]; then
    echo "❌ Swift Bundler 未安装，请运行:"
    echo "   git clone https://github.com/stackotter/swift-bundler /tmp/swift-bundler"
    echo "   cd /tmp/swift-bundler && swift build -c release"
    echo "   mkdir -p ~/.local/bin && cp .build/release/swift-bundler ~/.local/bin/"
    exit 1
fi

echo "🛑 停止旧实例..."
pkill -f "SpokenAnyWhere" 2>/dev/null || true
sleep 0.5

echo "🔨 构建应用..."
$BUNDLER bundle

echo "🔏 使用开发者证书签名..."
# adhoc 签名会阻止 TCC 工作，必须使用开发者证书
# 参考: https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements
codesign --force --deep --sign "Apple Development" --identifier "app.spokenly" .build/bundler/SpokenAnyWhere.app

LOG_DIR="../.tmp_frames"
LOG_FILE="$LOG_DIR/dev-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

echo "📜 日志输出到: $LOG_FILE"
echo "   查看日志: tail -f $LOG_FILE"
echo "   搜索日志: grep -E 'error|Error|❌' $LOG_FILE"

# 先启动 log stream，再启动应用，确保捕获启动日志
# 只保留应用自定义日志（com.spokeanywhere 和 app.spokenly）
# 过滤掉所有系统噪音日志
log stream --level debug --predicate '
    process == "SpokenAnyWhere" AND (
        subsystem BEGINSWITH "com.spokeanywhere" OR
        subsystem == "app.spokenly" OR
        (messageType == error) OR
        (messageType == fault)
    )
' --style compact > "$LOG_FILE" 2>&1 &
LOG_PID=$!
sleep 0.5

echo "🚀 启动应用..."
open .build/bundler/SpokenAnyWhere.app

echo "📡 日志进程 PID: $LOG_PID (按 Ctrl+C 停止)"
trap "kill $LOG_PID 2>/dev/null; echo '日志已停止'" EXIT

# 实时显示关键日志（包含词典/LM/字典/OCR/Selection相关）
tail -f "$LOG_FILE" | grep --line-buffered -E 'error|Error|❌|✅|Recognition|Transcription|Audio|词典|预编译|LM|Dictionary|languageModel|customized|OCR|AppContext|ScreenOCR|🔍|📱|Selection|Toolbar|选中|工具栏|📋|🖱️'
