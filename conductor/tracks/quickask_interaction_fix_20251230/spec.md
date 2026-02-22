# Spec: Quick Ask 交互优化

## Overview

优化 Quick Ask 面板的交互体验，解决三个核心问题：
1. AI 回答内容无法选中/复制
2. 选中文本向上拖动时视窗无法滚动
3. 语音转写与文本输入冲突（语音被覆盖）

## Requirements

### R1: 内容可选择/复制 (P0)

**现状**: MarkdownWebView 渲染的 AI 回答内容无法被用户选中

**目标**:
- 用户可以用鼠标拖选 AI 回答中的任意文字
- 选中后 Cmd+C 可复制
- 右键菜单可复制
- 保留现有的"一键复制"按钮

**技术方案**:
- 在 `MarkdownWebView` HTML 模板中添加 CSS: `user-select: text`
- 添加选中高亮样式 `::selection`

### R2: 选中拖动可滚动 (P0)

**现状**: 选中文本向上/下拖动时，视窗固定不动

**目标**:
- 选中文本并拖动到边缘时，内容可自动滚动
- 支持向上/向下两个方向

**技术方案**:
- 移除 `NonScrollableWebView` 自定义类
- 使用标准 `WKWebView`
- 通过 CSS `overflow-y: auto` 控制滚动

### R3: 语音追加文本 (P1)

**现状**: 同时有文本和语音输入时，只保留文本，语音消失

**目标**:
- 语音转写追加到文本末尾（而非覆盖）
- 两者都发送给 LLM 处理
- Prompt 中明确区分两种输入来源

**技术方案**:
- 修改 `QuickAskService.buildPromptResult()` 逻辑
- 修改 AnswerPanel 的 question 显示逻辑

## Acceptance Criteria

### AC1: 文本选择
- [ ] 可用鼠标在 AI 回答区域拖选文字
- [ ] Cmd+C 可复制选中内容
- [ ] Cmd+A 可全选回答内容
- [ ] 选中文字有蓝色高亮

### AC2: 滚动选择
- [ ] 选中文字向上拖动时内容向上滚动
- [ ] 选中文字向下拖动时内容向下滚动
- [ ] 滚动速度适中，不会失控

### AC3: 语音追加
- [ ] 输入文字后说话，语音追加到文字后
- [ ] LLM 收到的 prompt 包含两者
- [ ] 发送后问题预览显示完整内容

## Out of Scope

- 语音部分的视觉区分（斜体/颜色）- 可后续优化
- MarkdownWebView 的其他功能增强
- 语音转写准确度问题
