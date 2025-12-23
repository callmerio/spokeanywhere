# System Architect Analysis - Raycast 风格查词功能

## Architecture Overview

### 入口方案对比

| 方案 | 优点 | 缺点 | 推荐度 |
|------|------|------|--------|
| A. Quick Ask 模式 (`/define`) | 复用现有 UI 框架 | Quick Ask 功能边界模糊 | ⭐⭐ |
| B. 独立面板 | 功能清晰、可独立优化 | 需新建窗口管理 | ⭐⭐⭐ |
| C. 设置页内嵌 | 无需新入口 | 使用场景不自然 | ⭐ |

**推荐方案 B**: 独立面板，快捷键触发（如 ⌥+D 或复用 ⌥⌥ 时输入 `/define`）

### 系统架构图

```
┌─────────────────────────────────────────────────────────┐
│                    DictionaryPanel                       │
│  ┌─────────────────────────────────────────────────────┐│
│  │  SearchBar (TextField + debounce)                   ││
│  └─────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────┐│
│  │  ResultListView                                      ││
│  │  ┌─────────────────────────────────────────────────┐││
│  │  │ WordRow (word, pos, brief, isVocabulary?)      │││
│  │  └─────────────────────────────────────────────────┘││
│  └─────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────┐│
│  │  ActionBar (Define | Show Details ↵ | Tab 标记)     ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
         │                         │
         ▼                         ▼
┌─────────────────┐    ┌─────────────────────┐
│ DictionaryAPI   │    │ VocabularyService   │
│ Service         │    │ (生词管理)           │
└─────────────────┘    └─────────────────────┘
```

## Component Design

### 1. DictionaryPanelView (新建)
- **职责**: 查词面板主视图
- **状态**: 
  - `searchText: String`
  - `results: [WordResult]`
  - `selectedIndex: Int`
  - `viewMode: .list | .detail`

### 2. WordResultRow (新建)
- **职责**: 单词结果行
- **显示**: 单词、词性、简短释义、生词标记（橙色）

### 3. WordDetailView (新建/扩展 DictionaryResultView)
- **职责**: 详细释义视图
- **显示**: 同义词、反义词、例句、发音

### 4. DictionaryPanelState (新建)
- **职责**: 面板状态管理
- **功能**: 搜索、导航、生词标记

## Tech Stack

| 层级 | 技术选型 | 说明 |
|------|----------|------|
| UI | SwiftUI + NSPanel | 非激活窗口，保持键盘焦点 |
| 状态管理 | @Observable | Swift 5.9+ |
| 搜索防抖 | Combine debounce | 300ms |
| 词典数据 | DictionaryAPIService | 现有服务 |
| 生词管理 | VocabularyService | 现有服务 |
| 词形变化 | 方案待定 | 见下文 |

### 词形变化方案

| 方案 | 实现 | 优点 | 缺点 |
|------|------|------|------|
| A. 后端 API | 扩展 `/api/dictionary/en/:word/related` | 数据准确 | 依赖后端 |
| B. 本地 Lemmatizer | NLTagger + 规则 | 离线可用 | 覆盖有限 |
| C. macOS Dictionary | DCSCopyTextDefinition | 系统数据 | 需解析 |

**推荐方案 A**: 后端 API 扩展，保持一致性

## Risk Assessment

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| API 延迟 | 中 | 加载态 + 缓存 |
| 词形数据缺失 | 中 | 降级为仅搜索结果 |
| 键盘焦点丢失 | 低 | NSPanel.becomesKeyOnlyIfNeeded |
| 与 Quick Ask 冲突 | 低 | 独立快捷键 |
