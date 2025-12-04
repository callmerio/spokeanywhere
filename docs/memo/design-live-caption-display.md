# 实时字幕显示优化设计

## 问题分析

根据用户反馈和截图：

1. **样式问题**

   - 字体太小 (15pt)，可见性差
   - 背景对比度不足

2. **显示逻辑问题**

   - 当前折叠态是 `ScrollView` 可滚动，用户希望固定 2 行"滚动窗口"模式
   - 不能往上滑，只显示最新 2 行

3. **分句逻辑问题**
   - 当前按 `segments` 分段，每个 segment 一块
   - 需要按行分句，尽量在 2 行内显示完整 1-2 句

## 设计方案

### 1. UI 优化

| 属性       | 当前值   | 优化值 |
| ---------- | -------- | ------ |
| 原文字体   | 15pt     | 18pt   |
| 译文字体   | 15pt     | 18pt   |
| 行高       | 系统默认 | 1.3    |
| 背景透明度 | 0.4      | 0.6    |
| 内边距     | 16pt     | 20pt   |
| 折叠高度   | 120pt    | 160pt  |

### 2. 滚动窗口模式

**核心思想**：固定显示最新 2 行，不可滚动

```
┌────────────────────────────────────────┐
│  原文第1行 / 原文第2行                  │  <- 最多2行原文
│  译文第1行 / 译文第2行                  │  <- 对应译文
└────────────────────────────────────────┘
```

### 3. 智能分句逻辑

**分句时机**：

1. 遇到句号 `.`、问号 `?`、感叹号 `!`、省略号 `...`
2. 中文标点：`。`、`？`、`！`、`；`

**行填充规则**：

1. 第 1 行为空：填入新句子
2. 第 1 行未满 + 新句子短：拼接到第 1 行
3. 第 1 行满或溢出：等待分句点，然后：
   - 第 1 行 → 丢弃
   - 第 2 行 → 升级为第 1 行
   - 新句子 → 第 2 行
4. 如果第 2 行也满了，直接翻页（清空 → 新句子到第 1 行）

**行宽度计算**：

- 窗口宽度 600pt - padding 40pt = 560pt
- 每字符约 10pt (18pt 字体)
- 每行约 56 字符

### 4. 数据模型

```swift
/// 行缓冲区管理
class CaptionLineBuffer {
    /// 原文行 (最多2行)
    private(set) var originalLines: [String] = []
    /// 译文行 (最多2行)
    private(set) var translatedLines: [String] = []

    /// 当前未完成的句子片段
    private var pendingFragment: String = ""

    /// 追加新文本
    func append(_ text: String, translation: String?)

    /// 检测是否到分句点
    private func detectSentenceBreak(_ text: String) -> Int?

    /// 换行/翻页逻辑
    private func commitLine(_ line: String)
}
```

### 5. 实现步骤

1. 创建 `CaptionLineBuffer` 类管理行状态
2. 修改 `LiveCaptionView.collapsedContent` 使用固定布局
3. 修改 `LiveCaptionManager.handleTranscriptionResult` 使用行缓冲区
4. 优化字体、颜色、间距

## 参考

- Apple Live Captions 样式
- Netflix 字幕规范 (最多 2 行)
