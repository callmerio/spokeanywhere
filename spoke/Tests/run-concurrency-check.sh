#!/bin/bash
# 渐进式并发诊断入口
# 用法: ./Tests/run-concurrency-check.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🔍 运行 Strict Concurrency 诊断"
echo "=================================="
echo "模式: warn-concurrency + strict-concurrency=complete"

# Capture build output to check for warnings
BUILD_OUTPUT=$(swift build \
  -Xswiftc -warn-concurrency \
  -Xswiftc -strict-concurrency=complete 2>&1) || {
  echo "❌ Build failed"
  echo "$BUILD_OUTPUT"
  exit 1
}

echo "$BUILD_OUTPUT"

# Count warnings
WARNING_COUNT=$(echo "$BUILD_OUTPUT" | grep -c "warning:" || true)
UNHANDLED_COUNT=$(echo "$BUILD_OUTPUT" | grep -c "unhandled files" || true)

TOTAL_ISSUES=$((WARNING_COUNT + UNHANDLED_COUNT))

if [ $TOTAL_ISSUES -gt 0 ]; then
  echo ""
  echo "❌ Found $WARNING_COUNT warning(s) and $UNHANDLED_COUNT unhandled file(s)"
  echo "Strict concurrency gate FAILED"
  exit 1
fi

echo ""
echo "✅ strict-concurrency build 通过 (0 warnings)"
