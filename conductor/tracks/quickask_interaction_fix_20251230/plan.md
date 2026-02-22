# Plan: Quick Ask 交互优化

## Track Info

- **ID**: `quickask_interaction_fix_20251230`
- **Type**: Bug/Chore (轻量级)
- **Created**: 2025-12-30
- **Status**: [x] Done

## Tasks

### Task 1: 启用 MarkdownWebView 文本选择 ✅

**文件**: `spoke/UI/QuickAsk/MarkdownWebView.swift`

**改动**:
1. 在 HTML `<style>` 中添加:
   ```css
   body {
       -webkit-user-select: text;
       user-select: text;
       cursor: text;
   }
   ::selection {
       background: rgba(74, 158, 255, 0.3);
   }
   ```

2. 移除 `NonScrollableWebView` 类，使用标准 `WKWebView`

3. 配置 WebView 允许滚动:
   ```swift
   // 移除 scrollWheel 重写，让 WebView 自行处理滚动
   ```

**验证**:
- [ ] 可选中 AI 回答文字
- [ ] Cmd+C 可复制
- [ ] 选中有蓝色高亮

---

### Task 2: 修复选中拖动滚动 ✅

**文件**: `spoke/UI/QuickAsk/MarkdownWebView.swift`

**改动**:
1. 删除 `NonScrollableWebView` 类定义
2. 将 `NonScrollableWebView` 替换为 `WKWebView`
3. 确保 HTML 中 `overflow-y: auto` 已设置

**验证**:
- [ ] 选中向上拖动可滚动
- [ ] 选中向下拖动可滚动

---

### Task 3: 语音追加文本逻辑 ✅

**文件**: `spoke/Services/QuickAskService.swift`

**改动**:
1. 修改 `sendQuestion()` 中 question 显示逻辑:
   ```swift
   // Before:
   question: state.userInput.isEmpty ? state.voiceTranscription : state.userInput
   
   // After:
   question: [state.userInput, state.voiceTranscription]
       .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
       .joined(separator: " ")
   ```

2. `buildPromptResult()` 已经正确处理，无需修改

**验证**:
- [ ] 文字 + 语音都显示在问题预览
- [ ] LLM 收到两者

---

## Rollback

```bash
git checkout -- spoke/UI/QuickAsk/MarkdownWebView.swift
git checkout -- spoke/Services/QuickAskService.swift
```

## Files Changed

| 文件 | 改动类型 |
|------|----------|
| `UI/QuickAsk/MarkdownWebView.swift` | 修改 (CSS + 移除自定义类) |
| `Services/QuickAskService.swift` | 修改 (question 拼接逻辑) |
