# Brainstorm Synthesis - Raycast 风格查词功能

## Aligned Decisions ✅

### 1. 核心功能一致
- **输入搜索** + **列表展示** + **详情视图**
- **键盘优先**: ↑↓ 导航、Enter 详情、Tab 标记生词
- **复用现有服务**: DictionaryAPIService + VocabularyService

### 2. 技术方案一致
- **独立面板** (NSPanel) 而非嵌入 Quick Ask
- **SwiftUI** 构建 UI，保持项目一致性
- **防抖搜索** (300ms) 避免 API 压力

### 3. MVP 范围一致
- P0 聚焦核心：搜索 + 列表 + 生词标记 + 基础详情
- 词形变化作为 P1（依赖后端支持）

## Conflicts Identified ⚠️

### Conflict 1: 入口快捷键
- **PM**: 希望无缝集成，建议复用 ⌥⌥ + `/define` 命令
- **Architect**: 推荐独立快捷键（如 ⌥+D）避免 Quick Ask 功能膨胀

**Resolution**: 
- **MVP**: 独立快捷键 ⌥+D（或用户可配置）
- **后续**: 可在 Quick Ask 中添加 `/define` alias

### Conflict 2: 词形变化数据源
- **PM**: 用户期望看到词族列表（如 Raycast）
- **Architect**: 需要后端 API 支持，否则无法实现

**Resolution**:
- **MVP**: 无词形变化，仅显示精确匹配结果
- **P1**: 后端新增 `/api/dictionary/en/:word/related` 接口
- **降级**: 无词形数据时显示"仅找到精确匹配"

## Unified Proposal 📋

### Phase 1: MVP (3天)

```
Day 1: 基础架构
├── DictionaryPanelWindow (NSPanel 窗口)
├── DictionaryPanelView (主视图)
├── DictionaryPanelState (状态管理)
└── 快捷键注册 (⌥+D)

Day 2: 核心交互
├── SearchBar (输入 + 防抖)
├── ResultListView (列表 + 键盘导航)
├── WordResultRow (单词行 + 生词高亮)
└── Tab 标记生词 (VocabularyService)

Day 3: 详情视图
├── WordDetailView (详细释义)
├── Enter 进入/ESC 返回导航
└── 底部 ActionBar
```

### Phase 2: 增强 (2天)
- 词形变化列表（需后端支持）
- 搜索历史
- TTS 发音

### 文件结构

```
spoke/
├── UI/
│   └── Dictionary/                    # 新建目录
│       ├── DictionaryPanelWindow.swift
│       ├── DictionaryPanelView.swift
│       ├── DictionaryPanelState.swift
│       ├── WordResultRow.swift
│       └── WordDetailView.swift
└── Services/
    └── DictionaryAPIService.swift     # 复用
```

### 关键 UI 规格

| 元素 | 规格 |
|------|------|
| 窗口尺寸 | 600 x 400 (可调整) |
| 搜索框 | 高度 44px, 圆角 8px |
| 结果行 | 高度 56px |
| 生词高亮 | 橙色 (#FF9500) |
| 选中背景 | 半透明白 (0.1) |
| 毛玻璃 | .ultraThinMaterial |

## User Decision Needed 🤔

1. **快捷键选择**: ⌥+D 可以吗？还是其他组合？
2. **词形变化**: MVP 先不做词形列表，后续补充可以吗？
3. **入口**: 是否需要同时在菜单栏添加"查词"菜单项？
