# Research Summary: 查词接口统一 + 字幕单词点击交互

## 📁 Code Context (6 items)

1. `spoke/Services/LocalDictionaryService.swift` - 本地词典服务，使用 `DCSCopyTextDefinition` API，支持 LRU 缓存(200条)，返回 `LocalDictionaryResult`
2. `spoke/Services/DictionaryAPIService.swift` - 后端 API 服务，调用 `/api/dictionary/en/{word}`，返回 `DictionaryData`，支持词形还原
3. `spoke/UI/LiveCaption/VocabularyHighlightText.swift` - 字幕文本组件（NSTextView），支持生词高亮、右键菜单、选中工具栏
4. `spoke/UI/LiveCaption/LiveCaptionView.swift` - 实时字幕主视图，使用 `AppKitScrollView` + `VocabularyHighlightText`
5. `spoke/Services/SelectionActionService.swift` - 选择工具栏动作服务，已集成 `DictionaryAPIService`
6. `spoke/UI/SelectionToolbar/DictionaryResultView.swift` - 查词结果悬浮窗 UI 组件

## 📜 Memory Context

| Date | Entry | Insight |
|------|-------|---------|
| 2025-12-14 | DictionaryAPIService 完整实现 | 后端服务已完成，支持词形还原 |
| 2025-12-24 | LocalDictionaryService LRU缓存 | 本地词典查询慢需缓存，遍历所有词典找中文释义 |
| 2025-12-24 | VocabularyHighlightText | 支持右键菜单、选中文本工具栏、生词高亮 |
| 2025-12-18 | 实时字幕选中文本工具栏 | mouseUp 触发工具栏，300ms 防抖 |

## 🌐 External Research (12 items)

### 查词接口架构
1. [Local-First Architecture](https://dev.to) - **Key insight**: 本地数据作为 "单一真相来源"，网络作为伴侣而非必须；先查本地缓存 → 本地持久存储 → 在线 API
2. [Cache-Aside Pattern](https://medium.com) - **Key insight**: 缓存未命中时从在线获取，存入缓存后返回；LRU 替换策略适合词典场景
3. [Fallback Mechanism](https://siit.io) - **Key insight**: 主要方法失败时激活备用计划；本地未找到时调用远程 API

### 单词点击交互
4. [SwiftUI hoverEffect](https://swiftwithmajid.com) - **Key insight**: `.lift` 效果可缩放并添加阴影，适合 3D 突出效果；`.onHover` 可自定义动画
5. [rotation3DEffect](https://medium.com) - **Key insight**: 可创建微妙的 3D 效果，结合阴影和偏移量模拟立体感
6. [scaleEffect + withAnimation](https://swift-pal.com) - **Key insight**: 点击时缩放 + 弹性动画是常用交互反馈方式

### NSTextView 文字点击
7. [NSTextView word detection](https://stackoverflow.com) - **Key insight**: `characterIndexForInsertion(at:)` 获取字符索引，`enumerateSubstrings(.byWords)` 找到单词边界
8. [NSTrackingArea for hover](https://stackoverflow.com) - **Key insight**: 添加 `NSTrackingArea` 实现鼠标追踪，检测 hover 位置
9. [AttributedString + highlight](https://apple.com) - **Key insight**: 使用 `NSAttributedString` 为特定单词添加样式/高亮

### SwiftUI Popover
10. [popover(isPresented:)](https://apple.com/documentation) - **Key insight**: `.popover` 修饰符控制弹出窗口，支持 `attachmentAnchor` 和 `arrowEdge` 定位
11. [Detachable Popovers](https://apple.com/design) - **Key insight**: macOS 支持可分离的 Popover，适合需要持续查看的词典场景
12. [onHover delay](https://rampatra.com) - **Key insight**: hover 触发 popover 需要延迟（避免闪烁），建议 200-500ms

## 💡 Key Takeaways

### 架构设计
- **分层策略**: 内存缓存(LRU) → 本地词典(DCS) → 在线 API(后端)
- **统一接口**: 创建 `UnifiedDictionaryService` 聚合两个数据源
- **结果格式**: 统一为 `pos + 释义` 格式，兼容两个来源

### 交互设计
- **单词检测**: 使用 NSTextView + `mouseMoved` 检测 hover 的单词
- **3D 效果**: `scaleEffect(1.05)` + `shadow` + 微弹性动画
- **Popover**: 使用现有 `DictionaryResultView` 组件展示结果
- **触发方式**: 点击而非 hover（避免误触发）

### 技术方案
1. 扩展 `VocabularyTextView` 支持单词点击
2. 创建 `UnifiedDictionaryService` 聚合本地和在线
3. 复用 `DictionaryResultView` 作为弹出窗口
4. 点击单词时的视觉反馈：短暂放大 + 阴影
