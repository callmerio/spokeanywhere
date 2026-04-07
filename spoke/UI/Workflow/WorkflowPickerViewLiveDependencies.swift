@MainActor
extension WorkflowPickerViewDependencies {
    static let live: WorkflowPickerViewDependencies = {
        let services = currentServiceContainer()
        let configService = services.workflowConfigService
        let workflowState = services.workflowState

        return WorkflowPickerViewDependencies(
            workflowState: workflowState,
            search: { keyword in
                configService.search(keyword: keyword)
            },
            groupedWorkflows: { filter in
                configService.groupedWorkflows(filter: filter)
            }
        )
    }()
}
