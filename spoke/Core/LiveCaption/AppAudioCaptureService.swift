@preconcurrency import AVFoundation
@preconcurrency import CoreMedia
import Foundation
import OSLog
@preconcurrency import ScreenCaptureKit
// M2 战术豁免：Apple 框架类型（SCContentFilter, CMSampleBuffer, AVAudioPCMBuffer）尚未标记 Sendable
// 后续跟进 Apple SDK Sendable 状态，届时移除此抑制

// MARK: - App Audio Capture Service

@available(macOS 14.0, *)
@MainActor
protocol AppAudioCapturePickerProtocol: AnyObject {
    var defaultConfiguration: SCContentSharingPickerConfiguration { get set }
    var isActive: Bool { get set }
    func add(_ observer: any SCContentSharingPickerObserver)
    func present()
    func present(for stream: SCStream)
}

/// 应用音频捕获服务
/// 使用 SCContentSharingPicker 让用户选择特定应用进行音频捕获
@available(macOS 14.0, *)
@MainActor
final class AppAudioCaptureService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AppAudioCaptureService(dependencies: .live)
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "AppAudioCapture")
    
    private var stream: SCStream?
    private let audioQueue = DispatchQueue(label: "com.spokeanywhere.appaudio", qos: .userInteractive)
    private let dependencies: AppAudioCaptureServiceDependencies
    private var isPickerConfigured = false
    
    /// 是否正在捕获
    @Published private(set) var isCapturing: Bool = false
    
    /// 当前捕获的应用名称
    @Published private(set) var currentAppName: String?
    
    /// 是否正在等待用户选择
    @Published private(set) var isWaitingForSelection: Bool = false
    
    /// 是否正在重试连接
    @Published private(set) var isRetrying: Bool = false
    
    /// 重试计数
    private var retryCount: Int = 0
    private let maxRetryCount: Int = 3
    private let retryDelays: [TimeInterval] = [1, 2, 4]
    
    /// 上次使用的 filter（用于重连）
    private var lastFilter: SCContentFilter?
    
    /// 上次捕获的应用名（用于重连后恢复）
    private var lastAppName: String?
    
    /// 是否用户主动停止（不触发重试）
    private var isUserInitiatedStop: Bool = false
    
    /// PCM 缓冲区回调（用于 SpeechAnalyzerProvider）
    var onPCMBuffer: ((AVAudioPCMBuffer) -> Void)?
    
    /// 错误回调
    var onError: ((Error) -> Void)?
    
    /// 用户选择完成回调
    var onSelectionComplete: ((Bool) -> Void)?
    
    /// 用户取消选择回调
    var onSelectionCancelled: (() -> Void)?
    
    /// 重试状态变化回调
    var onRetryStateChanged: ((Bool, Int) -> Void)?
    
    // MARK: - Init
    
    private init(dependencies: AppAudioCaptureServiceDependencies) {
        self.dependencies = dependencies
        super.init()
        configurePickerIfNeeded()
    }

    static func makeTesting(dependencies: AppAudioCaptureServiceDependencies) -> AppAudioCaptureService {
        AppAudioCaptureService(dependencies: dependencies)
    }
    
    // MARK: - Picker Configuration
    
    private func configurePickerIfNeeded() {
        guard !isPickerConfigured else { return }

        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = [.singleApplication, .singleWindow]
        config.allowsChangingSelectedContent = true
        
        if let bundleId = Bundle.main.bundleIdentifier {
            config.excludedBundleIDs = [bundleId]
        }
        
        dependencies.picker.defaultConfiguration = config
        dependencies.picker.add(self)
        isPickerConfigured = true
    }
    
    // MARK: - Public API
    
    /// 显示应用选择器
    func presentPicker() {
        logger.info("📱 Presenting app picker")
        isWaitingForSelection = true
        configurePickerIfNeeded()
        dependencies.picker.isActive = true
        dependencies.picker.present()
    }
    
    /// 停止捕获
    func stopCapture() async {
        guard isCapturing || isRetrying else {
            currentAppName = nil
            deactivatePickerAndClearSelectionState()
            return
        }
        
        // 标记为用户主动停止，不触发重试
        isUserInitiatedStop = true
        
        do {
            try await stream?.stopCapture()
        } catch {
            logger.error("❌ Error stopping capture: \(error.localizedDescription)")
        }
        
        stream = nil
        isCapturing = false
        isRetrying = false
        retryCount = 0
        currentAppName = nil
        lastFilter = nil
        lastAppName = nil
        isUserInitiatedStop = false
        deactivatePickerAndClearSelectionState()
        logger.info("🛑 App audio capture stopped")
    }
    
    /// 重新选择应用（不停止当前捕获）
    func reselectApp() {
        logger.info("🔄 Re-selecting app")
        isWaitingForSelection = true
        configurePickerIfNeeded()
        dependencies.picker.isActive = true
        
        if let existingStream = stream {
            dependencies.picker.present(for: existingStream)
        } else {
            dependencies.picker.present()
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
            // 只在真正捕获中才尝试停止，避免 -3808 错误
            if isCapturing {
                do {
                    try await existingStream.stopCapture()
                } catch {
                    // 忽略停止失败（可能已经停止）
                    logger.warning("⚠️ stopCapture failed (ignored): \(error.localizedDescription)")
                }
            }
            stream = nil  // 确保释放
        }
        
        // 保存 filter 用于重连
        lastFilter = filter
        isUserInitiatedStop = false
        
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await stream?.startCapture()
        
        isCapturing = true
        isRetrying = false
        retryCount = 0
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

    private func deactivatePickerAndClearSelectionState() {
        dependencies.picker.isActive = false
        isWaitingForSelection = false
    }
}

// MARK: - SCContentSharingPickerObserver

@available(macOS 14.0, *)
extension AppAudioCaptureService: SCContentSharingPickerObserver {
    
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        runAppAudioCaptureAsync(self) { capture in
            defer {
                capture.deactivatePickerAndClearSelectionState()
            }
            let appName = capture.extractAppName(from: filter) ?? "Selected App"

            do {
                try await capture.startCapture(with: filter)
                capture.currentAppName = appName
                capture.lastAppName = appName
                capture.onSelectionComplete?(true)
            } catch {
                capture.logger.error("❌ Failed to start capture: \(error.localizedDescription)")
                capture.onError?(error)
                capture.onSelectionComplete?(false)
            }
        }
    }
    
    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                logger.info("❌ User cancelled app selection")
                deactivatePickerAndClearSelectionState()
                currentAppName = nil
                onSelectionCancelled?()
            }
            return
        }

        runAppAudioCaptureOnMain(self) { capture in
            capture.logger.info("❌ User cancelled app selection")
            capture.deactivatePickerAndClearSelectionState()
            capture.currentAppName = nil
            capture.onSelectionCancelled?()
        }
    }
    
    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                logger.error("❌ Picker failed to start: \(error.localizedDescription)")
                deactivatePickerAndClearSelectionState()
                currentAppName = nil
                onError?(error)
            }
            return
        }

        runAppAudioCaptureOnMain(self) { capture in
            capture.logger.error("❌ Picker failed to start: \(error.localizedDescription)")
            capture.deactivatePickerAndClearSelectionState()
            capture.currentAppName = nil
            capture.onError?(error)
        }
    }
}

// MARK: - SCStreamOutput

@available(macOS 14.0, *)
extension AppAudioCaptureService: SCStreamOutput {

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        // 内联转换 CMSampleBuffer，避免跨函数传递非 Sendable 类型
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
        }

        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee else {
            return
        }

        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: asbd.mSampleRate,
            channels: AVAudioChannelCount(asbd.mChannelsPerFrame),
            interleaved: false
        ) else {
            return
        }

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
            return
        }
        outputBuffer.frameLength = AVAudioFrameCount(numSamples)

        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
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
            return
        }

        guard let outputData = outputBuffer.floatChannelData?[0] else {
            return
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
            return
        }

        // M2 战术豁免：使用显式 unsafe transfer box 封装单次转移所有权语义
        // AVAudioPCMBuffer 在此路径下仅用于读取并立即处理，逻辑上安全
        let transferred = UnsafeTransferBox(value: outputBuffer)
        deliverAppAudioPCMBuffer(transferred.value, to: self)
    }

    /// 显式 unsafe transfer box：封装单次跨隔离边界转移所有权的语义
}

// MARK: - SCStreamDelegate

@available(macOS 14.0, *)
extension AppAudioCaptureService: SCStreamDelegate {
    
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        runAppAudioCaptureOnMain(self) { capture in
            let nsError = error as NSError
            capture.logger.error("❌ Stream stopped with error: \(error.localizedDescription, privacy: .public) [domain: \(nsError.domain, privacy: .public), code: \(nsError.code)]")

            capture.isCapturing = false
            capture.stream = nil

            guard !capture.isUserInitiatedStop else {
                capture.logger.info("🛑 User initiated stop, skipping retry")
                return
            }

            if capture.isRecoverableError(error) && capture.lastFilter != nil {
                capture.scheduleRetry()
            } else {
                capture.currentAppName = nil
                capture.lastFilter = nil
                capture.lastAppName = nil
                capture.onError?(error)
            }
        }
    }
    
    /// 判断错误是否可恢复
    private func isRecoverableError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // 可恢复的错误（临时性问题，重试有意义）
        // -3821: systemStoppedStream (系统停止)
        // -3805: failedApplicationConnectionInterrupted (连接中断)
        // -3811: internalError (内部错误)
        let recoverableCodes: Set<Int> = [-3821, -3805, -3811]
        
        // 不可恢复的错误（重试无意义）
        // -3801: userDeclined (用户拒绝)
        // -3817: userStopped (用户停止)
        // -3804: failedApplicationConnectionInvalid (连接无效 - 应用已关闭)
        // -3815: noCaptureSource (无捕获源 - 目标已消失)
        // -3808: attemptToStopStreamState (尝试停止已停止的流)
        let nonRecoverableCodes: Set<Int> = [-3801, -3817, -3804, -3815, -3808]
        
        if nonRecoverableCodes.contains(nsError.code) {
            logger.info("🚫 Error \(nsError.code) is non-recoverable")
            return false
        }
        
        // 只有明确可恢复的错误才重试
        return recoverableCodes.contains(nsError.code)
    }
    
    /// 安排重试
    private func scheduleRetry() {
        guard retryCount < maxRetryCount else {
            logger.error("❌ Max retry count (\(self.maxRetryCount)) reached, giving up")
            isRetrying = false
            currentAppName = nil
            lastFilter = nil
            onRetryStateChanged?(false, retryCount)
            onError?(CaptureError.streamCreationFailed)
            return
        }
        
        isRetrying = true
        let delay = retryDelays[min(retryCount, retryDelays.count - 1)]
        retryCount += 1
        
        logger.info("🔄 Scheduling retry \(self.retryCount)/\(self.maxRetryCount) in \(delay)s")
        onRetryStateChanged?(true, retryCount)
        
        _ = makeAppAudioCaptureRetryTask(delay: delay, service: self) { capture in
            await capture.attemptReconnect()
        }
    }
    
    /// 尝试重连
    private func attemptReconnect() async {
        guard let filter = lastFilter else {
            logger.error("❌ No filter available for reconnect")
            isRetrying = false
            onError?(CaptureError.streamCreationFailed)
            return
        }
        
        logger.info("🔄 Attempting reconnect (\(self.retryCount)/\(self.maxRetryCount))...")
        
        do {
            try await startCapture(with: filter)
            if let appName = lastAppName {
                currentAppName = appName
            }
            logger.info("✅ Reconnect successful!")
            onRetryStateChanged?(false, 0)
        } catch {
            logger.error("❌ Reconnect failed: \(error.localizedDescription)")
            // startCapture 失败会触发 didStopWithError，继续重试
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
