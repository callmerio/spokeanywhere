import AppKit
import Combine
import CoreImage
import Foundation
import os
import ScreenCaptureKit

@available(macOS 12.3, *)
@MainActor
class ScreenCaptureBlurService: NSObject, SCStreamOutput, ObservableObject {
    @MainActor static let shared = ScreenCaptureBlurService()

    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ScreenCaptureBlurService")
    @Published var currentFrame: CGImage?
    private var stream: SCStream?
    private let videoOutputQueue = DispatchQueue(label: "com.spoke.screencapture.output", qos: .userInteractive)
    nonisolated private let context = CIContext()

    // 缓存最后的截图，避免闪烁
    private var lastImage: CGImage?

    // MARK: - R2-2 Diagnostic Counters

    /// 主线程派发耗时记录（用于计算 P95）
    private var mainDispatchTimes: [Double] = []

    /// 覆盖标志：是否触发过 blur 路径
    private(set) var coverageBlur: Bool = false

    /// 获取 P95 主线程派发耗时
    func getBlurMainDispatchP95() -> Double {
        guard !mainDispatchTimes.isEmpty else { return 0 }
        let sorted = mainDispatchTimes.sorted()
        let p95Index = Int(Double(sorted.count) * 0.95)
        return sorted[min(p95Index, sorted.count - 1)]
    }

    /// 重置诊断计数器
    func resetDiagnostics() {
        mainDispatchTimes.removeAll()
        coverageBlur = false
    }
    
    override init() {
        super.init()
    }
    
    func startCapture() {
        runScreenCaptureBlurAsync(self) { service in
            await service.startCaptureStream()
        }
    }
    
    func stopCapture() {
        runScreenCaptureBlurAsync(self) { service in
            await service.stopCaptureStream()
        }
    }
    
    /// 模糊半径 (可动态调整)
    nonisolated(unsafe) var blurRadius: CGFloat = 30.0

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }

        // R2-2: 记录入队时间（用于测量主线程派发延迟）
        let enqueueTs = CFAbsoluteTimeGetCurrent()

        // 在 Service 层做模糊，输出已模糊的帧
        // 这样 View 层只需要裁剪显示，不会有边缘问题
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // CoreImage 高斯模糊
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(blurRadius, forKey: kCIInputRadiusKey)

        guard let blurredImage = blurFilter.outputImage else { return }

        // 裁剪回原始尺寸（模糊会扩展边界）
        let croppedImage = blurredImage.cropped(to: ciImage.extent)

        if let cgImage = context.createCGImage(croppedImage, from: ciImage.extent) {
            runScreenCaptureBlurOnMain(self) { service in
                service.publishBlurFrame(cgImage, enqueueTs: enqueueTs)
            }
        }
    }

    private func startCaptureStream() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else { return }

            // 排除自己的应用窗口，防止"无限镜"效应
            // 注意：这里简单地排除了所有属于当前应用的窗口
            // 实际生产中可能需要更精细的控制
            let excludedApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }

            let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
            config.queueDepth = 5
            config.showsCursor = false

            stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoOutputQueue)
            try await stream?.startCapture()
        } catch {
            logger.error("❌ Failed to start screen capture blur stream: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func stopCaptureStream() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    private func publishBlurFrame(_ cgImage: CGImage, enqueueTs: CFAbsoluteTime) {
        let dispatchMs = (CFAbsoluteTimeGetCurrent() - enqueueTs) * 1000
        mainDispatchTimes.append(dispatchMs)
        coverageBlur = true
        currentFrame = cgImage
    }
}
