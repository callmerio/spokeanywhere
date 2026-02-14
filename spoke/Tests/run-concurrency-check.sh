#!/bin/bash
# 渐进式并发诊断入口
# 用法: ./Tests/run-concurrency-check.sh

set -euo pipefail

cd "$(dirname "$0")/.."

echo "🔍 运行 Strict Concurrency 诊断"
echo "=================================="
echo "模式: warn-concurrency + strict-concurrency=complete"

swift build \
  -Xswiftc -warn-concurrency \
  -Xswiftc -strict-concurrency=complete

echo ""
echo "✅ strict-concurrency build 通过"
