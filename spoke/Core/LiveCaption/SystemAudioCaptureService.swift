import Foundation
import ScreenCaptureKit
import AVFoundation
import OSLog

// MARK: - System Audio Capture Service

/// 系统音频捕获服务
/// 使用 ScreenCaptureKit 捕获系统播放的音频（非麦克风）
@available(macOS 12.3, *)
@MainActor
final class SystemAudioCaptureService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SystemAudioCaptureService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "SystemAudioCapture")
    
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.spokeanywhere.systemaudio", qos: .userInteractive)
    
    /// 是否正在捕获
    @Published private(set) var isCapturing: Bool = false
    
    /// 音频缓冲区回调
    var onAudioBuffer: ((CMSampleBuffer) -> Void)?
    
    /// 错误回调
    var onError: ((Error) -> Void)?
    
    // MARK: - Init
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public API
    
    /// 检查屏幕录制权限
    /// 注意: macOS 26+ 上这个 API 可能触发 TCC 崩溃，需谨慎使用
    static func checkScreenCapturePermission() -> Bool {
        // 尝试用更安全的方式检查
        // CGPreflightScreenCaptureAccess 在 macOS 26 上可能触发 TCC 崩溃
        // 所以这里直接返回 true，让实际调用时处理错误
        return true
    }
    
    /// 请求屏幕录制权限 - 打开系统设置
    static func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// 开始捕获系统音频
    func startCapture() async throws {
        guard !isCapturing else {
            logger.warning("⚠️ Already capturing")
            return
        }
        
        // 直接尝试获取可共享内容
        // 如果没有权限，SCShareableContent 会返回错误
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            logger.error("❌ Failed to get shareable content: \(error.localizedDescription)")
            // 权限问题，引导用户到设置
            throw CaptureError.notAuthorized
        }
        
        guard let display = content.displays.first else {
            throw CaptureError.noDisplayFound
        }
        
        // 排除当前应用
        let excludedApps = content.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }
        
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApps,
            exceptingWindows: []
        )
        
        // 配置流 - 只需要音频
        let config = SCStreamConfiguration()
        
        // 音频配置
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 16000  // SFSpeech 推荐采样率
        config.channelCount = 1    // 单声道
        
        // 视频配置 - 最小化以节省资源
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)  // 1 FPS
        config.queueDepth = 1
        
        // 创建流
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        
        // 添加音频输出
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        
        // 开始捕获
        try await stream?.startCapture()
        
        isCapturing = true
        logger.info("🎧 System audio capture started")
    }
    
    /// 停止捕获
    func stopCapture() async {
        guard isCapturing else { return }
        
        do {
            try await stream?.stopCapture()
        } catch {
            logger.error("❌ Error stopping capture: \(error.localizedDescription)")
        }
        
        stream = nil
        isCapturing = false
        logger.info("🛑 System audio capture stopped")
    }
}

// MARK: - SCStreamOutput

@available(macOS 12.3, *)
extension SystemAudioCaptureService: SCStreamOutput {
    
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // 转发到主线程处理
        Task { @MainActor in
            self.onAudioBuffer?(sampleBuffer)
        }
    }
}

// MARK: - SCStreamDelegate

@available(macOS 12.3, *)
extension SystemAudioCaptureService: SCStreamDelegate {
    
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.logger.error("❌ Stream stopped with error: \(error.localizedDescription)")
            self.isCapturing = false
            self.onError?(error)
        }
    }
}

// MARK: - Errors

@available(macOS 12.3, *)
extension SystemAudioCaptureService {
    
    enum CaptureError: LocalizedError {
        case noDisplayFound
        case streamCreationFailed
        case notAuthorized
        
        var errorDescription: String? {
            switch self {
            case .noDisplayFound:
                return "未找到显示器"
            case .streamCreationFailed:
                return "创建音频流失败"
            case .notAuthorized:
                return "未授权屏幕录制权限"
            }
        }
    }
}

// MARK: - Availability Check

enum SystemAudioCaptureAvailability {
    
    static var isSupported: Bool {
        if #available(macOS 12.3, *) {
            return true
        }
        return false
    }
}
