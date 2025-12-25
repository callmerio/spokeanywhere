# Spec: 字幕单词点击查词 + 统一查词接口

**Track ID**: `caption_word_lookup_20251225`  
**Type**: Feature  
**Priority**: P0 (当前重点)

## Overview

在实时字幕中实现单词点击查词功能，并统一查词接口（本地词典优先，后端 API 兜底）。

### 用户故事

> 作为用户，我希望在看视频时能直接点击字幕中的单词查看释义，而不需要复制粘贴到词典应用。

## Requirements

### R1: 统一查词接口 (UnifiedDictionaryService)

创建聚合层，统一两个数据源的查询结果：

| 优先级 | 数据源 | 描述 |
|--------|--------|------|
| 1 | LocalDictionaryService | 本地 macOS 词典 (DCSCopyTextDefinition)，LRU 缓存 |
| 2 | DictionaryAPIService | 后端 API (/api/dictionary/en/{word})，支持词形还原 |

**输出格式统一**:
```
[词性缩写]. [中文释义1]；[中文释义2]
```

例如: `v. 维持；支撑  n. 支持`

### R2: 字幕单词点击交互

- **触发方式**: 单击单词（非选中文本）
- **视觉反馈**: 
  - Hover 时单词轻微放大 (`scaleEffect(1.05)`) + 阴影 + 下划线
  - 点击时短暂弹性缩放动画
- **弹出窗口**: 复用 `DictionaryResultView` 组件
- **位置**: 单词下方居中

### R3: 优化现有 VocabularyTextView

扩展 `VocabularyTextView` (NSTextView) 支持:
- 单词级别的 hover 检测 (NSTrackingArea + characterIndex)
- 单词点击事件 (区别于文本选择)
- 单词视觉高亮 (hover 时样式变化)

## Technical Design

### 架构图

```
┌────────────────────────────────────────────────────┐
│                 LiveCaptionView                    │
│    ┌──────────────────────────────────────────┐    │
│    │        VocabularyTextView (NSTextView)   │    │
│    │                                          │    │
│    │  [Click word] → UnifiedDictionaryService │    │
│    │                      ↓                   │    │
│    │        ┌─────────────────────────┐       │    │
│    │        │  LocalDictionaryService │───────┼────┼──→ (cached/local)
│    │        │         ↓ (fallback)    │       │    │
│    │        │  DictionaryAPIService   │───────┼────┼──→ (remote)
│    │        └─────────────────────────┘       │    │
│    │                      ↓                   │    │
│    │          DictionaryResultView            │    │
│    │          (NSPanel popover)               │    │
│    └──────────────────────────────────────────┘    │
└────────────────────────────────────────────────────┘
```

### 文件修改

| 文件 | 修改 |
|------|------|
| `Services/UnifiedDictionaryService.swift` | 新建，聚合两个数据源 |
| `UI/LiveCaption/VocabularyHighlightText.swift` | 扩展单词 hover/click 检测 |
| `Services/DictionaryResultManager.swift` | 已有，复用其 show/hide API |

## Acceptance Criteria

- [ ] 点击字幕单词弹出查词结果
- [ ] 查词优先使用本地词典，本地无结果时自动调用后端
- [ ] Hover 单词时有 3D 突出效果
- [ ] 点击已选择文本不触发查词（避免与现有工具栏冲突）
- [ ] 查词结果格式统一为 `词性. 释义`
- [ ] 后端不可用时仅使用本地结果，不报错

## Out of Scope

- 词形还原由后端处理（已实现）
- 查词历史记录
- 自定义词典
