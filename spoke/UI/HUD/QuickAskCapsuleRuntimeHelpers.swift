import Foundation

func runQuickAskCapsuleWorkflow(
    workflow: WorkflowAction,
    context: WorkflowContext,
    panelId: UUID,
    state: QuickAskState,
    dependencies: QuickAskCapsuleViewDependencies
) {
    runtimeRunAsync {
        let result = await dependencies.executeWorkflow(workflow, context)
        await MainActor.run {
            switch result {
            case .success(let response):
                dependencies.updateAnswer(response, panelId)
            case .failure(let error):
                dependencies.showAnswerError(error.localizedDescription, panelId)
            }
            state.reset()
        }
    }
}
