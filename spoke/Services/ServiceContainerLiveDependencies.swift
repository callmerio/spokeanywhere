import AppKit
import Foundation

@MainActor
extension ServiceContainerDependencies {
    static let live = ServiceContainerDependencies(
        makeAudioCapture: { AudioRecorderService.shared },
        makeTranscription: { TranscriptionManager.shared },
        makeLLM: { LLMPipeline.shared },
        makeLLMPipeline: { LLMPipeline.shared },
        makeWorkflowExecutor: { WorkflowExecutor.shared },
        makeAppSettings: { AppSettings.shared },
        makeAppSettingsConcrete: { AppSettings.shared },
        makeHistoryManager: { HistoryManager.shared },
        makeHistoryManagerConcrete: { HistoryManager.shared },
        makeQuickAsk: { QuickAskService.shared },
        makeQuickAskServiceConcrete: { QuickAskService.shared },
        makeAudioRecorderService: { AudioRecorderService.shared },
        makeWorkspace: { .shared },
        makeWorkflowConfigService: { WorkflowConfigService.shared },
        makePasteboard: { .general },
        makeContextService: { ContextService.shared },
        makeClipboardHistoryService: { ClipboardHistoryService.shared },
        makeClipboardPipelineService: { ClipboardPipelineService.shared },
        makeHotKeyService: { HotKeyService.shared },
        makeWorkflowState: { WorkflowState.shared },
        makeAttachmentManager: { AttachmentManager.shared },
        makeQuickAskHUDManager: { QuickAskHUDManager.shared },
        makeAnswerPanelManager: { AnswerPanelManager.shared },
        makeLiveCaptionManager: { LiveCaptionManager.shared },
        makeSelectionMonitorService: { SelectionMonitorService.shared },
        makeFloatingHUDManager: { FloatingHUDManager.shared },
        makeInputService: { InputService.shared },
        makeMessagePanelManager: { MessagePanelManager.shared },
        makeLiveCaptionWindowManager: { LiveCaptionWindowManager.shared },
        makeSelectionToolbarState: { SelectionToolbarState.shared },
        makeToolbarConfigService: { ToolbarConfigService.shared },
        makeTTSService: { TTSService.shared },
        makeScreenOCR: { ScreenOCRService.shared },
        makeDictionaryAPI: { DictionaryAPIService.shared },
        makeSelectionToolbarManager: { SelectionToolbarManager.shared },
        makeLLMSettings: { LLMSettings.shared }
    )
}
