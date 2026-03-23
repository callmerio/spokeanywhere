import AppKit
import Foundation

@MainActor
struct WorkflowExecutorLiveServices {
    let serviceContainer: ServiceContainer

    static let shared = WorkflowExecutorLiveServices(serviceContainer: currentServiceContainer())

    var settings: LLMSettings { serviceContainer.llmSettings }
    var pipeline: LLMPipeline { serviceContainer.llmPipeline }
    var workflowConfigService: WorkflowConfigService { serviceContainer.workflowConfigService }
    var pasteboard: NSPasteboard { serviceContainer.pasteboard }
}
