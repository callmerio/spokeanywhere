import AppKit
import Combine
import CoreImage
import Foundation
import ScreenCaptureKit

@available(macOS 12.3, *)
class ScreenCaptureBlurService: NSObject, SCStreamOutput, ObservableObject {
    static let shared = ScreenCaptureBlurService()
    
    @Published var currentFrame: CGImage?
    private var stream: SCStream?
    private let videoOutputQueue = DispatchQueue(label: "com.spoke.screencapture.output", qos: .userInteractive)
    private let context = CIContext()
    
    // 缓存最后的截图，避免闪烁
    private var lastImage: CGImage?
    
    override init() {
        super.init()
    }
    
    func startCapture() {
        Task {
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
                
                print("🎥 ScreenCapture started")
            } catch {
                print("❌ Failed to start screen capture: \(error)")
            }
        }
    }
    
    func stopCapture() {
        Task {
            try? await stream?.stopCapture()
            stream = nil
            print("🛑 ScreenCapture stopped")
        }
    }
    
    /// 模糊半径 (可动态调整)
    var blurRadius: CGFloat = 30.0
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
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
            DispatchQueue.main.async {
                self.currentFrame = cgImage
            }
        }
    }
}
