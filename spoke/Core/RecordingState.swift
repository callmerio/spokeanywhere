import AppKit
import Foundation
import Observation

/// 录音会话状态枚举
enum RecordingPhase: Equatable {
    case idle
    case recording
    case processing   // 转写处理中
    case thinking     // LLM 思考中
    case success
    case failure(message: String, reason: String? = nil, suggestion: String? = nil)
    
    static func == (lhs: RecordingPhase, rhs: RecordingPhase) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.processing, .processing), (.thinking, .thinking), (.success, .success):
            return true
        case (.failure(let m1, let r1, let s1), .failure(let m2, let r2, let s2)):
            return m1 == m2 && r1 == r2 && s1 == s2
        default:
            return false
        }
    }
}

/// 录音会话状态模型
/// 使用 @Observable (macOS 14+) 替代 ObservableObject
@Observable
@MainActor
final class RecordingState {
    /// 当前录音阶段
    var phase: RecordingPhase = .idle
    
    /// 录音时长（秒）
    var duration: TimeInterval = 0
    
    /// 当前目标 App 信息
    var targetApp: TargetAppInfo?
    
    /// 实时转写文本（中间结果，灰字显示）
    var partialText: String = ""
    
    /// 最终转写文本
    var finalText: String = ""
    
    /// 音频振幅（用于波形可视化，0.0-1.0）
    var audioLevel: Float = 0
    
    /// 是否显示胶囊
    var isVisible: Bool {
        phase != .idle
    }
    
    // MARK: - Actions
    
    func startRecording(targetApp: TargetAppInfo?) {
        self.phase = .recording
        self.duration = 0
        self.targetApp = targetApp
        self.partialText = ""
        self.finalText = ""
    }
    
    func updateDuration(_ duration: TimeInterval) {
        self.duration = duration
    }
    
    func updateAudioLevel(_ level: Float) {
        self.audioLevel = min(max(level, 0), 1)
    }
    
    func updatePartialText(_ text: String) {
        self.partialText = text
    }
    
    func startProcessing() {
        self.phase = .processing
    }
    
    func startThinking() {
        self.phase = .thinking
    }
    
    func complete(with text: String) {
        self.finalText = text
        self.phase = .success
    }
    
    func fail(with error: Error) {
        let message = error.localizedDescription
        let reason = (error as? LocalizedError)?.failureReason
        let suggestion = (error as? LocalizedError)?.recoverySuggestion
        
        self.phase = .failure(message: message, reason: reason, suggestion: suggestion)
    }
    
    func fail(with message: String) {
        self.phase = .failure(message: message)
    }
    
    func reset() {
        self.phase = .idle
        self.duration = 0
        self.targetApp = nil
        self.partialText = ""
        self.finalText = ""
        self.audioLevel = 0
    }
}

/// 目标 App 信息
struct TargetAppInfo: Equatable {
    let bundleIdentifier: String
    let name: String
    let icon: NSImage?
    
    static func from(_ app: NSRunningApplication) -> TargetAppInfo {
        TargetAppInfo(
            bundleIdentifier: app.bundleIdentifier ?? "unknown",
            name: app.localizedName ?? "Unknown",
            icon: app.icon
        )
    }
}
