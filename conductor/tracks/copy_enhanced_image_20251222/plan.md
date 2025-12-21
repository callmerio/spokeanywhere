# Plan: 复制优化后图片功能

**Track ID**: `copy_enhanced_image_20251222`  
**Type**: Chore (轻量级)  
**Status**: [x] Completed

---

## Checklist

### Task 1: 添加设置项 ✅
- [x] `ScreenshotSettings.swift` 添加 `copyEnhancedImage` 属性
- [x] UserDefaults 持久化

### Task 2: 修改复制逻辑 ✅
- [x] `ScreenshotContentView` 添加 `getCurrentDisplayImage()` 方法
- [x] `ScreenshotManager.copyToClipboard()` 支持传入增强图片
- [x] 更新调用点传递增强图片

### Task 3: 添加设置 UI ✅
- [x] `ScreenshotSettingsView` 添加 Toggle 开关

### Task 4: 验证
- [ ] 设置开启时复制增强图片
- [ ] 设置关闭时复制原图
- [ ] 设置跨重启持久化

---

## Commit
- `b17447f` feat(screenshot): 复制优化后图片功能
