import AppKit
import Foundation

@MainActor
struct RecordingControllerLiveServices {
    let serviceContainer: ServiceContainer

    var hudManager: FloatingHUDManager { serviceContainer.floatingHUDManager }
    var contextService: ContextService { serviceContainer.contextService }
    var hotKeyService: HotKeyService { serviceContainer.hotKeyService }
    var audioService: AudioRecorderService { serviceContainer.audioRecorderService }
    var inputService: InputService { serviceContainer.inputService }
    var settings: AppSettings { serviceContainer.appSettingsConcrete }
    var llmSettings: LLMSettings { serviceContainer.llmSettings }
    var llmPipeline: LLMPipeline { serviceContainer.llmPipeline }
    var historyManager: HistoryManager { serviceContainer.historyManagerConcrete }
    var quickAskService: QuickAskService { serviceContainer.quickAskServiceConcrete }
    var screenOCR: ScreenOCRService { serviceContainer.screenOCR }
    var messagePanelManager: MessagePanelManager { serviceContainer.messagePanelManager }
    var liveCaptionWindowManager: LiveCaptionWindowManager { serviceContainer.liveCaptionWindowManager }
    var clipboardPipelineService: ClipboardPipelineService { serviceContainer.clipboardPipelineService }
    var pasteboard: NSPasteboard { serviceContainer.pasteboard }
}

@MainActor
func currentRecordingControllerLiveServices() -> RecordingControllerLiveServices {
    RecordingControllerLiveServices(serviceContainer: currentServiceContainer())
}

@MainActor
extension RecordingControllerDependencies {
    static func makeLive() -> Self {
        let services = currentRecordingControllerLiveServices()
        return .init(
            hudManager: services.hudManager,
            contextService: services.contextService,
            hotKeyService: services.hotKeyService,
            audioService: services.audioService,
            inputService: services.inputService,
            settings: services.settings,
            llmSettings: services.llmSettings,
            llmPipeline: services.llmPipeline,
            historyManager: services.historyManager,
            quickAskService: services.quickAskService,
            screenOCR: services.screenOCR,
            messagePanelManager: services.messagePanelManager,
            liveCaptionWindowManager: services.liveCaptionWindowManager,
            clipboardPipelineService: services.clipboardPipelineService,
            copyToClipboard: { text in
                let pasteboard = services.pasteboard
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
            },
            openSettings: {
                triggerRecordingControllerOpenSettings()
            }
        )
    }
}
