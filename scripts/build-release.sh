#!/bin/bash
# 本地构建发布版本脚本
# Usage: ./scripts/build-release.sh

set -e

cd "$(dirname "$0")/.."

echo "🔨 Building SpokenAnyWhere..."

cd spoke

# 构建 Release 版本 (直接用 swift build)
echo "🏗️ Building Release..."
swift build -c release

# 创建输出目录
mkdir -p dist

# 创建 .app bundle
echo "📦 Creating App Bundle..."
rm -rf dist/SpokenAnyWhere.app
mkdir -p dist/SpokenAnyWhere.app/Contents/MacOS
mkdir -p dist/SpokenAnyWhere.app/Contents/Resources

# 复制可执行文件
cp .build/release/SpokenAnyWhere dist/SpokenAnyWhere.app/Contents/MacOS/

# 创建 Info.plist
cat > dist/SpokenAnyWhere.app/Contents/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>SpokenAnyWhere</string>
  <key>CFBundleIdentifier</key>
  <string>app.spokenly</string>
  <key>CFBundleName</key>
  <string>SpokenAnyWhere</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>SpokenAnyWhere needs microphone access for voice transcription.</string>
  <key>NSScreenCaptureUsageDescription</key>
  <string>实时字幕功能需要捕获系统音频</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>语音识别功能需要使用语音识别服务</string>
</dict>
</plist>
EOF

# 签名 (使用开发者证书)
echo "🔏 Signing App..."
if security find-identity -v -p codesigning | grep -q "Apple Development"; then
    codesign --force --deep --sign "Apple Development" --identifier "app.spokenly" dist/SpokenAnyWhere.app
    echo "✅ Signed with Apple Development certificate"
else
    echo "⚠️  No developer certificate found, using adhoc signing"
    codesign --force --deep --sign - --identifier "app.spokenly" dist/SpokenAnyWhere.app
fi

echo "📀 Creating DMG..."
hdiutil create -volname "SpokenAnyWhere" \
  -srcfolder dist/SpokenAnyWhere.app \
  -ov -format UDZO \
  dist/SpokenAnyWhere.dmg

echo ""
echo "✅ Build complete!"
echo "📁 Output: spoke/dist/"
echo "   - SpokenAnyWhere.app"
echo "   - SpokenAnyWhere.dmg"
