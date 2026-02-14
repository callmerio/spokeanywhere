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

    static let shared = ServiceContainer()

    // MARK: - Private Storage

    private var _audioCapture: AudioCaptureServiceProtocol?
    private var _transcription: TranscriptionServiceProtocol?
    private var _llm: LLMServiceProtocol?
    private var _appSettings: AppSettingsProtocol?
    private var _historyManager: HistoryManagerProtocol?
    private var _quickAsk: QuickAskServiceProtocol?

    // MARK: - Lazy Service Access

    /// 音频捕获服务
    var audioCapture: AudioCaptureServiceProtocol {
        if let service = _audioCapture {
            return service
        }
        let service = AudioRecorderService.shared
        _audioCapture = service
        return service
    }

    /// 转录服务
    var transcription: TranscriptionServiceProtocol {
        if let service = _transcription {
            return service
        }
        let service = TranscriptionManager.shared
        _transcription = service
        return service
    }

    /// LLM 服务
    var llm: LLMServiceProtocol {
        if let service = _llm {
            return service
        }
        let service = LLMPipeline.shared
        _llm = service
        return service
    }

    /// 应用设置服务
    var appSettings: AppSettingsProtocol {
        if let service = _appSettings {
            return service
        }
        let service = AppSettings.shared
        _appSettings = service
        return service
    }

    /// 历史记录服务
    var historyManager: HistoryManagerProtocol {
        if let service = _historyManager {
            return service
        }
        let service = HistoryManager.shared
        _historyManager = service
        return service
    }

    /// Quick Ask 服务
    var quickAsk: QuickAskServiceProtocol {
        if let service = _quickAsk {
            return service
        }
        let service = QuickAskService.shared
        _quickAsk = service
        return service
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

    /// 注册自定义应用设置服务（用于测试）
    func register(appSettings: AppSettingsProtocol) {
        _appSettings = appSettings
    }

    /// 注册自定义历史记录服务（用于测试）
    func register(historyManager: HistoryManagerProtocol) {
        _historyManager = historyManager
    }

    /// 注册自定义 Quick Ask 服务（用于测试）
    func register(quickAsk: QuickAskServiceProtocol) {
        _quickAsk = quickAsk
    }

    /// 重置为默认服务
    func resetToDefaults() {
        _audioCapture = nil
        _transcription = nil
        _llm = nil
        _appSettings = nil
        _historyManager = nil
        _quickAsk = nil
    }

    // MARK: - Init

    private init() {}
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

// MARK: - Protocol Conformance

// 让现有服务遵循协议
extension AudioRecorderService: AudioCaptureServiceProtocol {}
extension TranscriptionManager: TranscriptionServiceProtocol {}
extension LLMPipeline: LLMServiceProtocol {}
extension AppSettings: AppSettingsProtocol {}
extension HistoryManager: HistoryManagerProtocol {}
extension QuickAskService: QuickAskServiceProtocol {}
