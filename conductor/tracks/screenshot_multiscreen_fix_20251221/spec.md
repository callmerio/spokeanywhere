# Spec: Multi-Screen Screenshot Bugs Fix

**Track ID**: screenshot_multiscreen_fix_20251221  
**Type**: Bug Fix  
**Priority**: P1

## Overview

修复多屏幕环境下的两个截图问题：
1. 截图错位 - 选区位置与实际截图不匹配
2. 下方屏幕变模糊 - 非主屏幕截图分辨率丢失

## Bug Analysis

### Bug 1: 截图错位

**症状**: 用户在图三位置截取，实际获得的图片位置错误

**根因**: `RegionSelectionView.getAnnotatedImage()` 中的坐标计算问题
- 使用 `window?.backingScaleFactor` 作为 scale
- 但 CGImage 的实际像素尺寸可能与此不一致
- Y 坐标翻转计算: `(bounds.height - selectionRect.maxY) * scale` 可能有误

**相关代码**: `@/spoke/UI/Screenshot/RegionSelectionView.swift:199-223`

### Bug 2: 下方屏幕变模糊

**症状**: 上下分屏时，上方屏幕截图清晰，下方屏幕截图模糊

**根因**: `ScreenCaptureService.captureScreen()` 中 NSImage 创建问题
- `scDisplay.width/height` 是像素尺寸
- `screen.frame.size` 是点尺寸
- `NSImage(cgImage:, size:)` 用点尺寸创建导致像素密度信息丢失

**相关代码**: `@/spoke/Core/Attachment/ScreenCaptureService.swift:39-62`

## Requirements

### R1: 修复截图坐标计算
- 使用 CGImage 的实际像素尺寸计算 scale
- 正确处理不同屏幕的 backingScaleFactor

### R2: 修复 NSImage 创建
- 保留 CGImage 的原始像素尺寸信息
- 或者根据屏幕 backingScaleFactor 计算正确的点尺寸

### R3: 多屏幕兼容性
- 支持不同分辨率/DPI 的多屏幕配置
- 上下/左右分屏都应正确工作

## Acceptance Criteria

- [ ] 截图位置与选区位置一致（无错位）
- [ ] 所有屏幕截图清晰度一致（无模糊）
- [ ] 不同屏幕配置都能正常工作

## Out of Scope

- AI 增强功能（已在另一个 Track 处理）
- 截图标注功能
