import Foundation

typealias WorkflowConfigAsyncTask = Task<Void, Never>

func makeWorkflowConfigSaveTask(
    owner: WorkflowConfigService,
    delayNs: UInt64 = 300_000_000,
    action: @escaping @MainActor (WorkflowConfigService) -> Void
) -> WorkflowConfigAsyncTask {
    Task { [weak owner] in
        try? await Task.sleep(nanoseconds: delayNs)
        guard !Task.isCancelled else { return }
        guard let owner else { return }
        await MainActor.run {
            action(owner)
        }
    }
}
