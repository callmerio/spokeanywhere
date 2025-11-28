import Foundation
import AppKit
import Observation

/// Quick Ask 会话阶段
enum QuickAskPhase: Equatable {
    case idle
    case recording       // 正在录音 + 等待输入
    case sending         // 发送中
    case answering       // AI 回答中
    case completed       // 完成
    case failed(String)  // 失败
}

/// 向后兼容的类型别名
/// 新代码请直接使用 Attachment 类型
typealias QuickAskAttachment = Attachment

/// Quick Ask 状态模型
@Observable
@MainActor
final class QuickAskState {
    
    // MARK: - Phase
    
    /// 当前阶段
    var phase: QuickAskPhase = .idle
    
    // MARK: - Input
    
    /// 用户文字输入
    var userInput: String = ""
    
    /// 语音转写文本
    var voiceTranscription: String = ""
    
    /// 附件列表（使用通用 Attachment 类型）
    var attachments: [Attachment] = []
    
    /// 缩略图更新观察者
    private var thumbnailObserver: NSObjectProtocol?
    
    // MARK: - Recording
    
    /// 当前目标 App
    var targetApp: TargetAppInfo?
    
    /// 音频电平 (0.0-1.0)
    var audioLevel: Float = 0
    
    /// 录音时长
    var duration: TimeInterval = 0
    
    // MARK: - Answer
    
    /// AI 回答
    var answer: String = ""
    
    /// 推荐问题
    var suggestedQuestions: [String] = []
    
    // MARK: - Computed
    
    /// 是否显示 HUD
    var isVisible: Bool {
        phase != .idle
    }
    
    /// 是否可以发送
    var canSend: Bool {
        !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !voiceTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !attachments.isEmpty
    }
    
    /// 是否正在录音
    var isRecording: Bool {
        phase == .recording
    }
    
    // MARK: - Actions
    
    /// 开始 Quick Ask 会话
    func startSession(targetApp: TargetAppInfo?) {
        self.phase = .recording
        self.targetApp = targetApp
        self.userInput = ""
        self.voiceTranscription = ""
        self.attachments = []
        self.audioLevel = 0
        self.duration = 0
        self.answer = ""
        self.suggestedQuestions = []
    }
    
    /// 更新音频电平
    func updateAudioLevel(_ level: Float) {
        self.audioLevel = min(max(level, 0), 1)
    }
    
    /// 更新录音时长
    func updateDuration(_ duration: TimeInterval) {
        self.duration = duration
    }
    
    /// 更新语音转写
    func updateVoiceTranscription(_ text: String) {
        self.voiceTranscription = text
    }
    
    /// 添加附件（通用方法）
    func addAttachment(_ attachment: Attachment) {
        attachments.append(attachment)
        setupThumbnailObserverIfNeeded()
    }
    
    /// 移除附件
    func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }
    
    /// 添加图片附件（通过 AttachmentManager）
    func addImage(_ image: NSImage) {
        AttachmentManager.shared.addImage(image, source: .paste) { [weak self] attachment in
            self?.addAttachment(attachment)
        }
    }
    
    /// 添加截图附件
    func addScreenshot(_ image: NSImage) {
        AttachmentManager.shared.addScreenshot(image) { [weak self] attachment in
            self?.addAttachment(attachment)
        }
    }
    
    /// 添加文件附件
    func addFile(_ url: URL) {
        Task {
            await AttachmentManager.shared.handleFileURL(url, source: .drop) { [weak self] attachment in
                self?.addAttachment(attachment)
            }
        }
    }
    
    /// 设置缩略图更新观察者
    private func setupThumbnailObserverIfNeeded() {
        guard thumbnailObserver == nil else { return }
        
        thumbnailObserver = NotificationCenter.default.addObserver(
            forName: .attachmentThumbnailUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let id = notification.userInfo?["id"] as? UUID,
                  let updated = notification.userInfo?["attachment"] as? Attachment else { return }
            
            // 确保在 MainActor 上下文中更新
            Task { @MainActor in
                if let index = self?.attachments.firstIndex(where: { $0.id == id }) {
                    self?.attachments[index] = updated
                }
            }
        }
    }
    
    /// 开始发送
    func startSending() {
        self.phase = .sending
    }
    
    /// 开始回答
    func startAnswering() {
        self.phase = .answering
    }
    
    /// 完成回答
    func complete(answer: String, suggestions: [String] = []) {
        self.answer = answer
        self.suggestedQuestions = suggestions
        self.phase = .completed
    }
    
    /// 失败
    func fail(with message: String) {
        self.phase = .failed(message)
    }
    
    /// 重置（放弃）
    func reset() {
        self.phase = .idle
        self.targetApp = nil
        self.userInput = ""
        self.voiceTranscription = ""
        self.attachments = []
        self.audioLevel = 0
        self.duration = 0
        self.answer = ""
        self.suggestedQuestions = []
    }
    
    /// 重新录音（保留文字输入，清空语音）
    func restartRecording() {
        self.voiceTranscription = ""
        self.audioLevel = 0
        self.duration = 0
        self.phase = .recording
    }
}
