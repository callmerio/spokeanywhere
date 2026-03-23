import AppKit
import Foundation

@MainActor
struct QuickAskLiveServices {
    let serviceContainer: ServiceContainer

    var hotKeyService: HotKeyService { serviceContainer.hotKeyService }
    var workflowState: WorkflowState { serviceContainer.workflowState }
    var attachmentManager: AttachmentManager { serviceContainer.attachmentManager }
    var answerPanelManager: AnswerPanelManager { serviceContainer.answerPanelManager }
    var contextService: ContextService { serviceContainer.contextService }
    var llmPipeline: LLMPipeline { serviceContainer.llmPipeline }
    var workflowExecutor: WorkflowExecutor { serviceContainer.workflowExecutor }
    var llmSettings: LLMSettings { serviceContainer.llmSettings }
    var screenOCRService: ScreenOCRService { serviceContainer.screenOCR }
    var clipboardHistoryService: ClipboardHistoryService { serviceContainer.clipboardHistoryService }
    var liveCaptionManager: LiveCaptionManager { serviceContainer.liveCaptionManager }
    var quickAskHUDManager: QuickAskHUDManager { serviceContainer.quickAskHUDManager }
    var audioRecorderService: AudioRecorderService { serviceContainer.audioRecorderService }
    var pasteboard: NSPasteboard { serviceContainer.pasteboard }
}

@MainActor
func currentQuickAskLiveServices() -> QuickAskLiveServices {
    QuickAskLiveServices(serviceContainer: currentServiceContainer())
}

@MainActor
extension QuickAskHUDManagerDependencies {
    static func makeLive(answerPanelManager: AnswerPanelManager) -> Self {
        let services = currentQuickAskLiveServices()
        let hotKeyService = services.hotKeyService
        return .init(
            hotKeyService: hotKeyService,
            workflowState: services.workflowState,
            attachmentManager: services.attachmentManager,
            notificationCenter: .default,
            windowRuntime: QuickAskHUDWindowRuntime(
                setQuickAskActive: { hotKeyService.setQuickAskActive($0) },
                setDebugKeyEvents: { hotKeyService.debugKeyEvents = $0 },
                setActivationPolicy: { NSApp.setActivationPolicy($0) },
                activateApp: { NSApp.activate(ignoringOtherApps: true) },
                promotePanel: { panel in
                    panel.makeKeyAndOrderFront(nil)
                    panel.makeMain()
                }
            ),
            clipboardText: { services.pasteboard.string(forType: .string) },
            showAnswerPanel: { answerPanelManager.show(question: $0, attachments: $1) },
            updateAnswer: { answerPanelManager.updateAnswer($0, for: $1) },
            showAnswerError: { answerPanelManager.showError($0, for: $1) },
            executeWorkflow: { workflow, context in
                await services.workflowExecutor.execute(workflow, context: context)
            },
            openSettings: {
                triggerQuickAskOpenSettings()
            }
        )
    }
}

@MainActor
extension QuickAskServiceDependencies {
    static func makeLive() -> Self {
        let services = currentQuickAskLiveServices()
        return .init(
            hudManager: services.quickAskHUDManager,
            contextService: services.contextService,
            audioService: services.audioRecorderService,
            llmPipeline: services.llmPipeline,
            llmSettings: services.llmSettings,
            screenOCRService: services.screenOCRService,
            answerPanelManager: services.answerPanelManager,
            hotKeyService: services.hotKeyService,
            clipboardHistoryService: services.clipboardHistoryService,
            liveCaptionManager: services.liveCaptionManager,
            notificationCenter: .default
        )
    }
}
