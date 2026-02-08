# Research Summary: Quick Ask 交互优化

## 📁 Code Context (5 items)

1. `QuickAskService.swift:191` - **核心问题**: `question: state.userInput.isEmpty ? state.voiceTranscription : state.userInput` 导致语音被覆盖
2. `MarkdownWebView.swift:5-10` - `NonScrollableWebView` 重写 `scrollWheel` 阻止了 WebView 内部滚动
3. `MarkdownWebView.swift:70-155` - HTML 模板缺少 `user-select: text` CSS 规则
4. `MessageBubbleView.swift:170-183` - 已有复制按钮实现，但 WebView 内容不可选
5. `QuickAskState.swift:106-109` - `updateVoiceTranscription` 是覆盖模式而非追加模式

## 📜 Memory Context

- `memory.csv:30` - MarkdownWebView 使用 WKWebView 渲染 Markdown
- `memory.csv:49-50` - 历史修复：Highlight.js 样式、LaTeX 支持

## 🌐 External Research (12 items) 🔴

### WKWebView 文本选择
1. **WKPreferences.isTextInteractionEnabled** (Apple Docs) - macOS 11.3+ 默认 `true`，控制文本交互
2. **CSS user-select** (MDN) - 使用 `-webkit-user-select: text; user-select: text;` 启用选择
3. **WKUserScript 注入 CSS** (StackOverflow) - 可通过 WKUserContentController 注入自定义 CSS
4. **macOS Sonoma 选择问题** (StackOverflow) - Mac Catalyst 应用中 WKWebView 选择可能失效

### 滚动与选择拖拽
5. **WKWebView autoscroll during selection** (StackOverflow) - WKWebView 默认支持选择时自动滚动
6. **NonScrollableWebView 问题** (分析) - 重写 `scrollWheel` 会阻止选择拖拽滚动
7. **scrollView.isScrollEnabled** (Apple) - 控制 WKWebView 内部 scrollView 滚动

### 复制操作
8. **navigator.clipboard API** (MDN) - 现代剪贴板 API，需用户手势触发
9. **document.execCommand('copy')** (Apple WebKit) - 传统方式，需用户交互
10. **WKScriptMessageHandler** (Apple) - Swift 与 JS 通信，可实现复制功能

### 语音追加模式
11. **Voice input append to text** (Apple) - macOS/iOS 原生 dictation 支持追加到光标位置
12. **Multimodal UX best practices** (Medium) - 语音+文本应支持"追加模式"，允许无缝切换

## 💡 Key Takeaways

### 问题 1: 内容不可复制

**根因**:
- `MarkdownWebView` 的 HTML 模板中没有显式设置 `user-select: text`
- `NonScrollableWebView` 可能干扰了选择行为

**解决方案**:
1. 在 HTML `<style>` 中添加 `body { -webkit-user-select: text; user-select: text; }`
2. 添加 CSS 支持选择样式 `::selection { background: rgba(74, 158, 255, 0.3); }`
3. 确保 WKPreferences 没有禁用 `isTextInteractionEnabled`

### 问题 2: 选中拖动无法滚动

**根因**:
- `NonScrollableWebView` 重写了 `scrollWheel` 将事件传给父视图
- 这导致 WebView 内部选择拖拽时无法触发自动滚动

**解决方案**:
1. 移除 `NonScrollableWebView`，使用标准 `WKWebView`
2. 让 **外层 SwiftUI ScrollView** 控制滚动，而 WebView 负责选择
3. 或：检测选择状态，临时启用 WebView 内部滚动

### 问题 3: 语音与文本冲突

**根因**:
- `QuickAskService.swift:191` 使用三元运算符，文本非空时语音被忽略
- 这是"覆盖模式"而非"追加模式"

**解决方案**:
1. 修改 `buildPromptResult` 逻辑，将语音和文本 **都** 发送给 LLM
2. 在输入框中显示时，语音追加到文本末尾
3. 视觉区分：语音部分可用斜体或不同颜色标记
