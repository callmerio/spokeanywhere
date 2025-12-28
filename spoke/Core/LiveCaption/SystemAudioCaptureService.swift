import AVFoundation
import Foundation
import OSLog
import ScreenCaptureKit

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
    
    /// 音频缓冲区回调（原始 CMSampleBuffer）
    var onAudioBuffer: ((CMSampleBuffer) -> Void)?
    
    /// PCM 缓冲区回调（用于 SpeechAnalyzerProvider）
    var onPCMBuffer: ((AVAudioPCMBuffer) -> Void)?
    
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
            
            // 转换为 PCM 并回调（用于 SpeechAnalyzerProvider）
            if self.onPCMBuffer != nil, let pcmBuffer = self.convertToPCMBuffer(sampleBuffer) {
                self.onPCMBuffer?(pcmBuffer)
            }
        }
    }
    
    /// 将 CMSampleBuffer 转换为 AVAudioPCMBuffer
    /// SpeechAnalyzer 需要特定格式的 PCM 数据
    @MainActor
    private func convertToPCMBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            return nil
        }
        
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return nil }
        
        // 创建 AVAudioFormat
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: asbd.mSampleRate,
            channels: AVAudioChannelCount(asbd.mChannelsPerFrame),
            interleaved: false
        ) else {
            return nil
        }
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return nil
        }
        outputBuffer.frameLength = AVAudioFrameCount(numSamples)
        
        // 获取原始音频数据
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &dataPointer
        )
        
        guard status == kCMBlockBufferNoErr, let data = dataPointer else {
            return nil
        }
        
        guard let outputData = outputBuffer.floatChannelData?[0] else {
            return nil
        }
        
        // 根据输入格式转换数据
        let formatFlags = asbd.mFormatFlags
        let isFloat = (formatFlags & kAudioFormatFlagIsFloat) != 0
        let isSignedInt = (formatFlags & kAudioFormatFlagIsSignedInteger) != 0
        let bitsPerChannel = asbd.mBitsPerChannel
        
        if isFloat && bitsPerChannel == 32 {
            // Float32 输入 - 直接复制（使用 assumingMemoryBound 避免 UB）
            let floatData = UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
            memcpy(outputData, floatData, numSamples * MemoryLayout<Float>.size)
        } else if isSignedInt && bitsPerChannel == 16 {
            // Int16 输入 - 转换为 Float32
            let int16Data = UnsafeRawPointer(data).assumingMemoryBound(to: Int16.self)
            for i in 0..<numSamples {
                outputData[i] = Float(int16Data[i]) / 32768.0
            }
        } else if isSignedInt && bitsPerChannel == 32 {
            // Int32 输入 - 转换为 Float32
            let int32Data = UnsafeRawPointer(data).assumingMemoryBound(to: Int32.self)
            for i in 0..<numSamples {
                outputData[i] = Float(int32Data[i]) / Float(Int32.max)
            }
        } else {
            // 不支持的格式
            return nil
        }
        
        return outputBuffer
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
