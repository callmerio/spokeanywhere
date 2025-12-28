# Plan: SwiftLint Baseline Convergence A2-A5

> **Track ID**: swiftlint_refactor_A2A5_20251228  
> **类型**: Chore/Refactor (Checklist 模式)  
> **创建时间**: 2025-12-28T17:17:00+08:00

---

## ⚠️ SKILL 关键规则 (来自 .claude/skills/)

### From `build-macos-apps/SKILL.md`:
- **"Prove, Don't Promise"** - 每个改动后运行 `swift build` 验证
- **"Small Steps, Always Verified"** - `Change → Verify → Report → Next change`
- **"Always Leave It Working"** - 每个停止点必须是可工作状态

### From `moai-lang-swift/SKILL.md`:
- 保持现有 `@MainActor`, `Sendable` 标记不变
- 保持 Coordinator 模式结构一致
- 保持 `@Observable` / `@ObservedObject` 用法一致

### From `swiftui-patterns.md`:
- **Declarative overrides Imperative** - SwiftUI 控制层优先于 AppKit
- 拆分时保持 `@Bindable` / `@Environment` 模式不变
- 不破坏现有的状态绑定链路

---

## 任务概览

| 任务 | 目标文件 | 行数 | 状态 |
|------|----------|------|------|
| A2 | DictionarySettingsView.swift | 1537→753 | ✅ 完成 |
| A3 | LiveCaptionView.swift | 1098→714 | ✅ 完成 |
| A4 | DictionarySelectableText.swift | 790→330 | ✅ 完成 |
| A5 | 跨模块验证 | - | ✅ 完成 |

---

## Task A2: DictionarySettingsContent 拆分

### 目标
将 1537 行的 `DictionarySettingsView.swift` 拆分为多个逻辑清晰的小文件。

### 拆分计划

```
spoke/UI/Settings/Dictionary/          # 新建目录
├── DictionarySettingsContent.swift    # 主视图 (~150 行)
├── DictionaryHeaderSection.swift      # 标题+按钮+开关 (~100 行)
├── DictionaryFilterSection.swift      # Tab 筛选+搜索框 (~80 行)
├── DictionaryListSection.swift        # 词条列表 (~100 行)
├── DictionaryEntryRow.swift           # 单个词条行 (~150 行)
├── AddDictionaryEntrySheet.swift      # 新增词条弹窗 (~200 行)
├── EditDictionaryEntrySheet.swift     # 编辑词条弹窗 (~300 行)
├── BatchImportSheet.swift             # 批量导入弹窗 (~150 行)
└── VocabularyListSheet.swift          # 生词列表弹窗 (~200 行)
```

### Checklist
- [ ] 2.1 创建 `spoke/UI/Settings/Dictionary/` 目录
- [ ] 2.2 提取 `DictionaryHeaderSection` (headerSection, dictionarySettingsRow, dictionaryStatusBadge)
- [ ] 2.3 提取 `DictionaryFilterSection` (filterAndSearchSection, filterButton)
- [ ] 2.4 提取 `DictionaryListSection` (词条列表视图)
- [ ] 2.5 提取 `DictionaryEntryRow` (单个词条行组件)
- [ ] 2.6 提取 `AddDictionaryEntrySheet`
- [ ] 2.7 提取 `EditDictionaryEntrySheet` (含 TrainingPhraseCard)
- [ ] 2.8 提取 `BatchImportSheet`
- [ ] 2.9 提取 `VocabularyListSheet` (vocabularyListEntry + sheet)
- [ ] 2.10 精简主文件，移除 `// swiftlint:disable file_length`
- [ ] 2.11 验证: `swiftlint lint spoke/UI/Settings/Dictionary/`
- [ ] 2.12 验证: `cd spoke && swift build`
- [ ] 2.13 验证: UI 功能测试 (词典设置页面)

---

## Task A3: LiveCaptionView 拆分

### 目标
将 1098 行的 `LiveCaptionView.swift` 拆分为多个小文件。

### 拆分计划

```
spoke/UI/LiveCaption/
├── LiveCaptionView.swift              # 主视图 (~300 行)
├── AppKitScrollView.swift             # NSScrollView 桥接 (~300 行) ← 提取
├── CaptionDesign.swift                # 设计常量枚举 (~50 行) ← 提取
├── CaptionHoverToolbar.swift          # Hover 工具栏 (~200 行) ← 提取
├── CaptionItemView.swift              # (已存在)
└── LiveCaptionToolbar.swift           # (已存在)
```

### Checklist
- [ ] 3.1 提取 `AppKitScrollView` 到独立文件 (struct + Coordinator)
- [ ] 3.2 提取 `CaptionDesign` 枚举到独立文件
- [ ] 3.3 提取 `hoverToolbar` 相关视图到 `CaptionHoverToolbar.swift`
- [ ] 3.4 精简主文件 `LiveCaptionView.swift`
- [ ] 3.5 验证: `swiftlint lint spoke/UI/LiveCaption/`
- [ ] 3.6 验证: `cd spoke && swift build`
- [ ] 3.7 验证: UI 功能测试 (实时字幕滚动、翻译、语言切换)

---

## Task A4: DictionarySelectableText 重构

### 目标
将 790 行的 `DictionarySelectableText.swift` 拆分为多个小文件。

### 拆分计划

```
spoke/UI/Components/
├── DictionarySelectableText.swift     # 主组件 (~100 行)
├── SimpleMarkdownParser.swift         # Markdown 解析器 (~120 行) ← 提取
├── SelectionColorLayoutManager.swift  # 选中颜色 LayoutManager (~100 行) ← 提取
├── DictionaryTextView.swift           # 自定义 NSTextView (~400 行) ← 提取
└── (Coordinator 保留在主文件或 TextView 中)
```

### Checklist
- [ ] 4.1 提取 `SimpleMarkdownParser` enum 到独立文件 (保持 fontCache)
- [ ] 4.2 提取 `SelectionColorLayoutManager` class 到独立文件
- [ ] 4.3 提取 `DictionaryTextView` class 到独立文件 (含 Sheet 定义)
- [ ] 4.4 精简主文件 `DictionarySelectableText.swift`
- [ ] 4.5 验证: `swiftlint lint spoke/UI/Components/DictionarySelectableText.swift spoke/UI/Components/SimpleMarkdownParser.swift spoke/UI/Components/SelectionColorLayoutManager.swift spoke/UI/Components/DictionaryTextView.swift`
- [ ] 4.6 验证: `cd spoke && swift build`
- [ ] 4.7 验证: UI 功能测试 (Pipeline 卡片文本选择、右键菜单)

---

## Task A5: 跨模块最终验证

### Checklist
- [ ] 5.1 全量 SwiftLint: `swiftlint lint --config .swiftlint.yml spoke/`
- [ ] 5.2 确认目标文件无 `// swiftlint:disable` 注释
- [ ] 5.3 全量构建: `cd spoke && swift build`
- [ ] 5.4 综合 UI 测试:
  - [ ] 设置 → 词典 Tab 正常
  - [ ] 实时字幕功能正常
  - [ ] Pipeline 卡片交互正常
- [ ] 5.5 更新 Issue CSV 状态

---

## 回滚策略

```bash
# A2 回滚
git checkout -- spoke/UI/Settings/DictionarySettingsView.swift
rm -rf spoke/UI/Settings/Dictionary/

# A3 回滚
git checkout -- spoke/UI/LiveCaption/LiveCaptionView.swift
rm -f spoke/UI/LiveCaption/AppKitScrollView.swift
rm -f spoke/UI/LiveCaption/CaptionDesign.swift
rm -f spoke/UI/LiveCaption/CaptionHoverToolbar.swift

# A4 回滚
git checkout -- spoke/UI/Components/DictionarySelectableText.swift
rm -f spoke/UI/Components/SimpleMarkdownParser.swift
rm -f spoke/UI/Components/SelectionColorLayoutManager.swift
rm -f spoke/UI/Components/DictionaryTextView.swift
```

---

## 文件变更矩阵

| 文件路径 | 操作 | 任务 |
|----------|------|------|
| `spoke/UI/Settings/DictionarySettingsView.swift` | 移动/精简 | A2 |
| `spoke/UI/Settings/Dictionary/*.swift` | 新建 | A2 |
| `spoke/UI/LiveCaption/LiveCaptionView.swift` | 精简 | A3 |
| `spoke/UI/LiveCaption/AppKitScrollView.swift` | 新建 | A3 |
| `spoke/UI/LiveCaption/CaptionDesign.swift` | 新建 | A3 |
| `spoke/UI/LiveCaption/CaptionHoverToolbar.swift` | 新建 | A3 |
| `spoke/UI/Components/DictionarySelectableText.swift` | 精简 | A4 |
| `spoke/UI/Components/SimpleMarkdownParser.swift` | 新建 | A4 |
| `spoke/UI/Components/SelectionColorLayoutManager.swift` | 新建 | A4 |
| `spoke/UI/Components/DictionaryTextView.swift` | 新建 | A4 |
