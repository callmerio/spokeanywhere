import AppKit
import AVFoundation
import Combine
import Foundation
import OSLog
import ScreenCaptureKit
import SwiftUI

// MARK: - Caption Segment Model

/// 字幕段落
struct CaptionSegment: Identifiable, Equatable, Codable {
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

@MainActor
struct LiveCaptionManagerDependencies {
    let translator: TranslationService
    let appCaptureService: AppAudioCaptureService
    let systemCaptureService: SystemAudioCaptureService
    let transcriptionModelManager: TranscriptionModelManager
    let dictionaryService: DictionaryService
    let postTranslationUpdate: () -> Void
}

/// 实时字幕管理器
/// 整合音频捕获、转录、翻译
/// 使用 SpeechAnalyzerProvider (macOS 26+) 获得最佳识别效果
@MainActor
final class LiveCaptionManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LiveCaptionManager(dependencies: .live)
    
    // MARK: - Properties
    
    private let dependencies: LiveCaptionManagerDependencies
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
    
    /// 实时字幕独立语言设置（独立于全局设置）
    /// 存储 locale 标识符，如 "en-US", "zh-Hans"
    @AppStorage("LiveCaptionLocale") var captionLocale: String = "en-US"
    
    /// 音频捕获模式
    /// - global: 捕获所有系统音频（默认）
    /// - appPicker: macOS 14+ 让用户选择特定应用
    @AppStorage("LiveCaptionCaptureMode") var captureMode: String = CaptureMode.global.rawValue
    
    /// 当前捕获的应用名称（应用模式时）
    @Published private(set) var currentAppName: String?
    
    /// 是否正在重试连接（UI 显示用）
    var isRetrying: Bool {
        if #available(macOS 14.0, *) {
            return dependencies.appCaptureService.isRetrying
        }
        return false
    }
    
    /// 行缓冲区（折叠模式使用）
    let lineBuffer = CaptionLineBuffer()
    
    /// 源语言（使用独立的 captionLocale 设置）
    var sourceLanguage: String {
        captionLocale
    }
    
    /// 支持的语言列表
    static let supportedLanguages: [(id: String, name: String)] = [
        ("en-US", "英语 (English)"),
        ("zh-Hans", "中文 (混合英文)"),
        ("ja-JP", "日语 (Japanese)"),
        ("ko-KR", "韩语 (Korean)")
    ]
    
    /// 音频捕获模式枚举
    enum CaptureMode: String, CaseIterable {
        case global           // 全局模式 (捕获所有系统音频)
        case appPicker        // 应用选择模式 (macOS 14+)
        
        var displayName: String {
            switch self {
            case .global: return "全局模式"
            case .appPicker: return "应用选择模式"
            }
        }
        
        var description: String {
            switch self {
            case .global: return "捕获所有系统音频"
            case .appPicker: return "选择特定应用 (macOS 14+)"
            }
        }
    }
    
    // MARK: - Dependencies
    
    /// 使用 SpeechAnalyzerProvider（复用主转录引擎）- 用 Any 类型避免 @available 限制
    private var _provider: Any?
    
    @available(macOS 26.0, *)
    private var provider: SpeechAnalyzerProvider? {
        get { _provider as? SpeechAnalyzerProvider }
        set { _provider = newValue }
    }
    
    /// 回退：使用旧的 LiveCaptionTranscriber (macOS < 26)
    private var legacyTranscriber: LiveCaptionTranscriber?
    
    /// 内存中最大保留段落数（用于 UI 显示）
    /// 文字很轻量，可以保留较多用于回看
    private let maxSegmentsInMemory = 500
    
    /// 持久化文件最大保留段落数
    private let maxSegmentsInFile = 2000
    
    /// 当前翻译任务
    private var translationTask: LiveCaptionAsyncTask?
    
    /// 流式翻译任务（带防抖）
    private var volatileTranslationTask: LiveCaptionAsyncTask?
    
    /// 上次的 finalizedText 长度（用于计算增量）
    private var lastFinalizedLength: Int = 0
    
    /// 字幕历史存储路径
    private var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let spokeDir = appSupport.appendingPathComponent("Spoke", isDirectory: true)
        return spokeDir.appendingPathComponent("caption_history.json")
    }
    
    // MARK: - Init
    
    private init(
        dependencies: LiveCaptionManagerDependencies
    ) {
        self.dependencies = dependencies
        loadSegments()
    }

    static func makePreview() -> LiveCaptionManager {
        LiveCaptionManager(dependencies: .preview)
    }

    @MainActor
    static func makeTesting(dependencies: LiveCaptionManagerDependencies? = nil) -> LiveCaptionManager {
        LiveCaptionManager(dependencies: dependencies ?? .preview)
    }
    
    // MARK: - Public API
    
    /// 切换识别语言（会自动重启引擎）
    func setLocale(_ locale: String) async {
        guard locale != captionLocale else { return }
        captionLocale = locale
        
        // 如果正在运行，重启以应用新语言
        if isActive {
            await stop()
            try? await start()
        }
    }
    
    /// 切换到下一个支持的语言（循环切换）
    func switchToNextLanguage() {
        let current = sourceLanguage
        let languages = Self.supportedLanguages.map { $0.id }
        if let index = languages.firstIndex(of: current) {
            let nextIndex = (index + 1) % languages.count
            let nextLocale = languages[nextIndex]
            runLiveCaptionManagerAsync(self) { manager in
                await manager.setLocale(nextLocale)
            }
        }
    }
    
    /// 开始实时字幕
    func start() async throws {
        guard !isActive else { return }
        
        // 每次启动时清空历史，从干净状态开始
        clearSegments()
        
        // 检查系统版本
        guard #available(macOS 12.3, *) else {
            throw LiveCaptionError.systemNotSupported
        }
        
        // macOS 26+ 使用 SpeechAnalyzerProvider，效果更好
        if #available(macOS 26.0, *) {
            try await startWithSpeechAnalyzer()
        } else {
            try await startWithLegacyTranscriber()
        }
        
        isActive = true
    }
    
    /// 使用 SpeechAnalyzerProvider (macOS 26+)
    @available(macOS 26.0, *)
    private func startWithSpeechAnalyzer() async throws {
        // 检查是否使用应用选择模式
        let useAppPicker = captureMode == CaptureMode.appPicker.rawValue
        
        if useAppPicker {
            try await startWithAppPicker()
            return
        }
        
        // 全局模式
        try await startWithGlobalCapture()
    }
    
    /// 使用应用选择器模式 (macOS 26+ 因为依赖 SpeechAnalyzerProvider)
    @available(macOS 26.0, *)
    private func startWithAppPicker() async throws {
        let appCapture = dependencies.appCaptureService
        
        // 设置选择完成回调
        appCapture.onSelectionComplete = { [weak self] success in
            guard let self = self, success else { return }
            runLiveCaptionManagerAsync(self) { manager in
                manager.currentAppName = appCapture.currentAppName
                do {
                    try await manager.setupSpeechAnalyzer(withAppCapture: true)
                } catch {
                    manager.logger.error("❌ Failed to setup speech analyzer: \(error.localizedDescription)")
                }
            }
        }
        
        appCapture.onSelectionCancelled = { [weak self] in
            runLiveCaptionManagerAsync(self) { manager in
                manager.logger.info("⚠️ User cancelled app selection, falling back to global mode")
                do {
                    try await manager.startWithGlobalCapture()
                } catch {
                    manager.logger.error("❌ Failed to start global capture: \(error.localizedDescription)")
                    manager.isActive = false
                }
            }
        }
        
        // 重试状态变化回调
        appCapture.onRetryStateChanged = { [weak self] isRetrying, retryCount in
            runLiveCaptionManagerOnMain(self) { manager in
                if isRetrying {
                    manager.logger.info("🔄 [LiveCaption] App capture retrying (\(retryCount)/3)...")
                } else if retryCount > 0 {
                    manager.logger.info("✅ [LiveCaption] App capture reconnected!")
                    // 重连成功，恢复应用名
                    manager.currentAppName = appCapture.currentAppName
                }
            }
        }
        
        appCapture.onError = { [weak self] error in
            runLiveCaptionManagerAsync(self) { manager in
                // 只有在非重试状态下才停止（重试失败后 isRetrying 为 false）
                if !appCapture.isRetrying {
                    manager.logger.error("❌ App capture error (final): \(error.localizedDescription)")
                    await manager.stop()
                }
            }
        }
        
        // 显示应用选择器
        appCapture.presentPicker()
        logger.info("📱 Waiting for user to select app...")
    }
    
    /// 使用全局音频捕获模式
    @available(macOS 26.0, *)
    private func startWithGlobalCapture() async throws {
        try await setupSpeechAnalyzer(withAppCapture: false)
        
        // 启动全局音频捕获
        let capture = dependencies.systemCaptureService
        do {
            try await capture.startCapture()
        } catch {
            logger.error("❌ Failed to start audio capture: \(error.localizedDescription)")
            throw LiveCaptionError.captureError("需要屏幕录制权限才能捕获系统音频。")
        }
        
        logger.info("🎬 Live Caption started with global capture")
    }
    
    /// 设置语音分析器
    @available(macOS 26.0, *)
    private func setupSpeechAnalyzer(withAppCapture: Bool) async throws {
        // 获取用户配置的实时字幕模型
        let modelManager = dependencies.transcriptionModelManager
        let liveCaptionModelId = modelManager.settings.liveCaptionModelId
        let modelSettings = modelManager.settings.settings(for: liveCaptionModelId)
        
        guard let modelDef = TranscriptionModelDefinition.find(by: liveCaptionModelId) else {
            throw LiveCaptionError.captureError("未找到实时字幕模型配置")
        }
        
        // 使用独立的 captionLocale 而非全局设置
        let locale = Locale(identifier: captionLocale)
        logger.info("🎬 Starting LiveCaption with model: \(modelDef.displayName, privacy: .public), locale: \(self.captionLocale, privacy: .public)")
        
        // 创建 SpeechAnalyzerProvider
        let speechProvider = SpeechAnalyzerProvider(
            locale: locale,
            modelType: modelDef.type
        )
        speechProvider.enablePrecompiledLM = modelDef.supportsPrecompiledLM && modelSettings.enablePrecompiledLM
        
        // 设置结果回调
        speechProvider.onResult = { [weak self] result in
            self?.handleTranscriptionResult(result)
        }
        
        speechProvider.onError = { [weak self] error in
            self?.logger.error("❌ Transcription error: \(error.localizedDescription)")
        }
        
        // 准备引擎（包含词典注入）
        try await speechProvider.prepare()
        self.provider = speechProvider
        
        // 根据模式设置音频回调
        if withAppCapture {
            let appCapture = dependencies.appCaptureService
            appCapture.onPCMBuffer = { [weak self] buffer in
                guard let self = self else { return }
                do {
                    try self.provider?.process(buffer: buffer)
                } catch {
                    self.logger.error("❌ Process buffer error: \(error.localizedDescription)")
                }
            }
        } else {
            let capture = dependencies.systemCaptureService
            capture.onPCMBuffer = { [weak self] buffer in
                guard let self = self else { return }
                do {
                    try self.provider?.process(buffer: buffer)
                } catch {
                    self.logger.error("❌ Process buffer error: \(error.localizedDescription)")
                }
            }
            
            capture.onError = { [weak self] error in
                guard let self = self else { return }
                self.logger.error("❌ Audio capture error: \(error.localizedDescription)")
                runLiveCaptionManagerAsync(self) { manager in
                    await manager.stop()
                }
            }
        }
        
        logger.info("🎬 SpeechAnalyzer setup completed (appCapture: \(withAppCapture))")
    }
    
    /// 使用旧的 LiveCaptionTranscriber (macOS < 26)
    @available(macOS 12.3, *)
    private func startWithLegacyTranscriber() async throws {
        // 检查语音识别权限
        let authorized = await LiveCaptionTranscriber.requestAuthorization()
        guard authorized else {
            logger.error("❌ Speech recognition permission denied")
            throw LiveCaptionError.notAuthorized
        }
        
        // 创建 transcriber
        let transcriber = LiveCaptionTranscriber()
        self.legacyTranscriber = transcriber
        
        // 设置回调
        transcriber.onTranscription = { [weak self] segment in
            runLiveCaptionManagerAsync(self) { manager in
                await manager.handleLegacyTranscription(segment)
            }
        }
        
        transcriber.onError = { [weak self] error in
            self?.logger.error("❌ Transcription error: \(error.localizedDescription)")
        }
        
        // 启动音频捕获
        let capture = dependencies.systemCaptureService
        
        capture.onAudioBuffer = { [weak self] buffer in
            self?.legacyTranscriber?.processAudioBuffer(buffer)
        }
        
        capture.onError = { [weak self] error in
            runLiveCaptionManagerAsync(self) { manager in
                manager.logger.error("❌ Audio capture error: \(error.localizedDescription)")
                await manager.stop()
            }
        }
        
        do {
            try await capture.startCapture()
        } catch {
            logger.error("❌ Failed to start audio capture: \(error.localizedDescription)")
            throw LiveCaptionError.captureError("需要屏幕录制权限才能捕获系统音频。")
        }
        
        // 启动转录（使用用户设置的源语言）
        transcriber.updateLocale(Locale(identifier: sourceLanguage))
        
        // 注入词典词汇
        let dictionaryWords = dependencies.dictionaryService.getAllWords()
        if !dictionaryWords.isEmpty {
            transcriber.contextualStrings = dictionaryWords
            logger.info("📚 Injected \(dictionaryWords.count) dictionary words")
        }
        
        try transcriber.startTranscribing()
        
        logger.info("🎬 Live Caption started with legacy transcriber")
    }
    
    /// 停止实时字幕
    func stop() async {
        guard isActive else { return }
        
        // 停止转录
        if #available(macOS 26.0, *) {
            if let captionProvider = provider {
                try? await captionProvider.finishProcessing()
                captionProvider.reset()
            }
            _provider = nil
        }
        legacyTranscriber?.stopTranscribing()
        legacyTranscriber = nil
        
        // 停止音频捕获（根据当前模式）
        if captureMode == CaptureMode.appPicker.rawValue {
            if #available(macOS 14.0, *) {
                await dependencies.appCaptureService.stopCapture()
            }
        } else {
            if #available(macOS 12.3, *) {
                await dependencies.systemCaptureService.stopCapture()
            }
        }
        
        // 取消翻译任务
        translationTask?.cancel()
        translationTask = nil
        volatileTranslationTask?.cancel()
        volatileTranslationTask = nil
        
        isActive = false
        pendingText = ""
        lastFinalizedLength = 0
        currentAppName = nil
        
        // 停止时保存历史
        saveSegments()
        
        logger.info("🛑 Live Caption stopped")
    }
    
    /// 重新选择应用（应用模式专用）
    func reselectApp() {
        guard isActive, captureMode == CaptureMode.appPicker.rawValue else { return }
        
        if #available(macOS 14.0, *) {
            logger.info("🔄 Re-selecting app...")
            dependencies.appCaptureService.reselectApp()
        }
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
    
    /// 清空历史（内存 + 文件）
    func clearSegments() {
        segments.removeAll()
        pendingText = ""
        lastFinalizedLength = 0
        lineBuffer.clear()
        
        // 清空持久化文件
        try? FileManager.default.removeItem(at: storageURL)
        logger.info("🧹 Caption history cleared")
    }
    
    // MARK: - Context Export (for Quick Ask)
    
    /// 获取原文历史（不带翻译，用于 Quick Ask 上下文）
    /// - Parameter limit: 限制条数，0 表示全量
    /// - Returns: 原文拼接字符串
    func getOriginalTextHistory(limit: Int = 0) -> String {
        let allItems = lineBuffer.items
        let targetItems = limit > 0 ? Array(allItems.suffix(limit)) : allItems
        
        // 只拼接原文，不带翻译
        let texts = targetItems.map { $0.original }
        let result = texts.joined(separator: " ")
        
        logger.info("📋 Exported \(targetItems.count) caption items (limit: \(limit == 0 ? "all" : String(limit)))")
        return result
    }
    
    /// 获取原文历史条数
    var originalTextCount: Int {
        lineBuffer.items.count
    }
    
    // MARK: - Result Handling
    
    /// 处理 SpeechAnalyzerProvider 的结果 (macOS 26+)
    /// 新逻辑：volatile 实时更新 + 流式翻译，finalized 触发最终翻译
    private func handleTranscriptionResult(_ result: TranscriptionResult) {
        // 1. 更新 pendingText (Volatile)
        pendingText = result.volatileText
        lineBuffer.updateVolatile(text: result.volatileText)
        
        // 2. 对 volatile 文本进行流式翻译（带防抖）
        if !result.volatileText.isEmpty {
            translateVolatileText(result.volatileText)
        }
        
        // 3. 处理 Finalized 增量
        let currentLength = result.finalizedText.count
        if currentLength > lastFinalizedLength {
            let startIndex = result.finalizedText.index(result.finalizedText.startIndex, offsetBy: lastFinalizedLength)
            let newText = String(result.finalizedText[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !newText.isEmpty {
                // 🔥 先取消翻译任务，防止竞态
                volatileTranslationTask?.cancel()
                
                // 🔥 先添加到 Buffer（继承 pendingTranslation），再清空流式状态
                // 顺序很重要：addFinalized 需要读取 pendingTranslation 来继承翻译
                guard let itemId = lineBuffer.addFinalized(text: newText) else { return }
                lineBuffer.clearPending()
                
                // 触发翻译并更新 Buffer + 历史记录
                runLiveCaptionManagerAsync(self) { manager in
                    let translation = await manager.translateAndUpdateBuffer(itemId: itemId, text: newText)
                    await manager.saveSegment(text: newText, translation: translation)
                }
            }
            
            lastFinalizedLength = currentLength
        }
    }
    
    /// 对流式文本进行实时翻译（300ms 防抖）
    private func translateVolatileText(_ text: String) {
        guard translationEnabled, dependencies.translator.isAvailable else { return }
        
        // 获取当前版本号
        let currentVersion = lineBuffer.currentVolatileVersion
        
        // 取消之前的任务
        volatileTranslationTask?.cancel()
        
        volatileTranslationTask = makeLiveCaptionVolatileTranslationTask(
            text: text,
            translator: dependencies.translator,
            currentVersion: currentVersion
        ) { [self] translated, version in
            self.lineBuffer.updatePendingTranslation(translated, version: version)
        }
    }
    
    /// 翻译并更新 Buffer 中的 Item（带重试）
    /// - Returns: 翻译结果，用于复用到历史记录
    private func translateAndUpdateBuffer(itemId: UUID, text: String) async -> String? {
        guard translationEnabled, dependencies.translator.isAvailable else { return nil }

        let translated = await runLiveCaptionTranslationRetry(
            text: text,
            translator: dependencies.translator
        ) { [self] translated in
            lineBuffer.updateTranslation(id: itemId, translation: translated)
            // 🔥 翻译完成后发送通知，触发强制滚动
            dependencies.postTranslationUpdate()
        }

        if translated == nil {
            logger.warning("⚠️ 翻译失败（已重试3次）: \(text.prefix(30))...")
        }

        return translated
    }
    
    /// 处理旧版 LiveCaptionTranscriber 的结果 (macOS < 26)
    private func handleLegacyTranscription(_ segment: TranscriptionSegment) async {
        if segment.isFinal {
            // 清空流式状态
            lineBuffer.clearPending()
            volatileTranslationTask?.cancel()
            
            // 添加到 Buffer
            guard let itemId = lineBuffer.addFinalized(text: segment.text) else { return }
            // 触发翻译
            let translation = await translateAndUpdateBuffer(itemId: itemId, text: segment.text)
            // 保存历史
            await saveSegment(text: segment.text, translation: translation)
        } else {
            pendingText = segment.text
            lineBuffer.updateVolatile(text: segment.text)
            // 流式翻译
            translateVolatileText(segment.text)
        }
    }
    
    /// 保存段落（含翻译）- 用于历史记录
    /// - Parameters:
    ///   - text: 原文
    ///   - translation: 已翻译的结果（复用，避免重复请求）
    private func saveSegment(text: String, translation: String?) async {
        let newSegment = CaptionSegment(
            originalText: text,
            translatedText: translation,
            sourceLanguage: sourceLanguage
        )
        addSegment(newSegment)
    }
    
    private func addSegment(_ segment: CaptionSegment) {
        segments.append(segment)
        
        // 内存中限制数量（用于 UI 显示）
        if segments.count > maxSegmentsInMemory {
            segments.removeFirst(segments.count - maxSegmentsInMemory)
        }
        
        // 定期持久化（每 10 条保存一次，避免频繁 IO）
        if segments.count % 10 == 0 {
            saveSegments()
        }
    }
    
    // MARK: - Persistence
    
    /// 保存字幕历史到文件
    private func saveSegments() {
        // 只保存有内容的段落
        let segmentsToSave = segments.filter { !$0.originalText.isEmpty }
        
        // 限制文件中的数量
        let limitedSegments = segmentsToSave.suffix(maxSegmentsInFile)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(Array(limitedSegments))
            
            // 确保目录存在
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            try data.write(to: storageURL, options: .atomic)
            logger.debug("💾 Saved \(limitedSegments.count) caption segments")
        } catch {
            logger.error("❌ Failed to save caption history: \(error.localizedDescription)")
        }
    }
    
    /// 从文件加载字幕历史
    private func loadSegments() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.debug("📂 No caption history file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loadedSegments = try decoder.decode([CaptionSegment].self, from: data)
            
            // 只加载最近 24 小时的记录
            let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
            segments = loadedSegments.filter { $0.timestamp > cutoff }
            
            logger.info("📥 Loaded \(self.segments.count) caption segments from history")
        } catch {
            logger.error("❌ Failed to load caption history: \(error.localizedDescription)")
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
