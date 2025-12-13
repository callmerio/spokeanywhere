# Quick Ask Workflow 功能设计文档

> **版本**: v0.1 (设计阶段)  
> **创建日期**: 2025-12-12  
> **状态**: 📝 设计中

---

## 1. 概述

### 1.1 功能目标

在 Quick Ask 界面（Option+T 触发）中，按下 `/` 键可触发 Workflow 选择器，让用户快速选择预设的工作流来处理输入内容。

### 1.2 核心价值

```
┌──────────────────────────────────────────────────────────────┐
│  传统流程                                                      │
│  输入问题 → 手动描述需求 → 指定格式 → 等待回答                    │
│                                                               │
│  Workflow 流程                                                 │
│  输入问题 → 按 / 选择 Workflow → 自动组装 Prompt → 精准回答       │
└──────────────────────────────────────────────────────────────┘
```

| 场景     | 传统方式                       | Workflow 方式                      |
| -------- | ------------------------------ | ---------------------------------- |
| 翻译     | "请把这段翻译成中文..."        | `/translate` → 自动翻译            |
| 生图     | "生成一张图片..." + 手选模型   | `/image` → 自动使用生图模型        |
| 深度分析 | "请深入分析..." + 期望模型更强 | `/deep` → 自动使用高级模型         |
| 代码审查 | "帮我 review 这段代码..."      | `/review` → 专业 Prompt + 合适模型 |

---

## 2. 架构设计

### 2.1 系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      Quick Ask 界面                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  输入框: /trans                                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼ (检测到 / 前缀)                       │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  WorkflowPickerView (弹出选择器)                          │    │
│  │  ┌─────────────────────────────────────────────────┐    │    │
│  │  │ 🌐 translate   翻译成中文                        │    │    │
│  │  │ 🎨 image       AI 生图                          │    │    │
│  │  │ 🧠 deep        深度思考                          │    │    │
│  │  │ ⚡ quick       快速回答                          │    │    │
│  │  │ 📝 review      代码审查                          │    │    │
│  │  └─────────────────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ (选择 Workflow)
┌─────────────────────────────────────────────────────────────────┐
│                    WorkflowConfigService                         │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐     │
│  │ WorkflowAction │  │ WorkflowAction │  │ WorkflowAction │     │
│  │ - id           │  │ - id           │  │ - id           │     │
│  │ - name         │  │ - name         │  │ - name         │     │
│  │ - prompt       │  │ - prompt       │  │ - prompt       │     │
│  │ - modelId      │  │ - modelId      │  │ - modelId      │     │
│  │ - ...          │  │ - ...          │  │ - ...          │     │
│  └────────────────┘  └────────────────┘  └────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ (执行 Workflow)
┌─────────────────────────────────────────────────────────────────┐
│                    WorkflowExecutor                              │
│  1. 解析变量: {{input}}, {{context}}, {{selected}}               │
│  2. 组装最终 Prompt                                              │
│  3. 选择对应模型 (LLMPipeline)                                   │
│  4. 发送请求并返回结果                                            │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 模块职责

| 模块                      | 职责                               |
| ------------------------- | ---------------------------------- |
| **WorkflowAction**        | 数据模型，定义单个 Workflow 的配置 |
| **WorkflowConfigService** | 管理 Workflow 列表的 CRUD 和持久化 |
| **WorkflowPickerView**    | UI 组件，显示 Workflow 选择器      |
| **WorkflowExecutor**      | 执行引擎，处理变量替换和 LLM 调用  |
| **WorkflowSettingsView**  | 设置界面，配置 Workflow            |

---

## 3. 数据模型设计

### 3.1 WorkflowAction

```swift
/// Workflow 动作模型
struct WorkflowAction: Identifiable, Codable, Equatable {
    /// 唯一 ID (builtin.{name} 或 custom.{uuid})
    let id: String

    /// 显示名称 (用于选择器和设置)
    var name: String

    /// 触发关键词 (输入 /keyword 触发)
    var keyword: String

    /// 简短描述
    var description: String

    /// 图标 (SF Symbol)
    var icon: String

    /// 图标颜色 (Hex)
    var iconColorHex: String

    /// Prompt 模板 (支持变量占位符)
    var promptTemplate: String

    /// 是否内置
    var isBuiltin: Bool

    /// 是否启用
    var isEnabled: Bool

    /// 指定的 LLM Profile ID (nil 表示使用默认)
    /// 与现有 ToolbarAction.profileId 保持一致
    var profileId: UUID?

    /// 模型类型提示 (用于自动选择)
    var modelHint: WorkflowModelHint

    /// 注意：联网搜索能力由 Profile 级别的 enableSearchGrounding 控制
    /// 如需联网，请选择启用了搜索增强的 Profile

    /// 是否启用上下文 (截图/OCR)
    var enableContext: Bool

    /// 输出处理方式
    var outputMode: WorkflowOutputMode
}

/// 模型类型提示
enum WorkflowModelHint: String, Codable, CaseIterable {
    case `default`     // 默认对话模型
    case fast          // 快速模型 (低延迟)
    case advanced      // 高级模型 (深度思考)
    case imageGen      // 生图模型
    case code          // 代码专用模型
    case custom        // 自定义指定模型
}

/// 输出处理方式
enum WorkflowOutputMode: String, Codable, CaseIterable {
    case panel         // 显示在 Answer Panel
    case clipboard     // 直接复制到剪贴板
    case replace       // 替换选中文本
    case append        // 追加到输入
}

// outputMode 在不同触发场景下的行为矩阵：
// ┌────────────┬─────────────────────────┬─────────────────────────┐
// │ outputMode │ Quick Ask 触发           │ Selection Toolbar 触发   │
// ├────────────┼─────────────────────────┼─────────────────────────┤
// │ panel      │ 显示 AnswerPanel        │ 显示 AnswerPanel        │
// │ clipboard  │ 复制到剪贴板 + toast     │ 复制到剪贴板 + toast     │
// │ replace    │ ⚠️ 回退到 clipboard      │ 替换选中文本            │
// │ append     │ 追加到 Quick Ask 输入框  │ ⚠️ 回退到 clipboard      │
// └────────────┴─────────────────────────┴─────────────────────────┘

/// Workflow 执行上下文
struct WorkflowContext {
    /// 用户输入（去掉 /keyword 部分）
    let userInput: String
    /// OCR 识别内容（enableContext=true 时）
    let screenContext: String?
    /// 选中文本（从 Selection Toolbar 触发时）
    let selectedText: String?
    /// 语音转写内容
    let voiceTranscription: String?
    /// 剪贴板内容
    let clipboardContent: String?
}
```

### 3.2 变量占位符系统

```
┌──────────────────────────────────────────────────────────────┐
│                    变量占位符                                                 │
├──────────────┬───────────────────────────────────┬──────────────────┤
│ {{input}}    │ 用户输入内容 (除去 /keyword)        │ Quick Ask        │
│ {{context}}  │ 屏幕 OCR 识别文本                 │ enableContext    │
│ {{selected}} │ 用户选中的文本                   │ Selection Toolbar│
│ {{voice}}    │ 语音转写内容                     │ 有语音输入时      │
│ {{clipboard}}│ 剪贴板内容                       │ 始终可用          │
│ {{date}}     │ 当前日期时间                     │ 始终可用          │
│ {{lang}}     │ 系统语言设置                     │ 始终可用          │
└──────────────┴───────────────────────────────────────────────┘
```

### 3.3 Prompt 模板示例

```markdown
## 翻译 Workflow

请将以下内容翻译成中文，保持原文格式和语气：

{{input}}

只输出翻译结果，不要添加解释。

---

## 代码审查 Workflow

你是一个专业的代码审查专家。请审查以下代码：
```

{{input}}

```

## 屏幕上下文（如有）
{{context}}

请从以下角度进行审查：
1. 代码质量和可读性
2. 潜在的 Bug 和安全问题
3. 性能优化建议
4. 最佳实践建议

使用中文回复，格式清晰。

---

## 生图 Workflow
根据以下描述生成图片：

{{input}}

风格要求：现代、简洁、高质量
```

---

## 4. 交互设计

### 4.1 触发流程

```
┌─────────────────────────────────────────────────────────────┐
│                    Workflow 触发流程                          │
└─────────────────────────────────────────────────────────────┘

[Option+T 打开 Quick Ask]
         │
         ▼
┌───────────────────┐
│   输入框获得焦点    │
└───────────────────┘
         │
         │ 用户输入 /
         ▼
┌───────────────────┐      ┌─────────────────────────────┐
│ 检测到 / 前缀      │ ───▶ │ 显示 WorkflowPickerView    │
└───────────────────┘      │ - 过滤匹配的 Workflow       │
         │                 │ - 键盘导航 (↑↓)             │
         │                 │ - Enter 确认 / ESC 取消     │
         │                 └─────────────────────────────┘
         │                              │
         │                              ▼
         │                 ┌─────────────────────────────┐
         │                 │ 选择 Workflow               │
         │                 │ 1. 移除 /keyword 前缀        │
         │                 │ 2. 更新输入框 placeholder    │
         │                 │ 3. 设置当前活跃 Workflow     │
         │                 └─────────────────────────────┘
         │                              │
         ▼                              ▼
┌───────────────────┐      ┌─────────────────────────────┐
│ 继续输入内容       │      │ 输入框显示:                  │
│ (作为 {{input}})  │      │ [📝 review] 请输入代码...    │
└───────────────────┘      └─────────────────────────────┘
         │
         │ Enter 发送
         ▼
┌───────────────────┐
│ WorkflowExecutor  │
│ 1. 变量替换        │
│ 2. 选择模型        │
│ 3. 调用 LLM        │
└───────────────────┘
         │
         ▼
┌───────────────────┐
│ Answer Panel      │
│ 显示结果          │
└───────────────────┘
```

### 4.2 UI 设计

#### 4.2.1 Workflow 选择器 (WorkflowPickerView)

##### 视觉规范

```
┌─────────────────────────────────────────────────────────────────┐
│  ░░░░░░░░░░░░░░░░░░  磨砂玻璃背景  ░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                                                         │    │
│  │  translate  翻译成中文                                   │ ← 选中态
│  │  trans-en  Translate to English                         │    │
│  │  image  生成图片                                         │    │
│  │  deep  深度思考                                          │    │
│  │  quick  快速回答                                         │    │
│  │                                                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  + 创建 Workflow                                        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

##### 样式参数

| 属性         | 值                                                          | 说明                      |
| ------------ | ----------------------------------------------------------- | ------------------------- |
| **背景**     | `VisualEffectView(.hudWindow)` + `Color.black.opacity(0.5)` | 磨砂玻璃 + 深色叠加       |
| **圆角**     | `12px`                                                      | 与 Quick Ask 输入框一致   |
| **阴影**     | `shadow(radius: 20, y: 10)`                                 | 浮层感                    |
| **宽度**     | `与触发入口宽度一致`                                        | 自适应，Quick Ask = 340px |
| **最大高度** | `400px`                                                     | 超出滚动                  |
| **边距**     | `padding: 8px`                                              | 内边距                    |

##### 宽度自适应逻辑

```swift
// WorkflowPickerView.swift
struct WorkflowPickerView: View {
    let containerWidth: CGFloat  // 从父组件传入
    let workflows: [WorkflowAction]
    let searchQuery: String
    @Binding var selectedIndex: Int

    var body: some View {
        VStack(spacing: 0) {
            // 分组标题（如有）
            if !searchQuery.isEmpty {
                groupHeader("Workflows")
            }

            // 选项列表
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredWorkflows.indices, id: \.self) { index in
                        WorkflowOptionRow(
                            workflow: filteredWorkflows[index],
                            isSelected: index == selectedIndex,
                            searchQuery: searchQuery
                        )
                        .onTapGesture { selectedIndex = index }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 400)

            // 创建新 Workflow 入口
            createWorkflowRow
        }
        .frame(width: containerWidth)  // 🔑 关键：继承父组件宽度
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.5)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}
```

**宽度继承规则**：

| 触发入口            | 宽度              | 说明     |
| ------------------- | ----------------- | -------- |
| Quick Ask HUD       | `340px`           | 固定宽度 |
| Answer Panel 输入框 | `面板宽度 - 32px` | 动态计算 |
| Selection Toolbar   | `300px`           | 最小宽度 |

##### 选项行布局 (WorkflowOptionRow)

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  translate  翻译成中文                                           │
│  image  生成图片                                                 │
│  deep  深度思考                                                  │
│  review  代码审查                                                │
│                                                                  │
│  ├─ keyword ─┤  ├─ description ─┤                               │
│   14px/medium    12px/0.5 opacity                               │
│   白色           灰色                                            │
│                                                                  │
│  keyword 与 description 之间空两格                               │
└─────────────────────────────────────────────────────────────────┘

高度: 36px (单行紧凑)
行内布局: HStack { keyword + "  " + description }
```

**布局代码**：

```swift
// WorkflowOptionRow.swift
struct WorkflowOptionRow: View {
    let workflow: WorkflowAction
    let isSelected: Bool
    let searchQuery: String  // 用于高亮匹配文字

    private enum Layout {
        static let height: CGFloat = 36
        static let padding = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        static let cornerRadius: CGFloat = 6
    }

    private enum Styles {
        static let keywordFont: Font = .system(size: 14, weight: .medium)
        static let keywordColor: Color = .white
        static let descFont: Font = .system(size: 12)
        static let descColor: Color = .white.opacity(0.5)
        static let hoverBg: Color = .white.opacity(0.08)
        static let selectedBg: Color = .white.opacity(0.12)
    }

    var body: some View {
        HStack(spacing: 0) {
            // keyword + 两格空格 + description
            highlightedText(workflow.keyword, query: searchQuery)
                .font(Styles.keywordFont)
                .foregroundStyle(Styles.keywordColor)

            Text("  ")  // 两格空格

            Text(workflow.description.prefix(250))
                .font(Styles.descFont)
                .foregroundStyle(Styles.descColor)
                .lineLimit(1)

            Spacer()
        }
        .padding(Layout.padding)
        .frame(height: Layout.height)
        .background(isSelected ? Styles.selectedBg : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
    }
}
```

##### 动态搜索过滤

```
用户输入: /work

┌─────────────────────────────────────────────────────────────────┐
│  Workflows                                                →      │
│  ─────────────────────────────────────────────────────────      │
│  **work**flow-plan  创建工作计划和任务分解                       │
│  ─────────────────────────────────────────────────────────      │
│  + 创建 "work" Workflow                                         │
└─────────────────────────────────────────────────────────────────┘

匹配规则:
1. keyword 前缀匹配 (优先)
2. name 包含匹配
3. description 包含匹配
4. 匹配文字高亮显示 (加粗)
```

##### 分组结构

```
┌─────────────────────────────────────────────────────────────────┐
│  最近使用                                                        │
│  ─────────────────────────────────────────────────────────      │
│  translate  翻译成中文                                           │
│  review  代码审查                                                │
│                                                                  │
│  内置                                                            │
│  ─────────────────────────────────────────────────────────      │
│  translate  翻译成中文                                           │
│  image  生成图片                                                 │
│  deep  深度思考                                                  │
│  quick  快速回答                                                 │
│  ...                                                             │
│                                                                  │
│  自定义                                                          │
│  ─────────────────────────────────────────────────────────      │
│  email  写邮件                                                   │
│  ─────────────────────────────────────────────────────────      │
│  + 创建新 Workflow                                               │
└─────────────────────────────────────────────────────────────────┘
```

##### 键盘交互

| 按键      | 行为                                                         |
| --------- | ------------------------------------------------------------ |
| `↑` / `↓` | 上下移动选中项                                               |
| `Enter`   | 确认选择当前项                                               |
| `Tab`     | 选择并跳转到输入继续                                         |
| `ESC`     | 第一次：关闭 Picker，保留 `/xxx` 文本；第二次：清除 `/` 前缀 |
| 继续输入  | 实时过滤列表                                                 |

**设计要点**：

- **磨砂背景**: `VisualEffectView(.hudWindow)` + 深色叠加，与 HUD 风格统一
- **实时过滤**: 输入 `/trans` 只显示匹配的 Workflow，匹配部分高亮
- **键盘导航**: ↑↓ 选择，Enter 确认，ESC 取消
- **分组显示**: 最近使用 → 内置 → 自定义
- **宽度自适应**: 选择器宽度 = 触发入口宽度

##### 弹出位置与动画

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  Quick Ask 输入框 (Option+T)                                     │
│  ┌────────────────────────────────────────┐                     │
│  │  /trans_                               │  width = 340px      │
│  └────────────────────────────────────────┘                     │
│           │                                                      │
│           │ 向上弹出 (offset: -8px)                              │
│           ▼                                                      │
│  ┌────────────────────────────────────────┐                     │
│  │  WorkflowPickerView                    │  width = 340px      │
│  │  (与输入框等宽，左对齐)                  │  (继承父组件宽度)    │
│  └────────────────────────────────────────┘                     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**弹出规则**：

| 场景                | 弹出方向 | 说明                    |
| ------------------- | -------- | ----------------------- |
| Quick Ask (底部)    | 向上弹出 | Picker 显示在输入框上方 |
| Answer Panel (中间) | 向下弹出 | Picker 显示在输入框下方 |
| 屏幕边缘            | 自动翻转 | 空间不足时翻转方向      |

**动画参数**：

```swift
// 弹出动画
withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
    isPickerVisible = true
}

// 消失动画
withAnimation(.easeOut(duration: 0.15)) {
    isPickerVisible = false
}

// 选项 hover 动画
.animation(.easeInOut(duration: 0.1), value: isHovered)
```

##### 空状态处理

```
输入: /xyz (无匹配)

┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  😅 没有找到匹配的 Workflow                                       │
│                                                                  │
│  ─────────────────────────────────────────────────────────      │
│  + 创建 "xyz" Workflow                                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 4.2.2 激活状态显示

```
┌────────────────────────────────────────────────────────────┐
│  [📝 代码审查]  请输入要审查的代码...                         │
│  ___________________________________________________________│
│                                                             │
│                                                             │
├────────────────────────────────────────────────────────────┤
│  [W]  ▁▁▂▃▅▂▁▃▅▂▁▁▁    🎙️ SpokenAnyWhere                   │
└────────────────────────────────────────────────────────────┘
```

**设计要点**：

- 输入框左上角显示当前 Workflow 标签
- 点击标签可重新选择或取消
- Placeholder 更新为 Workflow 的提示文案

---

## 5. 设置界面设计

### 5.1 Workflow 设置入口

在 Settings → AI 处理 / 新增 "Workflow" Tab：

```
┌────────────────────────────────────────────────────────────┐
│  设置                                                       │
├────────────────────────────────────────────────────────────┤
│  常规  │  听写模型  │  AI 处理  │  Workflow  │  关于        │
│                              ↑ 高亮
└────────────────────────────────────────────────────────────┘
```

### 5.2 Workflow 管理界面

```
┌────────────────────────────────────────────────────────────┐
│  Workflow 配置                                              │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  内置 Workflow                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ☑️ 🌐 translate   翻译成中文          [编辑] [重置] │    │
│  │ ☑️ 🎨 image       AI 生图             [编辑] [重置] │    │
│  │ ☑️ 🧠 deep        深度思考            [编辑] [重置] │    │
│  │ ☑️ ⚡ quick       快速回答            [编辑] [重置] │    │
│  │ ☑️ 📝 review      代码审查            [编辑] [重置] │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  自定义 Workflow                                            │
│  ┌────────────────────────────────────────────────────┐    │
│  │ ☑️ 🔧 fix-grammar  语法修正        [编辑] [删除]    │    │
│  │ ☑️ 📧 email       写邮件           [编辑] [删除]    │    │
│  └────────────────────────────────────────────────────┘    │
│                                                             │
│  [+ 添加 Workflow]                                          │
│                                                             │
└────────────────────────────────────────────────────────────┘
```

### 5.3 Workflow 编辑界面

````
┌────────────────────────────────────────────────────────────┐
│  编辑 Workflow: 代码审查                                     │
├────────────────────────────────────────────────────────────┤
│                                                             │
│  基本信息                                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 名称:     [代码审查                              ]   │  │
│  │ 关键词:   [review                                ]   │  │
│  │ 描述:     [专业的代码审查，发现潜在问题            ]   │  │
│  │ 图标:     [📝] ▼   颜色: [🟢] ▼                      │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  Prompt 模板                                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 你是一个专业的代码审查专家。请审查以下代码：          │  │
│  │                                                       │  │
│  │ ```                                                   │  │
│  │ {{input}}                                             │  │
│  │ ```                                                   │  │
│  │                                                       │  │
│  │ ## 上下文                                              │  │
│  │ {{context}}                                           │  │
│  │ ...                                                   │  │
│  └──────────────────────────────────────────────────────┘  │
│  💡 可用变量: {{input}} {{context}} {{selected}} {{voice}}   │
│                                                             │
│  模型设置                                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 模型类型:  ( ) 默认  ( ) 快速  (•) 高级  ( ) 生图     │  │
│  │ 指定模型:  [自动选择                            ] ▼  │  │
│  │ ☑️ 启用联网搜索                                       │  │
│  │ ☑️ 启用屏幕上下文                                     │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│  输出设置                                                    │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ 输出方式:  (•) Answer Panel  ( ) 复制到剪贴板         │  │
│  │            ( ) 替换选中文本  ( ) 追加到输入           │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
│                            [取消]  [保存]                    │
└────────────────────────────────────────────────────────────┘
````

---

## 6. 技术实现

### 6.1 文件结构

```
spoke/
├── Core/
│   └── Workflow/
│       ├── WorkflowAction.swift          # 数据模型
│       ├── WorkflowDefaults.swift        # 内置 Workflow 定义
│       └── WorkflowExecutor.swift        # 执行引擎
├── Services/
│   └── WorkflowConfigService.swift       # 配置管理服务
└── UI/
    ├── QuickAsk/
    │   └── WorkflowPickerView.swift      # 选择器 UI
    └── Settings/
        └── WorkflowSettingsView.swift    # 设置界面
```

### 6.2 核心实现要点

#### 6.2.1 `/` 触发检测

```swift
// QuickAskInputView 中添加
func textDidChange(_ notification: Notification) {
    guard let textView = notification.object as? NSTextView else { return }
    let text = textView.string

    // 输入法组合状态时不触发（避免中文拼音干扰）
    guard !textView.hasMarkedText() else { return }

    // 检测 / 前缀触发 Workflow 选择器
    if text.hasPrefix("/") {
        let keyword = String(text.dropFirst())
        showWorkflowPicker(filter: keyword)
    } else {
        hideWorkflowPicker()
    }
}
```

#### 6.2.2 变量替换

```swift
// WorkflowExecutor
func buildPrompt(workflow: WorkflowAction, context: WorkflowContext) -> String {
    var prompt = workflow.promptTemplate

    // 白名单精确替换（不使用泛 regex，避免误伤用户输入中的 {{xxx}} 文本）
    let replacements: [(String, String?)] = [
        ("{{input}}", context.userInput),
        ("{{context}}", context.screenContext),
        ("{{selected}}", context.selectedText),
        ("{{voice}}", context.voiceTranscription),
        ("{{clipboard}}", context.clipboardContent),
        ("{{date}}", Date().formatted()),
        ("{{lang}}", Locale.current.identifier)
    ]

    for (placeholder, value) in replacements {
        prompt = prompt.replacingOccurrences(of: placeholder, with: value ?? "")
    }

    // 注意：不再使用泛 regex 清理，未匹配的占位符保留原样
    // 这样用户输入中包含的 {{xxx}} 不会被意外删除

    return prompt.trimmingCharacters(in: .whitespacesAndNewlines)
}
```

> **与现有架构对齐**：复用 `ToolbarActionPlaceholder` 的设计模式，白名单精确替换。

#### 6.2.3 模型选择逻辑

```swift
// WorkflowExecutor
// 复用现有 LLMSettings + ProviderProfile 体系
func selectProfile(for workflow: WorkflowAction) -> ProviderProfile? {
    let settings = LLMSettings.shared

    // 1. 优先使用指定 Profile
    if let profileId = workflow.profileId {
        return settings.profiles.first { $0.id == profileId }
    }

    // 2. 根据 modelHint 选择角色 Profile
    switch workflow.modelHint {
    case .fast:
        // 使用 chat 角色的 Profile（通常是快速模型）
        if let id = settings.chatProfileId {
            return settings.profiles.first { $0.id == id }
        }
    case .advanced:
        // 使用 summary 角色的 Profile（通常是高级模型）
        if let id = settings.summaryProfileId {
            return settings.profiles.first { $0.id == id }
        }
    case .imageGen, .code:
        // 需要用户显式指定 profileId
        return nil
    default:
        break
    }

    // 3. 回退到默认选中的 Profile
    if let id = settings.selectedProfileId {
        return settings.profiles.first { $0.id == id }
    }
    return settings.profiles.first
}

// 调用方必须处理 nil 情况
func executeWorkflow(_ workflow: WorkflowAction, context: WorkflowContext) async {
    guard let profile = selectProfile(for: workflow) else {
        // 明确的失败处理：弹 toast 引导用户配置
        await showError("请先在设置中配置\(workflow.modelHint.displayName)专用 Profile")
        return
    }
    // 继续执行...
}
```

> **与现有架构对齐**：复用 `LLMSettings.shared` 的 Profile 系统，不引入新的 Provider 管理器。
> **失败处理**：当 `selectProfile()` 返回 nil 时，必须弹出明确的错误提示引导用户配置。

---

## 7. 与现有功能的关系

### 7.1 与 ToolbarAction 的关系

```
┌───────────────────────────────────────────────────────────────┐
│                     共享 vs 独立                               │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ToolbarAction (选中文本触发)     WorkflowAction (Quick Ask)  │
│  ┌─────────────────────┐         ┌─────────────────────┐     │
│  │ - 处理选中文本       │         │ - 处理输入内容       │     │
│  │ - {{selected}} 变量  │         │ - {{input}} 变量    │     │
│  │ - 工具栏 UI          │         │ - /keyword 触发     │     │
│  └─────────────────────┘         └─────────────────────┘     │
│           │                               │                   │
│           └───────────┬───────────────────┘                   │
│                       ▼                                       │
│              ┌─────────────────┐                             │
│              │ 共享配置能力     │                             │
│              │ - Prompt 模板   │                             │
│              │ - 模型选择      │                             │
│              │ - 联网搜索      │                             │
│              │ - 持久化机制    │                             │
│              └─────────────────┘                             │
└───────────────────────────────────────────────────────────────┘
```

**设计决策**：WorkflowAction 独立于 ToolbarAction，但复用相同的配置模式和 UI 组件。

### 7.2 兼容性

- **Selection Toolbar**: 可选择将某个 Workflow 添加到 Selection Toolbar
- **历史记录**: Workflow 执行结果保存到现有 SessionHistoryService
- **LLM Pipeline**: 复用现有的 LLMPipeline 进行实际调用

### 7.3 Prompt 结构说明

```
┌───────────────────────────────────────────────────────────────┐
│                    LLMPrompt 结构                          │
├───────────────────────────────────────────────────────────────┤
│  systemPrompt   │  来自 LLMSettings.systemPrompt           │
│                 │  （全局设置，Workflow 不覆盖）             │
├─────────────────┼─────────────────────────────────────────────┤
│  userMessage    │  WorkflowTemplate 替换变量后的结果        │
│                 │  （与 ToolbarAction 保持一致）              │
└─────────────────┴─────────────────────────────────────────────┘
```

> **设计决策**：WorkflowTemplate 作为 `userMessage` 发送，与现有 ToolbarAction 的处理方式一致。
> 如果未来需要自定义 systemPrompt，可作为 Phase 2 高级功能扩展。

---

## 8. 内置 Workflow 列表

| Keyword     | 名称     | 模型类型 | 描述             | 备注                     |
| ----------- | -------- | -------- | ---------------- | ------------------------ |
| `translate` | 翻译     | 默认     | 翻译成中文       | -                        |
| `trans-en`  | 英文翻译 | 默认     | 翻译成英文       | -                        |
| `image`     | AI 生图  | 生图     | 根据描述生成图片 | 需指定支持生图的 Profile |
| `deep`      | 深度思考 | 高级     | 深入分析和推理   | 建议启用 enableThinking  |
| `quick`     | 快速回答 | 快速     | 低延迟快速响应   | -                        |
| `review`    | 代码审查 | 代码     | 专业代码 Review  | 需指定代码专用 Profile   |
| `explain`   | 代码解释 | 代码     | 解释代码逻辑     | 需指定代码专用 Profile   |
| `summarize` | 总结     | 默认     | 内容摘要提取     | -                        |
| `rewrite`   | 改写     | 默认     | 润色和改写文本   | -                        |
| `fix`       | 语法修正 | 默认     | 修正语法错误     | -                        |

> **联网搜索说明**：如需启用联网搜索，请选择已启用 `enableSearchGrounding` 的 Profile。
> 联网能力由 Profile 级别控制，而非 Workflow 级别。

---

## 9. 实现计划

### Phase 1: MVP (预计 2-3 天)

- [ ] `WorkflowAction` 数据模型
- [ ] `WorkflowConfigService` 配置服务
- [ ] 内置 Workflow 定义 (5 个)
- [ ] `/` 触发检测
- [ ] `WorkflowPickerView` 基础 UI
- [ ] 变量替换实现
- [ ] 集成 LLMPipeline

### Phase 2: 设置界面 (预计 1-2 天)

- [ ] `WorkflowSettingsView` 列表页
- [ ] Workflow 编辑弹窗
- [ ] 自定义 Workflow 增删改
- [ ] 模型选择 UI

### Phase 3: 增强 (预计 1 天)

- [ ] 键盘导航优化
- [ ] 最近使用排序
- [ ] 与 Selection Toolbar 集成
- [ ] 导入/导出 Workflow

---

## 10. 开放问题

1. **Workflow 共享**: 是否支持导出/导入 Workflow 配置？
2. **组合 Prompt**: 是否支持 Workflow 嵌套（一个 Workflow 调用另一个）？
3. **快捷键**: 是否为常用 Workflow 分配独立快捷键？
4. **历史**: Workflow 执行历史是否单独展示？

---

## 附录: 参考设计

### A. 触发选择器

参考 Windsurf/Cursor 的 Slash Command 交互：

- 输入 `/` 立即弹出
- 继续输入进行过滤
- ↑↓ 导航，Enter 选择

### B. Prompt 变量

参考 Raycast AI 的变量系统：

- `{selection}` - 选中文本
- `{clipboard}` - 剪贴板
- `{browser-tab}` - 浏览器标签页
