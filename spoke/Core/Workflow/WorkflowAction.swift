import Foundation
import SwiftUI

// MARK: - Workflow 动作模型

/// Workflow 动作
/// 用于 Quick Ask 的 /keyword 触发式工作流
struct WorkflowAction: Identifiable, Codable, Equatable {
    /// 唯一 ID (builtin.{name} 或 custom.{uuid})
    let id: String
    /// 显示名称
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
    let isBuiltin: Bool
    /// 是否启用
    var isEnabled: Bool
    /// 指定的 LLM Profile ID (nil 表示使用默认)
    /// 与现有 ToolbarAction.profileId 保持一致
    var profileId: UUID?
    /// 模型类型提示 (用于自动选择)
    var modelHint: WorkflowModelHint
    /// 是否启用上下文 (截图/OCR)
    var enableContext: Bool
    /// 输出处理方式
    var outputMode: WorkflowOutputMode
    
    // MARK: - Computed
    
    /// 图标颜色
    var iconColor: Color {
        Color(hex: iconColorHex)
    }
    
    // MARK: - Init
    
    init(
        id: String,
        name: String,
        keyword: String,
        description: String,
        icon: String,
        iconColorHex: String,
        promptTemplate: String,
        isBuiltin: Bool,
        isEnabled: Bool = true,
        profileId: UUID? = nil,
        modelHint: WorkflowModelHint = .default,
        enableContext: Bool = false,
        outputMode: WorkflowOutputMode = .panel
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.description = description
        self.icon = icon
        self.iconColorHex = iconColorHex
        self.promptTemplate = promptTemplate
        self.isBuiltin = isBuiltin
        self.isEnabled = isEnabled
        self.profileId = profileId
        self.modelHint = modelHint
        self.enableContext = enableContext
        self.outputMode = outputMode
    }
    
    // MARK: - 工厂方法
    
    /// 创建内置 Workflow
    static func builtin(
        keyword: String,
        name: String,
        description: String,
        icon: String,
        iconColorHex: String,
        promptTemplate: String,
        modelHint: WorkflowModelHint = .default,
        enableContext: Bool = false,
        outputMode: WorkflowOutputMode = .panel
    ) -> WorkflowAction {
        WorkflowAction(
            id: "builtin.\(keyword)",
            name: name,
            keyword: keyword,
            description: description,
            icon: icon,
            iconColorHex: iconColorHex,
            promptTemplate: promptTemplate,
            isBuiltin: true,
            isEnabled: true,
            profileId: nil,
            modelHint: modelHint,
            enableContext: enableContext,
            outputMode: outputMode
        )
    }
    
    /// 创建自定义 Workflow
    static func custom(
        name: String,
        keyword: String,
        description: String,
        icon: String,
        iconColorHex: String,
        promptTemplate: String,
        profileId: UUID? = nil,
        modelHint: WorkflowModelHint = .default,
        enableContext: Bool = false,
        outputMode: WorkflowOutputMode = .panel
    ) -> WorkflowAction {
        WorkflowAction(
            id: "custom.\(UUID().uuidString)",
            name: name,
            keyword: keyword,
            description: description,
            icon: icon,
            iconColorHex: iconColorHex,
            promptTemplate: promptTemplate,
            isBuiltin: false,
            isEnabled: true,
            profileId: profileId,
            modelHint: modelHint,
            enableContext: enableContext,
            outputMode: outputMode
        )
    }
    
    // MARK: - 修改辅助
    
    /// 返回更新后的副本
    func with(
        name: String? = nil,
        keyword: String? = nil,
        description: String? = nil,
        icon: String? = nil,
        iconColorHex: String? = nil,
        promptTemplate: String? = nil,
        isEnabled: Bool? = nil,
        profileId: UUID?? = nil,
        modelHint: WorkflowModelHint? = nil,
        enableContext: Bool? = nil,
        outputMode: WorkflowOutputMode? = nil
    ) -> WorkflowAction {
        var copy = self
        if let name = name { copy.name = name }
        if let keyword = keyword { copy.keyword = keyword }
        if let description = description { copy.description = description }
        if let icon = icon { copy.icon = icon }
        if let iconColorHex = iconColorHex { copy.iconColorHex = iconColorHex }
        if let promptTemplate = promptTemplate { copy.promptTemplate = promptTemplate }
        if let isEnabled = isEnabled { copy.isEnabled = isEnabled }
        if let profileId = profileId { copy.profileId = profileId }
        if let modelHint = modelHint { copy.modelHint = modelHint }
        if let enableContext = enableContext { copy.enableContext = enableContext }
        if let outputMode = outputMode { copy.outputMode = outputMode }
        return copy
    }
}

// MARK: - 模型类型提示

/// 模型类型提示 (用于自动选择 Profile)
enum WorkflowModelHint: String, Codable, CaseIterable {
    case `default`     // 默认对话模型
    case fast          // 快速模型 (低延迟)
    case advanced      // 高级模型 (深度思考)
    case imageGen      // 生图模型
    case code          // 代码专用模型
    
    var displayName: String {
        switch self {
        case .default: return "默认"
        case .fast: return "快速"
        case .advanced: return "高级"
        case .imageGen: return "生图"
        case .code: return "代码"
        }
    }
}

// MARK: - 输出处理方式

/// 输出处理方式
enum WorkflowOutputMode: String, Codable, CaseIterable {
    case panel         // 显示在 Answer Panel
    case clipboard     // 直接复制到剪贴板
    case replace       // 替换选中文本
    case append        // 追加到输入
    
    var displayName: String {
        switch self {
        case .panel: return "显示面板"
        case .clipboard: return "复制到剪贴板"
        case .replace: return "替换选中"
        case .append: return "追加输入"
        }
    }
}

// MARK: - 执行上下文

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
    
    init(
        userInput: String,
        screenContext: String? = nil,
        selectedText: String? = nil,
        voiceTranscription: String? = nil,
        clipboardContent: String? = nil
    ) {
        self.userInput = userInput
        self.screenContext = screenContext
        self.selectedText = selectedText
        self.voiceTranscription = voiceTranscription
        self.clipboardContent = clipboardContent
    }
}

// MARK: - 变量占位符

enum WorkflowPlaceholder {
    static let input = "{{input}}"
    static let context = "{{context}}"
    static let selected = "{{selected}}"
    static let voice = "{{voice}}"
    static let clipboard = "{{clipboard}}"
    static let date = "{{date}}"
    static let lang = "{{lang}}"
}

// MARK: - 内置 Workflow 定义

enum WorkflowDefaults {
    
    /// 内置 Workflow 列表
    static let builtins: [WorkflowAction] = [
        .builtin(
            keyword: "translate",
            name: "翻译",
            description: "翻译成中文",
            icon: "character.bubble",
            iconColorHex: "#007AFF",
            promptTemplate: """
            请将以下内容翻译成中文，保持原文格式和语气：

            \(WorkflowPlaceholder.input)

            只输出翻译结果，不要添加解释。
            """,
            modelHint: .default
        ),
        .builtin(
            keyword: "trans-en",
            name: "英文翻译",
            description: "翻译成英文",
            icon: "a.magnify",
            iconColorHex: "#34C759",
            promptTemplate: """
            Please translate the following content into English, maintaining the original format and tone:

            \(WorkflowPlaceholder.input)

            Output only the translation, without any explanation.
            """,
            modelHint: .default
        ),
        .builtin(
            keyword: "summarize",
            name: "总结",
            description: "内容摘要提取",
            icon: "doc.text.magnifyingglass",
            iconColorHex: "#FF9500",
            promptTemplate: """
            请对以下内容进行总结，提取关键信息：

            \(WorkflowPlaceholder.input)

            要求：
            1. 使用中文回答
            2. 提取核心观点和关键信息
            3. 保持简洁，控制在 200 字以内
            """,
            modelHint: .default
        ),
        .builtin(
            keyword: "rewrite",
            name: "改写",
            description: "润色和改写文本",
            icon: "pencil.and.outline",
            iconColorHex: "#AF52DE",
            promptTemplate: """
            请改写以下内容，使其更加流畅、专业：

            \(WorkflowPlaceholder.input)

            要求：
            1. 保持原意不变
            2. 改善表达方式
            3. 直接输出改写结果
            """,
            modelHint: .default,
            outputMode: .clipboard
        ),
        .builtin(
            keyword: "fix",
            name: "语法修正",
            description: "修正语法错误",
            icon: "checkmark.circle",
            iconColorHex: "#30D158",
            promptTemplate: """
            请修正以下文本中的语法和拼写错误：

            \(WorkflowPlaceholder.input)

            只输出修正后的文本，不要解释修改内容。
            """,
            modelHint: .fast,
            outputMode: .clipboard
        )
    ]
}
