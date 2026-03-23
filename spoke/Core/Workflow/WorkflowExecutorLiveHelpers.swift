import AppKit
import Foundation

@MainActor
struct WorkflowExecutorLiveServices {
    let serviceContainer: ServiceContainer

    static let shared = WorkflowExecutorLiveServices(serviceContainer: .shared)

    var settings: LLMSettings { serviceContainer.llmSettings }
    var pipeline: LLMPipeline { serviceContainer.llm as! LLMPipeline }
    var workflowConfigService: WorkflowConfigService { serviceContainer.workflowConfigService }
    var pasteboard: NSPasteboard { serviceContainer.pasteboard }
}
