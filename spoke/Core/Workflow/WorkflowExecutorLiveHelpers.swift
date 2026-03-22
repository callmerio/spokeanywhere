import AppKit
import Foundation

@MainActor
struct WorkflowExecutorLiveServices {
    let settings: LLMSettings
    let pipeline: LLMPipeline
    let workflowConfigService: WorkflowConfigService
    let pasteboard: NSPasteboard
    let dateProvider: () -> Date
    let localeProvider: () -> Locale

    static let shared = WorkflowExecutorLiveServices(
        settings: .shared,
        pipeline: .shared,
        workflowConfigService: .shared,
        pasteboard: .general,
        dateProvider: Date.init,
        localeProvider: { .current }
    )
}
