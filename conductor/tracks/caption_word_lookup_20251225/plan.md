# Plan: 字幕单词点击查词 + 统一查词接口

**Track ID**: `caption_word_lookup_20251225`  
**Type**: Feature  
**Status**: [ ] Pending  
**Estimated**: 4-6h

---

## Phase 1: 统一查词接口 (UnifiedDictionaryService) ✅

### Task 1.1: 创建 UnifiedDictionaryService ✅
- [x] 创建 `Services/UnifiedDictionaryService.swift`
- [x] 定义统一返回类型 `UnifiedDictionaryResult`
  ```swift
  struct UnifiedDictionaryResult {
      let word: String
      let phonetic: String?
      let senses: [UnifiedSense]  // pos + chinese + english
      let source: DataSource  // .local / .remote
  }
  ```
- [x] 实现 `lookup(_ word: String) async -> UnifiedDictionaryResult?`
  - 先查 LocalDictionaryService
  - 如果有结果且包含中文释义，直接返回
  - 否则调用 DictionaryAPIService
  - 合并两个来源的结果

### Task 1.2: 格式转换器 ✅
- [x] 实现 `LocalDictionaryResult` → `UnifiedDictionaryResult` 转换
- [x] 实现 `DictionaryData` → `UnifiedDictionaryResult` 转换
- [x] 统一 `briefDefinition` 格式: `v. 释义1；释义2`


---

## Phase 2: 单词点击交互 (VocabularyTextView) ✅

### Task 2.1: 单词 Hover 检测 ✅
- [x] 添加 `NSTrackingArea` 监听鼠标移动
- [x] 实现 `mouseMoved(with:)` 检测当前 hover 的单词
- [x] 使用 `characterIndex(for:in:)` 获取字符索引
- [x] 使用 `NSString.rangeOfWord(at:)` 确定单词边界

### Task 2.2: Hover 视觉效果 (下划线 + 手型光标) ✅
- [x] 为 hover 单词添加临时样式:
  - `NSAttributedString.Key.underlineStyle` 下划线
  - 蓝色半透明下划线
- [x] 鼠标离开时恢复原样式
- [x] 设置手型光标 (NSCursor.pointingHand)

### Task 2.3: 单词点击事件 ✅
- [x] 重写 `mouseDown(with:)` 记录点击位置和时间
- [x] 重写 `mouseUp(with:)` 检测点击 vs 拖拽
  - 距离 < 5px 且时间 < 300ms → 点击
  - 有选中文本 → 触发选择工具栏
  - 无选中 + 短点击 → 触发单词查词
- [x] 触发 `onWordClicked: (String, CGPoint) -> Void` 回调

---

## Phase 3: 查词弹窗集成 ✅

### Task 3.1: 连接 DictionaryResultManager ✅
- [x] `VocabularyHighlightText` 添加 `onWordClicked` 回调
- [x] `Coordinator` 添加 `onWordClicked` 属性
- [x] 在 `LiveCaptionView` 中处理回调:
  ```swift
  onWordClicked: { word, screenPoint in
      handleWordClicked(word, at: screenPoint)
  }
  ```

### Task 3.2: 更新 DictionaryResultManager ✅
- [x] 添加 `showResult(_ result: UnifiedDictionaryResult, at: CGPoint)` 方法
- [x] 转换 `UnifiedDictionaryResult` → `DictionaryData` 复用现有 UI

---

## Phase 4: Verification

- [ ] Task 4.1: 测试本地词典有结果的单词 (如 "hello")
- [ ] Task 4.2: 测试本地词典无结果但后端有的单词 (如 "sustains")
- [ ] Task 4.3: 测试后端不可用时的 fallback
- [ ] Task 4.4: 测试 hover 动画效果
- [ ] Task 4.5: 测试选择文本时不触发查词

---

## Key Algorithm

```
点击单词流程:
1. mouseDown 记录位置 + 启动 200ms 定时器
2. mouseUp:
   - 如果有拖动 (累计距离 > 5px): 执行选择逻辑
   - 如果无拖动: 执行单词点击逻辑
3. 单词点击:
   a. characterIndex(for: position)
   b. 找到单词边界
   c. 调用 UnifiedDictionaryService.lookup(word)
   d. 显示 DictionaryResultView
```

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `Services/UnifiedDictionaryService.swift` | Create | 聚合层 |
| `UI/LiveCaption/VocabularyHighlightText.swift` | Modify | 添加 hover/click 检测 |
| `UI/LiveCaption/LiveCaptionView.swift` | Modify | 集成 onWordClicked |
| `Services/DictionaryResultManager.swift` | Modify | 支持新数据类型 |

---

## Rollback Plan

```bash
git checkout -- spoke/Services/UnifiedDictionaryService.swift
git checkout -- spoke/UI/LiveCaption/VocabularyHighlightText.swift
git checkout -- spoke/UI/LiveCaption/LiveCaptionView.swift
```
