#!/bin/bash
# 运行所有单元测试
# 用法:
#   ./Tests/run-tests.sh                 # 默认测试
#   ./Tests/run-tests.sh --strict-concurrency  # 额外运行并发诊断

set -e

cd "$(dirname "$0")/.."

run_strict_concurrency=false
if [[ "${1:-}" == "--strict-concurrency" ]]; then
    run_strict_concurrency=true
fi

echo "🧪 运行所有单元测试"
echo "=================================="

# 编译并运行 TextExtractionTests
echo ""
echo "📦 编译 TextExtractionTests..."
swiftc -parse-as-library -o /tmp/text_extraction_tests Tests/TextExtractionTests.swift
echo "🚀 运行测试..."
/tmp/text_extraction_tests

echo ""
echo "=================================="

# 编译并运行 AttachmentTests
echo ""
echo "📦 编译 AttachmentTests..."
swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift
echo "🚀 运行测试..."
/tmp/attachment_tests

echo ""
echo "=================================="
if [[ "$run_strict_concurrency" == true ]]; then
    echo ""
    echo "🔍 运行并发诊断..."
    ./Tests/run-concurrency-check.sh
    echo "=================================="
fi
echo "💡 并发诊断可单独执行: ./Tests/run-concurrency-check.sh"
echo "🎉 所有测试完成!"
