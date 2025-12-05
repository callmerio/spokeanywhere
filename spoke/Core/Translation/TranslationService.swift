import Foundation
import OSLog
import Translation

// MARK: - Translation Service

/// Apple Translation API 封装
/// macOS 15+ 支持 Translation framework
@MainActor
final class TranslationService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = TranslationService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "Translation")
    
    /// 翻译会话（macOS 15+）- 使用 Any 避免版本限制
    private var _translationSession: Any?
    
    /// 翻译配置（macOS 15+）- 使用 Any 避免版本限制
    private var _configuration: Any?
    
    /// 翻译配置（类型安全访问）
    @available(macOS 15.0, *)
    var configuration: TranslationSession.Configuration? {
        get { _configuration as? TranslationSession.Configuration }
        set { _configuration = newValue }
    }
    
    /// 是否支持翻译功能
    var isAvailable: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }
    
    /// 目标语言
    @Published var targetLanguage: String = "zh-Hans" {
        didSet {
            // 目标语言变化时重置会话
            invalidateSession()
        }
    }
    
    /// 源语言（nil 表示自动检测）
    @Published var sourceLanguage: String? = nil {
        didSet {
            invalidateSession()
        }
    }
    
    /// 翻译缓存（避免重复翻译相同文本）
    private var translationCache: [String: String] = [:]
    private let maxCacheSize = 100
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 准备翻译会话
    /// 调用此方法后会触发 configuration 更新，用于 SwiftUI .translationTask
    func prepareSession(source: String? = nil, target: String = "zh-Hans") {
        guard #available(macOS 15.0, *) else { return }
        
        sourceLanguage = source
        targetLanguage = target
        
        let sourceLang: Locale.Language? = source.map { Locale.Language(identifier: $0) }
        let targetLang = Locale.Language(identifier: target)
        
        configuration = TranslationSession.Configuration(
            source: sourceLang,
            target: targetLang
        )
        
        logger.info("🌐 Translation session prepared: \(source ?? "auto") → \(target)")
    }
    
    /// 使用已有会话翻译文本
    /// 需要在 SwiftUI .translationTask 中获取 session 后调用
    @available(macOS 15.0, *)
    func translate(_ text: String, using session: TranslationSession) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // 检查缓存
        if let cached = translationCache[trimmed] {
            return cached
        }
        
        do {
            let response = try await session.translate(trimmed)
            let result = response.targetText
            
            // 缓存结果
            cacheTranslation(original: trimmed, translated: result)
            
            logger.debug("✅ Translated: \(trimmed.prefix(30))... → \(result.prefix(30))...")
            return result
        } catch {
            logger.error("❌ Translation error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 批量翻译（更高效）
    @available(macOS 15.0, *)
    func translateBatch(_ texts: [String], using session: TranslationSession) async -> [String: String] {
        var results: [String: String] = [:]
        
        // 过滤已缓存的
        var toTranslate: [String] = []
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cached = translationCache[trimmed] {
                results[text] = cached
            } else if !trimmed.isEmpty {
                toTranslate.append(trimmed)
            }
        }
        
        guard !toTranslate.isEmpty else { return results }
        
        do {
            let requests = toTranslate.map { TranslationSession.Request(sourceText: $0) }
            let responses = try await session.translations(from: requests)
            
            for (index, response) in responses.enumerated() {
                let original = toTranslate[index]
                let translated = response.targetText
                results[original] = translated
                cacheTranslation(original: original, translated: translated)
            }
            
            logger.info("✅ Batch translated \(toTranslate.count) texts")
        } catch {
            logger.error("❌ Batch translation error: \(error.localizedDescription)")
        }
        
        return results
    }
    
    /// 独立翻译（macOS 26+ 支持独立 session）
    func translate(_ text: String, from source: String? = nil) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // 检查缓存
        if let cached = translationCache[trimmed] {
            return cached
        }
        
        // macOS 26+ 支持独立创建 session
        if #available(macOS 26.0, *) {
            do {
                let sourceLang = Locale.Language(identifier: source ?? "en")
                let targetLang = Locale.Language(identifier: targetLanguage)
                let session = try TranslationSession(installedSource: sourceLang, target: targetLang)
                let response = try await session.translate(trimmed)
                let result = response.targetText
                
                cacheTranslation(original: trimmed, translated: result)
                logger.debug("✅ Translated: \(trimmed.prefix(30))... → \(result.prefix(30))...")
                return result
            } catch {
                logger.error("❌ Translation error: \(error.localizedDescription)")
                return nil
            }
        }
        
        // macOS 15-25: 需要通过 SwiftUI translationTask 使用，暂不支持
        logger.debug("📝 Standalone translation requires macOS 26+")
        return nil
    }
    
    /// 检查语言包是否已下载
    @available(macOS 15.0, *)
    func checkLanguageAvailability(source: String?, target: String) async -> LanguageAvailability.Status {
        let availability = LanguageAvailability()
        let sourceLang: Locale.Language? = source.map { Locale.Language(identifier: $0) }
        let targetLang = Locale.Language(identifier: target)
        
        return await availability.status(from: sourceLang ?? .init(identifier: "en"), to: targetLang)
    }
    
    /// 使配置无效，触发重新创建会话
    func invalidateSession() {
        if #available(macOS 15.0, *) {
            configuration?.invalidate()
            configuration = nil
        }
        _translationSession = nil
    }
    
    /// 清空缓存
    func clearCache() {
        translationCache.removeAll()
    }
    
    // MARK: - Private
    
    private func cacheTranslation(original: String, translated: String) {
        // LRU 简易实现：超过限制时清空一半
        if translationCache.count >= maxCacheSize {
            let keysToRemove = Array(translationCache.keys.prefix(maxCacheSize / 2))
            for key in keysToRemove {
                translationCache.removeValue(forKey: key)
            }
        }
        translationCache[original] = translated
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
