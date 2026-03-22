import AppKit
import Foundation

@MainActor
struct SelectionActionLiveServices {
    let state: SelectionToolbarState
    let ttsService: TTSService
    let screenOCR: ScreenOCRService
    let llmPipeline: LLMPipeline
    let dictionaryAPI: DictionaryAPIService
    let selectionToolbarManager: SelectionToolbarManager
    let answerPanelManager: AnswerPanelManager
    let llmSettings: LLMSettings

    static let shared = SelectionActionLiveServices(
        state: .shared,
        ttsService: .shared,
        screenOCR: .shared,
        llmPipeline: .shared,
        dictionaryAPI: .shared,
        selectionToolbarManager: .shared,
        answerPanelManager: .shared,
        llmSettings: .shared
    )
}

func copySelectionActionTextToPasteboard(
    _ text: String,
    pasteboard: NSPasteboard = .general
) {
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
}

func scheduleSelectionActionToolbarHide(
    _ manager: SelectionToolbarManager,
    delay: TimeInterval
) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        manager.hide()
    }
}
