# Spec: SwiftLint Baseline Convergence A2-A5

## Overview

重构三个大型 SwiftUI 视图文件，拆分为多个小文件，移除 `// swiftlint:disable file_length` 注释，实现 SwiftLint 0 warnings。

**类型**: Chore/Refactor (不改变行为)

## Requirements

### R1: DictionarySettingsContent 拆分 (A2)
- 将 `DictionarySettingsView.swift` (1537 行) 拆分为多个文件
- 移除 `// swiftlint:disable file_length` 注释
- 每个拆分文件符合 SwiftLint 规则

### R2: LiveCaptionView 拆分 (A3)
- 将 `LiveCaptionView.swift` (1098 行) 拆分为多个文件
- 保持 AppKitScrollView 桥接功能完整
- 保持滚动逻辑和翻译更新机制

### R3: DictionarySelectableText 重构 (A4)
- 将 `DictionarySelectableText.swift` (790 行) 拆分为多个文件
- 保持 Markdown 解析、选中高亮、右键菜单功能
- 保持 fontCache 性能优化

### R4: 跨模块最终验证 (A5)
- 验证所有拆分后的文件 SwiftLint 0 warnings
- 验证 swift build 通过
- 验证 UI 功能手工抽检

## Acceptance Criteria

- [ ] 所有目标文件 SwiftLint 0 violations (无 disable 注释)
- [ ] swift build 通过
- [ ] 词典设置页面 UI 正常显示
- [ ] 实时字幕功能正常（滚动、翻译、高亮）
- [ ] Pipeline 卡片文本选择和右键菜单正常
- [ ] 继续使用 DesignTokens，无硬编码样式

## Out of Scope

- 任何 UI 行为变更
- 性能优化（除保持现有优化外）
- 新功能添加
- 测试代码编写

## Technical Notes

### 文件拆分策略

参见 `plan.md` 中的详细拆分计划。

### 风险控制
- 每个任务完成后立即验证 build + 功能
- 保持现有代码风格和 DesignTokens 使用

### 依赖关系
```
A1 (已完成) ← A2 ← A3 ← A4 ← A5
```
