import AppKit
import Foundation

@MainActor
struct SelectionActionLiveServices {
    let serviceContainer: ServiceContainer

    static let shared = SelectionActionLiveServices(serviceContainer: .shared)

    var state: SelectionToolbarState { serviceContainer.selectionToolbarState }
    var ttsService: TTSService { serviceContainer.ttsService }
    var screenOCR: ScreenOCRService { serviceContainer.screenOCR }
    var llmPipeline: LLMPipeline { serviceContainer.llmPipeline }
    var dictionaryAPI: DictionaryAPIService { serviceContainer.dictionaryAPI }
    var selectionToolbarManager: SelectionToolbarManager { serviceContainer.selectionToolbarManager }
    var answerPanelManager: AnswerPanelManager { serviceContainer.answerPanelManager }
    var llmSettings: LLMSettings { serviceContainer.llmSettings }
}

func copySelectionActionTextToPasteboard(
    _ text: String,
    pasteboard: NSPasteboard
) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

func scheduleSelectionActionToolbarHide(
    _ manager: SelectionToolbarManager,
    delay: TimeInterval
) {
    runSelectionToolbarAfterDelay(seconds: delay) {
        manager.hide()
    }
}
