import Foundation
import SwiftUI

// MARK: - Service Protocols

/// 音频捕获服务协议
@MainActor
protocol AudioCaptureServiceProtocol: AnyObject {
    var isRecording: Bool { get }
    var isProcessing: Bool { get }
    var tempAudioFileURL: URL? { get }
    var currentEngineType: TranscriptionEngineType? { get }

    var onAudioLevelUpdate: ((Float) -> Void)? { get set }
    var onPartialResult: ((TranscriptionResult) -> Void)? { get set }
    var onFinalResult: ((String) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    func requestPermissions() async -> Bool
    func startRecording() throws
    func stopRecording() -> String?
    func cancelRecording()
    func cleanupTempFile()
}

/// 转录服务协议
@MainActor
protocol TranscriptionServiceProtocol: AnyObject {
    var currentProvider: TranscriptionProvider? { get }
    var currentEngineType: TranscriptionEngineType? { get }
    var preferredLocale: Locale { get }
    var isDictionaryInjectionEnabled: Bool { get set }
    var isDictionaryPrepared: Bool { get }
    var needsDictionaryPreparation: Bool { get }

    func availableEngines() -> [TranscriptionProviderInfo]
    func bestAvailableEngine() -> TranscriptionEngineType
    func createProvider(type: TranscriptionEngineType) -> TranscriptionProvider?
    func createBestProvider() -> TranscriptionProvider
    func releaseProvider()
    func prepareDictionary() async
    func requestPermissions() async -> Bool
    func engineStatusDescription() -> String
}

/// LLM 服务协议
@MainActor
protocol LLMServiceProtocol: AnyObject {
    var isProcessing: Bool { get }
    var shouldProcess: Bool { get }
    var currentProviderName: String { get }

    func chat(_ message: String) async -> Result<LLMResponse, LLMError>
    func chat(_ message: String, profile: ProviderProfile) async -> Result<LLMResponse, LLMError>
    func refine(_ text: String, customSystemPrompt: String?) async -> Result<String, LLMError>
}

/// 应用设置服务协议
@MainActor
protocol AppSettingsProtocol: AnyObject {
    var startAtLogin: Bool { get set }
    var showInDock: Bool { get set }
    var showInMenuBar: Bool { get set }
    var pressEscToCancel: Bool { get set }
    var playSoundEffect: Bool { get set }
    var recordingMode: AppSettings.RecordingMode { get set }
    var realtimeTypingEnabled: Bool { get set }
    var selectionToolbarEnabled: Bool { get set }

    // 快捷键相关
    var shortcutKeyCode: Int { get set }
    var shortcutModifiers: Int { get set }
    var shortcutDisplayString: String { get }
    func updateShortcut(keyCode: Int, modifiers: Int)
}

/// 历史记录服务协议
@MainActor
protocol HistoryManagerProtocol: AnyObject {
    var audioStorageURL: URL { get }

    func saveRecording(rawText: String, processedText: String?, tempAudioURL: URL?, appBundleId: String?) async
    func reprocess(_ item: HistoryItem, with customPrompt: String) async -> Result<String, LLMError>
    func deleteItem(_ item: HistoryItem)
    func audioURL(for item: HistoryItem) -> URL?
    func getStorageStats() async -> (count: Int, totalSize: Int64)
    func setRecordType(_ item: HistoryItem, type: HistoryRecordType)
}

/// Quick Ask 服务协议
@MainActor
protocol QuickAskServiceProtocol: AnyObject {
    var state: QuickAskState { get }
    var isActive: Bool { get }

    func startSession()
    func sendQuestion() async
    func cancelSession()
    func restartRecording()
    func sendViaShortcut()
}

// MARK: - Service Container

@MainActor
struct ServiceContainerDependencies {
    let makeAudioCapture: () -> AudioCaptureServiceProtocol
    let makeTranscription: () -> TranscriptionServiceProtocol
    let makeLLM: () -> LLMServiceProtocol
    let makeLLMPipeline: () -> LLMPipeline
    let makeWorkflowExecutor: () -> WorkflowExecutor
    let makeAppSettings: () -> AppSettingsProtocol
    let makeAppSettingsConcrete: () -> AppSettings
    let makeHistoryManager: () -> HistoryManagerProtocol
    let makeHistoryManagerConcrete: () -> HistoryManager
    let makeQuickAsk: () -> QuickAskServiceProtocol
    let makeQuickAskServiceConcrete: () -> QuickAskService
    let makeAudioRecorderService: () -> AudioRecorderService
    let makeWorkspace: () -> NSWorkspace
    let makeWorkflowConfigService: () -> WorkflowConfigService
    let makePasteboard: () -> NSPasteboard
    let makeContextService: () -> ContextService
    let makeClipboardHistoryService: () -> ClipboardHistoryService
    let makeClipboardPipelineService: () -> ClipboardPipelineService
    let makeHotKeyService: () -> HotKeyService
    let makeWorkflowState: () -> WorkflowState
    let makeAttachmentManager: () -> AttachmentManager
    let makeQuickAskHUDManager: () -> QuickAskHUDManager
    let makeAnswerPanelManager: () -> AnswerPanelManager
    let makeLiveCaptionManager: () -> LiveCaptionManager
    let makeSelectionMonitorService: () -> SelectionMonitorService
    let makeFloatingHUDManager: () -> FloatingHUDManager
    let makeInputService: () -> InputService
    let makeMessagePanelManager: () -> MessagePanelManager
    let makeLiveCaptionWindowManager: () -> LiveCaptionWindowManager
    let makeSelectionToolbarState: () -> SelectionToolbarState
    let makeToolbarConfigService: () -> ToolbarConfigService
    let makeTTSService: () -> TTSService
    let makeScreenOCR: () -> ScreenOCRService
    let makeDictionaryAPI: () -> DictionaryAPIService
    let makeSelectionToolbarManager: () -> SelectionToolbarManager
    let makeLLMSettings: () -> LLMSettings
}

/// 轻量级依赖注入容器
///
/// 使用方式:
/// ```swift
/// // 获取服务
/// let audio = ServiceContainer.shared.audioCapture
///
/// // SwiftUI 中使用
/// @Environment(\.services) var services
///
/// // 测试时注入 Mock
/// ServiceContainer.shared.register(audioCapture: MockAudioService())
/// ```
@MainActor
final class ServiceContainer: ObservableObject {

    // MARK: - Singleton

    static let shared = ServiceContainer(dependencies: .live)

    private let dependencies: ServiceContainerDependencies

    // MARK: - Private Storage

    private var _audioCapture: AudioCaptureServiceProtocol?
    private var _transcription: TranscriptionServiceProtocol?
    private var _llm: LLMServiceProtocol?
    private var _llmPipeline: LLMPipeline?
    private var _workflowExecutor: WorkflowExecutor?
    private var _appSettings: AppSettingsProtocol?
    private var _appSettingsConcrete: AppSettings?
    private var _historyManager: HistoryManagerProtocol?
    private var _historyManagerConcrete: HistoryManager?
    private var _quickAsk: QuickAskServiceProtocol?
    private var _quickAskServiceConcrete: QuickAskService?
    private var _audioRecorderService: AudioRecorderService?
    private var _workspace: NSWorkspace?
    private var _workflowConfigService: WorkflowConfigService?
    private var _pasteboard: NSPasteboard?
    private var _contextService: ContextService?
    private var _clipboardHistoryService: ClipboardHistoryService?
    private var _clipboardPipelineService: ClipboardPipelineService?
    private var _hotKeyService: HotKeyService?
    private var _workflowState: WorkflowState?
    private var _attachmentManager: AttachmentManager?
    private var _quickAskHUDManager: QuickAskHUDManager?
    private var _answerPanelManager: AnswerPanelManager?
    private var _liveCaptionManager: LiveCaptionManager?
    private var _selectionMonitorService: SelectionMonitorService?
    private var _floatingHUDManager: FloatingHUDManager?
    private var _inputService: InputService?
    private var _messagePanelManager: MessagePanelManager?
    private var _liveCaptionWindowManager: LiveCaptionWindowManager?
    private var _selectionToolbarState: SelectionToolbarState?
    private var _toolbarConfigService: ToolbarConfigService?
    private var _ttsService: TTSService?
    private var _screenOCR: ScreenOCRService?
    private var _dictionaryAPI: DictionaryAPIService?
    private var _selectionToolbarManager: SelectionToolbarManager?
    private var _llmSettings: LLMSettings?

    // MARK: - Lazy Service Access

    /// 音频捕获服务
    var audioCapture: AudioCaptureServiceProtocol {
        resolveService(storage: &_audioCapture, provider: dependencies.makeAudioCapture)
    }

    /// 转录服务
    var transcription: TranscriptionServiceProtocol {
        resolveService(storage: &_transcription, provider: dependencies.makeTranscription)
    }

    /// LLM 服务
    var llm: LLMServiceProtocol {
        resolveService(storage: &_llm, provider: dependencies.makeLLM)
    }

    var llmPipeline: LLMPipeline {
        resolveService(storage: &_llmPipeline, provider: dependencies.makeLLMPipeline)
    }

    var workflowExecutor: WorkflowExecutor {
        resolveService(storage: &_workflowExecutor, provider: dependencies.makeWorkflowExecutor)
    }

    /// 应用设置服务
    var appSettings: AppSettingsProtocol {
        resolveService(storage: &_appSettings, provider: dependencies.makeAppSettings)
    }

    var appSettingsConcrete: AppSettings {
        resolveService(storage: &_appSettingsConcrete, provider: dependencies.makeAppSettingsConcrete)
    }

    /// 历史记录服务
    var historyManager: HistoryManagerProtocol {
        resolveService(storage: &_historyManager, provider: dependencies.makeHistoryManager)
    }

    var historyManagerConcrete: HistoryManager {
        resolveService(storage: &_historyManagerConcrete, provider: dependencies.makeHistoryManagerConcrete)
    }

    /// Quick Ask 服务
    var quickAsk: QuickAskServiceProtocol {
        resolveService(storage: &_quickAsk, provider: dependencies.makeQuickAsk)
    }

    var quickAskServiceConcrete: QuickAskService {
        resolveService(storage: &_quickAskServiceConcrete, provider: dependencies.makeQuickAskServiceConcrete)
    }

    var audioRecorderService: AudioRecorderService {
        resolveService(storage: &_audioRecorderService, provider: dependencies.makeAudioRecorderService)
    }

    var workspace: NSWorkspace {
        resolveService(storage: &_workspace, provider: dependencies.makeWorkspace)
    }

    var workflowConfigService: WorkflowConfigService {
        resolveService(storage: &_workflowConfigService, provider: dependencies.makeWorkflowConfigService)
    }

    var pasteboard: NSPasteboard {
        resolveService(storage: &_pasteboard, provider: dependencies.makePasteboard)
    }

    var contextService: ContextService {
        resolveService(storage: &_contextService, provider: dependencies.makeContextService)
    }

    var clipboardHistoryService: ClipboardHistoryService {
        resolveService(storage: &_clipboardHistoryService, provider: dependencies.makeClipboardHistoryService)
    }

    var clipboardPipelineService: ClipboardPipelineService {
        resolveService(storage: &_clipboardPipelineService, provider: dependencies.makeClipboardPipelineService)
    }

    var hotKeyService: HotKeyService {
        resolveService(storage: &_hotKeyService, provider: dependencies.makeHotKeyService)
    }

    var workflowState: WorkflowState {
        resolveService(storage: &_workflowState, provider: dependencies.makeWorkflowState)
    }

    var attachmentManager: AttachmentManager {
        resolveService(storage: &_attachmentManager, provider: dependencies.makeAttachmentManager)
    }

    var quickAskHUDManager: QuickAskHUDManager {
        resolveService(storage: &_quickAskHUDManager, provider: dependencies.makeQuickAskHUDManager)
    }

    var answerPanelManager: AnswerPanelManager {
        resolveService(storage: &_answerPanelManager, provider: dependencies.makeAnswerPanelManager)
    }

    var liveCaptionManager: LiveCaptionManager {
        resolveService(storage: &_liveCaptionManager, provider: dependencies.makeLiveCaptionManager)
    }

    var selectionMonitorService: SelectionMonitorService {
        resolveService(storage: &_selectionMonitorService, provider: dependencies.makeSelectionMonitorService)
    }

    var floatingHUDManager: FloatingHUDManager {
        resolveService(storage: &_floatingHUDManager, provider: dependencies.makeFloatingHUDManager)
    }

    var inputService: InputService {
        resolveService(storage: &_inputService, provider: dependencies.makeInputService)
    }

    var messagePanelManager: MessagePanelManager {
        resolveService(storage: &_messagePanelManager, provider: dependencies.makeMessagePanelManager)
    }

    var liveCaptionWindowManager: LiveCaptionWindowManager {
        resolveService(storage: &_liveCaptionWindowManager, provider: dependencies.makeLiveCaptionWindowManager)
    }

    var selectionToolbarState: SelectionToolbarState {
        resolveService(storage: &_selectionToolbarState, provider: dependencies.makeSelectionToolbarState)
    }

    var toolbarConfigService: ToolbarConfigService {
        resolveService(storage: &_toolbarConfigService, provider: dependencies.makeToolbarConfigService)
    }

    var ttsService: TTSService {
        resolveService(storage: &_ttsService, provider: dependencies.makeTTSService)
    }

    var screenOCR: ScreenOCRService {
        resolveService(storage: &_screenOCR, provider: dependencies.makeScreenOCR)
    }

    var dictionaryAPI: DictionaryAPIService {
        resolveService(storage: &_dictionaryAPI, provider: dependencies.makeDictionaryAPI)
    }

    var selectionToolbarManager: SelectionToolbarManager {
        resolveService(storage: &_selectionToolbarManager, provider: dependencies.makeSelectionToolbarManager)
    }

    var llmSettings: LLMSettings {
        resolveService(storage: &_llmSettings, provider: dependencies.makeLLMSettings)
    }

    // MARK: - Test Injection

    /// 注册自定义音频捕获服务（用于测试）
    func register(audioCapture: AudioCaptureServiceProtocol) {
        _audioCapture = audioCapture
    }

    /// 注册自定义转录服务（用于测试）
    func register(transcription: TranscriptionServiceProtocol) {
        _transcription = transcription
    }

    /// 注册自定义 LLM 服务（用于测试）
    func register(llm: LLMServiceProtocol) {
        _llm = llm
    }

    func register(llmPipeline: LLMPipeline) {
        _llmPipeline = llmPipeline
    }

    func register(workflowExecutor: WorkflowExecutor) {
        _workflowExecutor = workflowExecutor
    }

    /// 注册自定义应用设置服务（用于测试）
    func register(appSettings: AppSettingsProtocol) {
        _appSettings = appSettings
    }

    func register(appSettingsConcrete: AppSettings) {
        _appSettingsConcrete = appSettingsConcrete
    }

    /// 注册自定义历史记录服务（用于测试）
    func register(historyManager: HistoryManagerProtocol) {
        _historyManager = historyManager
    }

    func register(historyManagerConcrete: HistoryManager) {
        _historyManagerConcrete = historyManagerConcrete
    }

    /// 注册自定义 Quick Ask 服务（用于测试）
    func register(quickAsk: QuickAskServiceProtocol) {
        _quickAsk = quickAsk
    }

    func register(quickAskServiceConcrete: QuickAskService) {
        _quickAskServiceConcrete = quickAskServiceConcrete
    }

    func register(audioRecorderService: AudioRecorderService) {
        _audioRecorderService = audioRecorderService
    }

    func register(workspace: NSWorkspace) {
        _workspace = workspace
    }

    func register(workflowConfigService: WorkflowConfigService) {
        _workflowConfigService = workflowConfigService
    }

    func register(pasteboard: NSPasteboard) {
        _pasteboard = pasteboard
    }

    func register(contextService: ContextService) {
        _contextService = contextService
    }

    func register(clipboardHistoryService: ClipboardHistoryService) {
        _clipboardHistoryService = clipboardHistoryService
    }

    func register(clipboardPipelineService: ClipboardPipelineService) {
        _clipboardPipelineService = clipboardPipelineService
    }

    func register(hotKeyService: HotKeyService) {
        _hotKeyService = hotKeyService
    }

    func register(workflowState: WorkflowState) {
        _workflowState = workflowState
    }

    func register(attachmentManager: AttachmentManager) {
        _attachmentManager = attachmentManager
    }

    func register(quickAskHUDManager: QuickAskHUDManager) {
        _quickAskHUDManager = quickAskHUDManager
    }

    func register(answerPanelManager: AnswerPanelManager) {
        _answerPanelManager = answerPanelManager
    }

    func register(liveCaptionManager: LiveCaptionManager) {
        _liveCaptionManager = liveCaptionManager
    }

    func register(selectionMonitorService: SelectionMonitorService) {
        _selectionMonitorService = selectionMonitorService
    }

    func register(floatingHUDManager: FloatingHUDManager) {
        _floatingHUDManager = floatingHUDManager
    }

    func register(inputService: InputService) {
        _inputService = inputService
    }

    func register(messagePanelManager: MessagePanelManager) {
        _messagePanelManager = messagePanelManager
    }

    func register(liveCaptionWindowManager: LiveCaptionWindowManager) {
        _liveCaptionWindowManager = liveCaptionWindowManager
    }

    func register(selectionToolbarState: SelectionToolbarState) {
        _selectionToolbarState = selectionToolbarState
    }

    func register(toolbarConfigService: ToolbarConfigService) {
        _toolbarConfigService = toolbarConfigService
    }

    func register(ttsService: TTSService) {
        _ttsService = ttsService
    }

    func register(screenOCR: ScreenOCRService) {
        _screenOCR = screenOCR
    }

    func register(dictionaryAPI: DictionaryAPIService) {
        _dictionaryAPI = dictionaryAPI
    }

    func register(selectionToolbarManager: SelectionToolbarManager) {
        _selectionToolbarManager = selectionToolbarManager
    }

    func register(llmSettings: LLMSettings) {
        _llmSettings = llmSettings
    }

    /// 重置为默认服务
    func resetToDefaults() {
        _audioCapture = nil
        _transcription = nil
        _llm = nil
        _llmPipeline = nil
        _workflowExecutor = nil
        _appSettings = nil
        _appSettingsConcrete = nil
        _historyManager = nil
        _historyManagerConcrete = nil
        _quickAsk = nil
        _quickAskServiceConcrete = nil
        _audioRecorderService = nil
        _workspace = nil
        _workflowConfigService = nil
        _pasteboard = nil
        _contextService = nil
        _clipboardHistoryService = nil
        _clipboardPipelineService = nil
        _hotKeyService = nil
        _workflowState = nil
        _attachmentManager = nil
        _quickAskHUDManager = nil
        _answerPanelManager = nil
        _liveCaptionManager = nil
        _selectionMonitorService = nil
        _floatingHUDManager = nil
        _inputService = nil
        _messagePanelManager = nil
        _liveCaptionWindowManager = nil
        _selectionToolbarState = nil
        _toolbarConfigService = nil
        _ttsService = nil
        _screenOCR = nil
        _dictionaryAPI = nil
        _selectionToolbarManager = nil
        _llmSettings = nil
    }

    // MARK: - Init

    init() {
        self.dependencies = .live
    }

    private init(dependencies: ServiceContainerDependencies) {
        self.dependencies = dependencies
    }

    private func resolveService<Service>(
        storage: inout Service?,
        provider: () -> Service
    ) -> Service {
        if let service = storage {
            return service
        }
        let service = provider()
        storage = service
        return service
    }
}

// MARK: - SwiftUI Environment Integration

private struct ServiceContainerKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ServiceContainer.shared
}

extension EnvironmentValues {
    /// 服务容器环境值
    var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

extension View {
    /// 注入自定义服务容器（用于 Preview 和测试）
    func withServiceContainer(_ container: ServiceContainer) -> some View {
        environment(\.services, container)
    }
}

@MainActor
func currentServiceContainer() -> ServiceContainer {
    ServiceContainer.shared
}

// MARK: - Protocol Conformance

// 让现有服务遵循协议
extension AudioRecorderService: AudioCaptureServiceProtocol {}
extension TranscriptionManager: TranscriptionServiceProtocol {}
extension LLMPipeline: LLMServiceProtocol {}
extension AppSettings: AppSettingsProtocol {}
extension HistoryManager: HistoryManagerProtocol {}
extension QuickAskService: QuickAskServiceProtocol {}
