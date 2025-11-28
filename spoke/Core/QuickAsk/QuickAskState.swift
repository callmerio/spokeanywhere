import Foundation
import AppKit
import Observation
import AVFoundation
import UniformTypeIdentifiers

/// Quick Ask 会话阶段
enum QuickAskPhase: Equatable {
    case idle
    case recording       // 正在录音 + 等待输入
    case sending         // 发送中
    case answering       // AI 回答中
    case completed       // 完成
    case failed(String)  // 失败
}

/// 附件类型
enum QuickAskAttachment: Identifiable, Equatable {
    /// 图片：原图 + 缩略图 + ID
    case image(NSImage, NSImage?, UUID)
    case file(URL, UUID)
    /// 截图：原图 + 缩略图 + ID
    case screenshot(NSImage, NSImage?, UUID)
    
    var id: UUID {
        switch self {
        case .image(_, _, let id), .file(_, let id), .screenshot(_, _, let id):
            return id
        }
    }
    
    /// 缩略图（用于显示）
    var thumbnail: NSImage? {
        switch self {
        case .image(_, let thumb, _), .screenshot(_, let thumb, _):
            return thumb
        case .file(_, _):
            return nil // 文件缩略图在 AttachmentThumbnail 中单独处理
        }
    }
    
    /// 是否是视频文件
    var isVideo: Bool {
        if case .file(let url, _) = self {
            if let uti = UTType(filenameExtension: url.pathExtension) {
                return uti.conforms(to: .movie) || uti.conforms(to: .video)
            }
        }
        return false
    }
    
    /// 原图（用于发送）
    var originalImage: NSImage? {
        switch self {
        case .image(let image, _, _), .screenshot(let image, _, _):
            return image
        default:
            return nil
        }
    }
    
    var fileName: String? {
        switch self {
        case .file(let url, _):
            return url.lastPathComponent
        default:
            return nil
        }
    }
    
    static func == (lhs: QuickAskAttachment, rhs: QuickAskAttachment) -> Bool {
        lhs.id == rhs.id
    }
    
    /// 生成缩略图（异步）
    static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return image }
        
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()
        
        return thumbnail
    }
    
    /// 从视频生成缩略图
    static func makeVideoThumbnail(from url: URL, maxSize: CGFloat = 256) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxSize, height: maxSize)
        
        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            print("Failed to generate video thumbnail: \(error)")
            return nil
        }
    }
}

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
    
    /// 附件列表
    var attachments: [QuickAskAttachment] = []
    
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
    
    /// 添加附件
    func addAttachment(_ attachment: QuickAskAttachment) {
        attachments.append(attachment)
    }
    
    /// 移除附件
    func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }
    
    /// 添加图片附件（异步生成缩略图）
    func addImage(_ image: NSImage) {
        let id = UUID()
        // 先添加占位（无缩略图），避免延迟感
        let placeholder = QuickAskAttachment.image(image, nil, id)
        attachments.append(placeholder)
        
        // 后台生成缩略图
        Task.detached(priority: .userInitiated) {
            let thumbnail = QuickAskAttachment.makeThumbnail(from: image)
            await MainActor.run {
                // 更新为带缩略图的版本
                if let index = self.attachments.firstIndex(where: { $0.id == id }) {
                    self.attachments[index] = .image(image, thumbnail, id)
                }
            }
        }
    }
    
    /// 添加截图附件（异步生成缩略图）
    func addScreenshot(_ image: NSImage) {
        let id = UUID()
        let placeholder = QuickAskAttachment.screenshot(image, nil, id)
        attachments.append(placeholder)
        
        Task.detached(priority: .userInitiated) {
            let thumbnail = QuickAskAttachment.makeThumbnail(from: image)
            await MainActor.run {
                if let index = self.attachments.firstIndex(where: { $0.id == id }) {
                    self.attachments[index] = .screenshot(image, thumbnail, id)
                }
            }
        }
    }
    
    /// 添加文件附件
    func addFile(_ url: URL) {
        let attachment = QuickAskAttachment.file(url, UUID())
        attachments.append(attachment)
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
