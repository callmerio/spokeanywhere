import Foundation
import AppKit
import Observation

/// 录音会话状态枚举
enum RecordingPhase: Equatable {
    case idle
    case recording
    case processing
    case success
    case failure(String)
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
    
    func complete(with text: String) {
        self.finalText = text
        self.phase = .success
    }
    
    func fail(with message: String) {
        self.phase = .failure(message)
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
