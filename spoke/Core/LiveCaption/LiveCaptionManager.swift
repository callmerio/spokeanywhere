import Foundation
import Combine
import OSLog
import AppKit
import SwiftUI
import ScreenCaptureKit

// MARK: - Caption Segment Model

/// 字幕段落
struct CaptionSegment: Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let originalText: String
    var translatedText: String?
    let sourceLanguage: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        originalText: String,
        translatedText: String? = nil,
        sourceLanguage: String = "en"
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
    }
}

// MARK: - Live Caption Manager

/// 实时字幕管理器
/// 整合音频捕获、转录、翻译
@MainActor
final class LiveCaptionManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LiveCaptionManager()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "LiveCaption")
    
    /// 是否激活
    @Published private(set) var isActive: Bool = false
    
    /// 是否展开显示
    @Published var isExpanded: Bool = false
    
    /// 字幕段落列表
    @Published private(set) var segments: [CaptionSegment] = []
    
    /// 当前正在输入的文本（未确定）
    @Published private(set) var pendingText: String = ""
    
    /// 是否显示原文
    @Published var showOriginal: Bool = true
    
    /// 是否启用翻译
    @Published var translationEnabled: Bool = true
    
    /// 源语言
    /// - en-US: 纯英文
    /// - zh-CN: 中文（能识别混入的英文，推荐中英混合场景）
    @Published var sourceLanguage: String = "zh-CN"
    
    /// 支持的语言列表
    static let supportedLanguages: [(id: String, name: String)] = [
        ("en-US", "英语 (English)"),
        ("zh-CN", "中文 (混合英文)"),
        ("ja-JP", "日语 (Japanese)"),
        ("ko-KR", "韩语 (Korean)"),
    ]
    
    // MARK: - Dependencies
    
    private let transcriber = LiveCaptionTranscriber()
    private let translator = TranslationService.shared
    
    /// 最大保留段落数（用户可能听一整天，文本量不大，不做严格限制）
    private let maxSegments = 10000
    
    /// 当前翻译任务
    private var translationTask: Task<Void, Never>?
    
    /// 静默超时时间（秒）- partial result 停止更新超过这么久视为暂停
    private let silenceTimeout: TimeInterval = 1.5
    
    /// 最大字符数（约 2 行，BBC 标准单行 37 字符）
    private let maxCharsPerSegment: Int = 70
    
    /// 句子结束标点
    private let sentenceEndPunctuation = CharacterSet(charactersIn: "。？！.?!")
    
    /// 上次 partial result 更新时间
    private var lastPartialTime: Date = Date()
    
    /// 上次的 pending 文本（用于检测增量）
    private var lastPendingText: String = ""
    
    /// 静默检测定时器
    private var silenceTimer: Timer?
    
    // MARK: - Init
    
    private init() {
        setupCallbacks()
    }
    
    // MARK: - Public API
    
    /// 开始实时字幕
    func start() async throws {
        guard !isActive else { return }
        
        // 检查系统版本
        guard #available(macOS 12.3, *) else {
            throw LiveCaptionError.systemNotSupported
        }
        
        // 检查语音识别权限
        let authorized = await LiveCaptionTranscriber.requestAuthorization()
        guard authorized else {
            logger.error("❌ Speech recognition permission denied")
            throw LiveCaptionError.notAuthorized
        }
        
        // 启动音频捕获（会在内部处理权限问题）
        let capture = SystemAudioCaptureService.shared
        
        capture.onAudioBuffer = { [weak self] buffer in
            self?.transcriber.processAudioBuffer(buffer)
        }
        
        capture.onError = { [weak self] error in
            self?.logger.error("❌ Audio capture error: \(error.localizedDescription)")
        }
        
        do {
            try await capture.startCapture()
        } catch {
            logger.error("❌ Failed to start audio capture: \(error.localizedDescription)")
            // 权限问题，抛出错误让 UI 层处理
            throw LiveCaptionError.captureError("需要屏幕录制权限才能捕获系统音频。")
        }
        
        // 启动转录
        transcriber.updateLocale(Locale(identifier: sourceLanguage))
        
        // 注入词典词汇提高识别率
        let dictionaryWords = DictionaryService.shared.getAllWords()
        if !dictionaryWords.isEmpty {
            transcriber.contextualStrings = dictionaryWords
            logger.info("📚 Injected \(dictionaryWords.count) dictionary words")
        }
        
        try transcriber.startTranscribing()
        
        isActive = true
        logger.info("🎬 Live Caption started")
    }
    
    /// 停止实时字幕
    func stop() async {
        guard isActive else { return }
        
        // 停止转录
        transcriber.stopTranscribing()
        
        // 停止音频捕获
        if #available(macOS 12.3, *) {
            await SystemAudioCaptureService.shared.stopCapture()
        }
        
        // 取消翻译任务
        translationTask?.cancel()
        translationTask = nil
        
        isActive = false
        pendingText = ""
        
        logger.info("🛑 Live Caption stopped")
    }
    
    /// 切换开关
    func toggle() async {
        if isActive {
            await stop()
        } else {
            // macOS 26 上需要先检查权限，避免 TCC 崩溃
            let hasPermission = await checkScreenCapturePermission()
            
            if !hasPermission {
                // 没有权限，引导用户去系统设置授权
                await showPermissionGuide()
                return
            }
            
            do {
                try await start()
            } catch let error as LiveCaptionError {
                logger.error("❌ Failed to start: \(error.localizedDescription)")
                await showPermissionAlert(error: error)
            } catch {
                logger.error("❌ Failed to start: \(error.localizedDescription)")
            }
        }
    }
    
    /// 用户是否已确认授权（避免在 macOS 26 上崩溃）
    @AppStorage("LiveCaptionPermissionConfirmed") private var permissionConfirmed: Bool = false
    
    /// 检查屏幕录制权限
    /// macOS 26 上 SCShareableContent 在无权限时会直接崩溃，无法捕获错误
    /// 所以使用 @AppStorage 让用户手动确认已授权
    private func checkScreenCapturePermission() async -> Bool {
        // macOS 26+ 使用用户确认机制
        if #available(macOS 26.0, *) {
            return permissionConfirmed
        }
        
        // macOS 15-25 可以安全地检查
        if #available(macOS 15.0, *) {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                return true
            } catch {
                logger.warning("⚠️ Screen capture permission not granted: \(error.localizedDescription)")
                return false
            }
        }
        
        // macOS 14 及更早版本
        return CGPreflightScreenCaptureAccess()
    }
    
    /// 显示权限引导弹窗
    private func showPermissionGuide() async {
        let alert = NSAlert()
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = """
        实时字幕功能需要「屏幕与系统音频录制」权限来捕获系统音频。
        
        请点击下方按钮打开系统设置，然后：
        1. 点击 + 号添加应用
        2. 导航到 .build/bundler/ 文件夹
        3. 选择 SpokenAnyWhere.app
        4. 启用权限
        
        授权完成后，点击「已完成授权」继续。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "已完成授权")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统设置
            SystemAudioCaptureService.openScreenCaptureSettings()
        } else if response == .alertSecondButtonReturn {
            // 用户确认已授权，记录状态
            permissionConfirmed = true
            logger.info("✅ User confirmed screen capture permission")
        }
    }
    
    /// 显示权限提示弹窗
    private func showPermissionAlert(error: LiveCaptionError) async {
        let alert = NSAlert()
        alert.messageText = "实时字幕无法启动"
        alert.alertStyle = .warning
        
        switch error {
        case .captureError:
            alert.informativeText = "需要「屏幕录制」权限才能捕获系统音频。\n\n请在系统设置中授权后重试。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "取消")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // 打开屏幕录制权限设置
                if #available(macOS 12.3, *) {
                    SystemAudioCaptureService.openScreenCaptureSettings()
                }
            }
            
        case .notAuthorized:
            alert.informativeText = "需要「语音识别」权限才能转录音频。\n\n请在系统设置中授权后重试。"
            alert.addButton(withTitle: "确定")
            alert.runModal()
            
        case .systemNotSupported:
            alert.informativeText = "实时字幕功能需要 macOS 12.3 或更高版本。"
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
    
    /// 清空历史
    func clearSegments() {
        segments.removeAll()
        pendingText = ""
    }
    
    /// 更新源语言
    func updateSourceLanguage(_ language: String) {
        sourceLanguage = language
        if isActive {
            transcriber.updateLocale(Locale(identifier: language))
        }
    }
    
    // MARK: - Private
    
    private func setupCallbacks() {
        transcriber.onTranscription = { [weak self] segment in
            Task { @MainActor in
                await self?.handleTranscription(segment)
            }
        }
        
        transcriber.onError = { [weak self] error in
            self?.logger.error("❌ Transcription error: \(error.localizedDescription)")
        }
    }
    
    private func handleTranscription(_ segment: TranscriptionSegment) async {
        // 取消之前的静默检测定时器
        silenceTimer?.invalidate()
        
        if segment.isFinal {
            // 最终结果：添加到段落列表
            await saveSegment(text: segment.text)
            lastPendingText = ""
            
        } else {
            // 部分结果
            let currentText = segment.text
            pendingText = currentText
            lastPartialTime = Date()
            
            // 检查是否需要分段
            let shouldSegment = checkShouldSegment(text: currentText)
            
            if shouldSegment {
                // 找到分段点，保存并重置
                await saveSegment(text: currentText)
                lastPendingText = currentText
            } else {
                // 启动静默检测定时器
                startSilenceTimer()
            }
        }
    }
    
    /// 检查是否需要分段
    private func checkShouldSegment(text: String) -> Bool {
        // 条件 1: 检测到句子结束标点
        if let lastChar = text.last, sentenceEndPunctuation.contains(lastChar.unicodeScalars.first!) {
            return true
        }
        
        // 条件 2: 超过最大字符数（约 2 行）
        if text.count >= maxCharsPerSegment {
            return true
        }
        
        return false
    }
    
    /// 启动静默检测定时器
    private func startSilenceTimer() {
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                // 静默超时，保存当前 pending 内容
                if !self.pendingText.isEmpty && self.pendingText != self.lastPendingText {
                    await self.saveSegment(text: self.pendingText)
                    self.lastPendingText = self.pendingText
                }
            }
        }
    }
    
    /// 保存段落（含翻译）
    private func saveSegment(text: String) async {
        pendingText = ""
        
        var newSegment = CaptionSegment(
            originalText: text,
            sourceLanguage: sourceLanguage
        )
        
        // 翻译
        if translationEnabled, translator.isAvailable {
            translationTask?.cancel()
            
            translationTask = Task {
                if let translated = await translator.translate(text) {
                    if let index = segments.firstIndex(where: { $0.id == newSegment.id }) {
                        segments[index].translatedText = translated
                    } else {
                        newSegment.translatedText = translated
                    }
                }
            }
            
            addSegment(newSegment)
            await translationTask?.value
        } else {
            addSegment(newSegment)
        }
    }
    
    private func addSegment(_ segment: CaptionSegment) {
        segments.append(segment)
        
        // 限制数量
        if segments.count > maxSegments {
            segments.removeFirst(segments.count - maxSegments)
        }
    }
}

// MARK: - Errors

extension LiveCaptionManager {
    
    enum LiveCaptionError: LocalizedError {
        case notAuthorized
        case systemNotSupported
        case captureError(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "未授权语音识别权限"
            case .systemNotSupported:
                return "系统版本不支持 (需要 macOS 12.3+)"
            case .captureError(let message):
                return "音频捕获错误: \(message)"
            }
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let liveCaptionDidToggle = Notification.Name("liveCaptionDidToggle")
}
