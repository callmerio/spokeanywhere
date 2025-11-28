#!/bin/bash
# 运行所有单元测试
# 用法: ./Tests/run-tests.sh

set -e

cd "$(dirname "$0")/.."

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
echo "🎉 所有测试完成!"
