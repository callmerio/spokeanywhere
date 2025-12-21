import Foundation
import Combine

// MARK: - Screenshot Settings

enum UpscalingMode: String, CaseIterable, Codable {
    case none
    case basic      // Lanczos + Sharpen
    case ai         // Real-ESRGAN
    
    var displayName: String {
        switch self {
        case .none: return "Off"
        case .basic: return "Basic (Sharpen)"
        case .ai: return "AI Enhanced (Real-ESRGAN)"
        }
    }
}

final class ScreenshotSettings: ObservableObject {
    
    static let shared = ScreenshotSettings()
    
    @Published var upscalingMode: UpscalingMode {
        didSet {
            UserDefaults.standard.set(upscalingMode.rawValue, forKey: "Screenshot.UpscalingMode")
        }
    }
    
    /// 复制时使用 AI 增强后的图片（如果可用）
    @Published var copyEnhancedImage: Bool {
        didSet {
            UserDefaults.standard.set(copyEnhancedImage, forKey: "Screenshot.CopyEnhancedImage")
        }
    }
    
    private init() {
        if let rawValue = UserDefaults.standard.string(forKey: "Screenshot.UpscalingMode"),
           let mode = UpscalingMode(rawValue: rawValue) {
            self.upscalingMode = mode
        } else {
            self.upscalingMode = .basic // Default
        }
        
        // 默认开启复制增强图片
        self.copyEnhancedImage = UserDefaults.standard.object(forKey: "Screenshot.CopyEnhancedImage") as? Bool ?? true
    }
}
