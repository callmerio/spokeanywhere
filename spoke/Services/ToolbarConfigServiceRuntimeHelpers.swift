import Foundation

typealias ToolbarConfigAsyncTask = Task<Void, Never>

func makeToolbarConfigSaveTask(
    owner: ToolbarConfigService,
    delayNs: UInt64 = 300_000_000,
    action: @escaping @MainActor (ToolbarConfigService) -> Void
) -> ToolbarConfigAsyncTask {
    Task { [weak owner] in
        try? await Task.sleep(nanoseconds: delayNs)
        guard !Task.isCancelled else { return }
        guard let owner else { return }
        await MainActor.run {
            action(owner)
        }
    }
}
