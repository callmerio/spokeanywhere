# Spec: 复制优化后图片功能

## Overview

当截图被 AI 放大/优化后，右键"复制图片"应复制优化后的图片而非原图。该行为可在设置中配置。

## User Story

> 作为用户，我希望复制截图时能获得 AI 增强后的高清版本，而不是模糊的原图。

## Requirements

### R1: 复制增强后图片
- 当 `copyEnhancedImage` 设置为 `true` 时，复制操作应使用当前 `imageView.image`（可能是增强后的）
- 当设置为 `false` 时，保持原有行为（复制原图）

### R2: 设置开关
- 在 `ScreenshotSettings` 中添加 `copyEnhancedImage: Bool` 属性
- 默认值：`true`（默认复制增强后图片）
- 持久化到 `UserDefaults`

### R3: 设置 UI
- 在 `ScreenshotSettingsView` 中添加 Toggle 开关
- 位置：放大画质增强选项下方
- 标题："复制优化后图片"
- 描述："复制时使用 AI 增强后的高清图片"

## Technical Design

### 修改文件

1. **`ScreenshotSettings.swift`**
   - 添加 `@Published var copyEnhancedImage: Bool`
   - UserDefaults key: `"Screenshot.CopyEnhancedImage"`

2. **`ScreenshotContentView.swift`**
   - 添加 `func getCurrentDisplayImage() -> NSImage?`
   - 返回 `imageView.image`（当前显示的图片）

3. **`ScreenshotManager.swift`**
   - 修改 `copyToClipboard(_ item:)` 签名为 `copyToClipboard(_ item:, enhancedImage: NSImage? = nil)`
   - 根据 `ScreenshotSettings.shared.copyEnhancedImage` 决定使用哪个图片

4. **调用点更新**
   - `ScreenshotContentView.performCopyImage()` 传递 `imageView.image`
   - `ScreenshotWindow` 快捷键 C 传递增强图
   - 其他调用点保持原有行为

5. **`ScreenshotSettingsView.swift`**
   - 添加 Toggle UI

## Acceptance Criteria

- [ ] 设置开启时，复制的图片是 AI 增强后的版本
- [ ] 设置关闭时，复制的图片是原图
- [ ] 设置在 UI 中可配置
- [ ] 设置跨重启持久化
- [ ] 默认值为 true

## Out of Scope

- 保存到文件时使用增强图片（当前只影响复制）
- 拖拽图片时使用增强图片
