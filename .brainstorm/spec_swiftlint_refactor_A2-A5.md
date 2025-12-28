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

### AC1: 代码质量
- [ ] 所有目标文件 SwiftLint 0 violations (无 disable 注释)
- [ ] swift build 通过
- [ ] 无编译警告

### AC2: 功能保持
- [ ] 词典设置页面 UI 正常显示
- [ ] 实时字幕功能正常（滚动、翻译、高亮）
- [ ] Pipeline 卡片文本选择和右键菜单正常

### AC3: 代码规范
- [ ] 继续使用 DesignTokens
- [ ] 新文件命名符合项目规范
- [ ] 保持现有代码组织风格

## Out of Scope

- 任何 UI 行为变更
- 性能优化（除保持现有优化外）
- 新功能添加
- 测试代码编写（无现有测试覆盖）

## Technical Notes

### 文件拆分策略

#### A2: DictionarySettingsView.swift → 多文件
```
spoke/UI/Settings/Dictionary/
├── DictionarySettingsContent.swift      # 主视图 (精简)
├── DictionaryHeaderSection.swift        # 头部区域
├── DictionaryFilterSection.swift        # 筛选和搜索
├── DictionaryListSection.swift          # 词典列表
├── DictionaryEntryRow.swift             # 词条行组件
├── AddDictionaryEntrySheet.swift        # 新增弹窗
├── EditDictionaryEntrySheet.swift       # 编辑弹窗
├── BatchImportSheet.swift               # 批量导入弹窗
└── VocabularyListSheet.swift            # 生词列表弹窗
```

#### A3: LiveCaptionView.swift → 多文件
```
spoke/UI/LiveCaption/
├── LiveCaptionView.swift                # 主视图 (精简)
├── AppKitScrollView.swift               # NSScrollView 桥接
├── CaptionDesign.swift                  # 设计常量
├── CaptionHoverToolbar.swift            # Hover 工具栏
├── CaptionItemView.swift                # 单条字幕组件 (已存在)
└── LiveCaptionToolbar.swift             # 工具栏 (已存在)
```

#### A4: DictionarySelectableText.swift → 多文件
```
spoke/UI/Components/
├── DictionarySelectableText.swift       # 主组件 (精简)
├── SimpleMarkdownParser.swift           # Markdown 解析器
├── SelectionColorLayoutManager.swift    # 选中颜色管理
├── DictionaryTextView.swift             # 自定义 NSTextView
└── DictionaryTextCoordinator.swift      # Coordinator (可选合并)
```

### 风险控制
- **中风险**: 拆分可能破坏隐式依赖关系
- **缓解**: 每个任务完成后立即验证 build + 功能

### 依赖关系
```
A1 (已完成) ← A2 ← A3 ← A4 ← A5
```
