import Foundation
import OSLog

// MARK: - Translation Service

/// Apple Translation API 封装
/// 注意: Translation API 需要 macOS 15+ 且在 SwiftUI 上下文中使用
/// 当前版本使用 placeholder 实现，待系统 API 稳定后完善
@MainActor
final class TranslationService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = TranslationService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "Translation")
    
    /// 是否支持翻译功能
    /// Translation API 需要 macOS 15+，且需要通过 SwiftUI .translationTask 使用
    var isAvailable: Bool {
        // Translation framework 的 TranslationSession 直接使用需要 macOS 26+
        // 目前暂时禁用，后续通过 SwiftUI 方式集成
        return false
    }
    
    /// 目标语言
    @Published var targetLanguage: String = "zh-Hans"
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 翻译文本
    /// 当前为 placeholder 实现，返回 nil
    /// 后续将通过 SwiftUI .translationTask 方式实现
    func translate(_ text: String, from sourceLanguage: String? = nil) async -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        // TODO: 使用 SwiftUI .translationTask 方式实现
        // Translation API 的 TranslationSession 直接使用需要 macOS 26+
        // 目前返回 nil，字幕仅显示原文
        logger.info("📝 Translation not yet implemented, showing original text")
        return nil
    }
    
    /// 检查语言包是否已下载
    func checkLanguageAvailability(source: String, target: String) async -> Bool {
        // 暂未实现
        return false
    }
}

// MARK: - Supported Languages

extension TranslationService {
    
    /// 支持的目标语言列表
    static let supportedTargetLanguages: [(code: String, name: String)] = [
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁体中文"),
        ("en", "English"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("fr", "Français"),
        ("de", "Deutsch"),
        ("es", "Español"),
        ("pt-BR", "Português"),
        ("ru", "Русский"),
        ("ar", "العربية"),
    ]
}
