import AVFoundation
import Foundation
import OSLog
import ScreenCaptureKit

// MARK: - App Audio Capture Service

/// 应用音频捕获服务
/// 使用 SCContentSharingPicker 让用户选择特定应用进行音频捕获
@available(macOS 14.0, *)
@MainActor
final class AppAudioCaptureService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AppAudioCaptureService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "AppAudioCapture")
    
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.spokeanywhere.appaudio", qos: .userInteractive)
    private let picker = SCContentSharingPicker.shared
    
    /// 是否正在捕获
    @Published private(set) var isCapturing: Bool = false
    
    /// 当前捕获的应用名称
    @Published private(set) var currentAppName: String?
    
    /// 是否正在等待用户选择
    @Published private(set) var isWaitingForSelection: Bool = false
    
    /// PCM 缓冲区回调（用于 SpeechAnalyzerProvider）
    var onPCMBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    /// 错误回调
    var onError: ((Error) -> Void)?
    
    /// 用户选择完成回调
    var onSelectionComplete: ((Bool) -> Void)?
    
    /// 用户取消选择回调
    var onSelectionCancelled: (() -> Void)?
    
    // MARK: - Init
    
    private override init() {
        super.init()
        configurePicker()
    }
    
    // MARK: - Picker Configuration
    
    private func configurePicker() {
        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = [.singleApplication, .singleWindow]
        config.allowsChangingSelectedContent = true
        
        if let bundleId = Bundle.main.bundleIdentifier {
            config.excludedBundleIDs = [bundleId]
        }
        
        picker.defaultConfiguration = config
        picker.add(self)
        picker.isActive = true
    }
    
    // MARK: - Public API
    
    /// 显示应用选择器
    func presentPicker() {
        logger.info("📱 Presenting app picker")
        isWaitingForSelection = true
        picker.isActive = true
        picker.present()
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
        currentAppName = nil
        logger.info("🛑 App audio capture stopped")
    }
    
    /// 重新选择应用（不停止当前捕获）
    func reselectApp() {
        logger.info("🔄 Re-selecting app")
        isWaitingForSelection = true
        
        if let existingStream = stream {
            picker.present(for: existingStream)
        } else {
            picker.present()
        }
    }
    
    // MARK: - Private Methods
    
    private func startCapture(with filter: SCContentFilter) async throws {
        let config = SCStreamConfiguration()
        
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 16000
        config.channelCount = 1
        
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 1
        
        if let existingStream = stream {
            try await existingStream.stopCapture()
        }
        
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await stream?.startCapture()
        
        isCapturing = true
        logger.info("🎧 App audio capture started for: \(self.currentAppName ?? "Unknown")")
    }
    
    private func extractAppName(from filter: SCContentFilter) -> String? {
        let mirror = Mirror(reflecting: filter)
        for child in mirror.children {
            if child.label == "applications",
               let apps = child.value as? [SCRunningApplication],
               let firstApp = apps.first {
                return firstApp.applicationName
            }
        }
        return nil
    }
}

// MARK: - SCContentSharingPickerObserver

@available(macOS 14.0, *)
extension AppAudioCaptureService: SCContentSharingPickerObserver {
    
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in
            self.isWaitingForSelection = false
            let appName = self.extractAppName(from: filter) ?? "Selected App"
            
            do {
                try await self.startCapture(with: filter)
                // 延迟更新 UI 状态，避免在 Display Cycle 中触发约束循环
                DispatchQueue.main.async {
                    self.currentAppName = appName
                    self.onSelectionComplete?(true)
                }
            } catch {
                self.logger.error("❌ Failed to start capture: \(error.localizedDescription)")
                self.onError?(error)
                self.onSelectionComplete?(false)
            }
        }
    }
    
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in
            self.logger.info("❌ User cancelled app selection")
            self.isWaitingForSelection = false
            self.onSelectionCancelled?()
        }
    }
    
    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor in
            self.logger.error("❌ Picker failed to start: \(error.localizedDescription)")
            self.isWaitingForSelection = false
            self.onError?(error)
        }
    }
}

// MARK: - SCStreamOutput

@available(macOS 14.0, *)
extension AppAudioCaptureService: SCStreamOutput {
    
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        Task { @MainActor in
            if self.onPCMBuffer != nil, let pcmBuffer = self.convertToPCMBuffer(sampleBuffer) {
                self.onPCMBuffer?(pcmBuffer)
            }
        }
    }
    
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
        
        let formatFlags = asbd.mFormatFlags
        let isFloat = (formatFlags & kAudioFormatFlagIsFloat) != 0
        let isSignedInt = (formatFlags & kAudioFormatFlagIsSignedInteger) != 0
        let bitsPerChannel = asbd.mBitsPerChannel
        
        if isFloat && bitsPerChannel == 32 {
            let floatData = UnsafeRawPointer(data).assumingMemoryBound(to: Float.self)
            memcpy(outputData, floatData, numSamples * MemoryLayout<Float>.size)
        } else if isSignedInt && bitsPerChannel == 16 {
            let int16Data = UnsafeRawPointer(data).assumingMemoryBound(to: Int16.self)
            for i in 0..<numSamples {
                outputData[i] = Float(int16Data[i]) / 32768.0
            }
        } else if isSignedInt && bitsPerChannel == 32 {
            let int32Data = UnsafeRawPointer(data).assumingMemoryBound(to: Int32.self)
            for i in 0..<numSamples {
                outputData[i] = Float(int32Data[i]) / Float(Int32.max)
            }
        } else {
            return nil
        }
        
        return outputBuffer
    }
}

// MARK: - SCStreamDelegate

@available(macOS 14.0, *)
extension AppAudioCaptureService: SCStreamDelegate {
    
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.logger.error("❌ Stream stopped with error: \(error.localizedDescription)")
            self.isCapturing = false
            self.currentAppName = nil
            self.onError?(error)
        }
    }
}

// MARK: - Errors

@available(macOS 14.0, *)
extension AppAudioCaptureService {
    
    enum CaptureError: LocalizedError {
        case userCancelled
        case streamCreationFailed
        case notAuthorized
        
        var errorDescription: String? {
            switch self {
            case .userCancelled:
                return "用户取消了应用选择"
            case .streamCreationFailed:
                return "创建音频流失败"
            case .notAuthorized:
                return "未授权屏幕录制权限"
            }
        }
    }
}
