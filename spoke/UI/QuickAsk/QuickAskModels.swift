import CoreGraphics
import Foundation
import SwiftUI

/// Quick Ask 模式
enum QuickAskMode: String, CaseIterable {
    case chat = "Chat"
    case deepResearch = "DeepResearch"

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .deepResearch: return "magnifyingglass"
        }
    }
}

/// 消息角色
enum MessageRole: Equatable {
    case user
    case assistant
}

/// 聊天消息模型
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let attachments: [QuickAskAttachment]
    /// AI 生成的图片（仅 assistant 消息有效）
    let generatedImages: [Data]
    /// 上下文来源（仅 user 消息有效）
    let contextSources: [ContextSource]
    /// 应用截图（仅 user 消息有效，用于显示缩略图）
    let screenshotImage: CGImage?
    /// 语音转录内容（仅 user 消息有效，与 content 分开显示）
    let voiceTranscription: String?
    var timestamp = Date()

    init(
        role: MessageRole,
        content: String,
        attachments: [QuickAskAttachment],
        generatedImages: [Data] = [],
        contextSources: [ContextSource] = [],
        screenshotImage: CGImage? = nil,
        voiceTranscription: String? = nil
    ) {
        self.role = role
        self.content = content
        self.attachments = attachments
        self.generatedImages = generatedImages
        self.contextSources = contextSources
        self.screenshotImage = screenshotImage
        self.voiceTranscription = voiceTranscription
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// 回答面板状态
@Observable
@MainActor
final class AnswerPanelState {
    var messages: [ChatMessage] = []
    var isLoading: Bool = false
    var error: String?
    var suggestedQuestions: [String] = []

    // 兼容旧代码的计算属性
    var answer: String {
        messages.last(where: { $0.role == .assistant })?.content ?? ""
    }
}
