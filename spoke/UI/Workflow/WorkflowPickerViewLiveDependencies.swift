@MainActor
extension WorkflowPickerViewDependencies {
    static let live: WorkflowPickerViewDependencies = {
        let configService = WorkflowConfigService.shared
        let workflowState = WorkflowState.shared

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
