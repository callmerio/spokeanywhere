import SwiftUI

// MARK: - 工具栏按钮动作定义

/// 工具栏按钮动作类型
enum SelectionToolbarActionType: String, CaseIterable, Codable, Identifiable {
    /// 朗读 - TTS 朗读选中文本
    case speak
    /// 查询 - 联网搜索 + AI 解释
    case lookup
    /// 翻译 - 翻译选中文本
    case translate
    /// 总结 - AI 总结长文本
    case summarize
    /// 复制 - 复制到剪贴板
    case copy
    
    var id: String { rawValue }
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .speak: return "朗读"
        case .lookup: return "查询"
        case .translate: return "翻译"
        case .summarize: return "总结"
        case .copy: return "复制"
        }
    }
    
    /// 图标名称 (SF Symbols)
    var iconName: String {
        switch self {
        case .speak: return "speaker.wave.2.fill"
        case .lookup: return "magnifyingglass"
        case .translate: return "character.book.closed.fill"
        case .summarize: return "doc.text.magnifyingglass"
        case .copy: return "doc.on.doc"
        }
    }
    
    /// 图标颜色
    var iconColor: Color {
        switch self {
        case .speak: return .orange
        case .lookup: return .blue
        case .translate: return .purple
        case .summarize: return .green
        case .copy: return .gray
        }
    }
    
    /// 是否需要联网
    var requiresNetwork: Bool {
        switch self {
        case .speak, .lookup, .translate, .summarize:
            return true
        case .copy:
            return false
        }
    }
    
    /// 是否需要 LLM
    var requiresLLM: Bool {
        switch self {
        case .lookup, .summarize:
            return true
        default:
            return false
        }
    }
    
    /// 快捷键提示
    var shortcutHint: String? {
        switch self {
        case .speak: return "⌥S"
        case .lookup: return "⌥L"
        case .translate: return "⌥T"
        case .copy: return "⌘C"
        default: return nil
        }
    }
}

// MARK: - 选中文本上下文

/// 选中文本及其上下文信息
struct SelectionContext: Equatable {
    /// 选中的文本
    let selectedText: String
    
    /// 选中文本的屏幕位置 (用于工具栏定位)
    let selectionBounds: CGRect
    
    /// 来源应用的 Bundle ID
    let sourceAppBundleId: String?
    
    /// 来源应用名称
    let sourceAppName: String?
    
    /// 当前应用 OCR 上下文 (可选)
    var ocrContext: String?
    
    /// 创建时间
    let timestamp: Date
    
    init(
        selectedText: String,
        selectionBounds: CGRect,
        sourceAppBundleId: String? = nil,
        sourceAppName: String? = nil,
        ocrContext: String? = nil
    ) {
        self.selectedText = selectedText
        self.selectionBounds = selectionBounds
        self.sourceAppBundleId = sourceAppBundleId
        self.sourceAppName = sourceAppName
        self.ocrContext = ocrContext
        self.timestamp = Date()
    }
    
    /// 选中文本是否为空或太短（至少2个字符才算有效选中）
    var isEmpty: Bool {
        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.count < 2
    }
    
    /// 选中文本长度
    var textLength: Int {
        selectedText.count
    }
    
    /// 是否为长文本 (超过 500 字符)
    var isLongText: Bool {
        textLength > 500
    }
}

// MARK: - 动作执行结果

/// 动作执行结果
enum SelectionActionResult {
    case success(message: String?)
    case failure(error: Error)
    case cancelled
}

// MARK: - 动作执行状态

/// 动作执行阶段
enum SelectionActionPhase: Equatable {
    case idle
    case preparing
    case executing(progress: Double?)
    case completed
    case failed(message: String)
}
