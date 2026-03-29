import Foundation

typealias ToolbarConfigAsyncTask = Task<Void, Never>

func makeToolbarConfigSaveTask(
    owner: ToolbarConfigService,
    delayNs: UInt64 = 300_000_000,
    action: @escaping @MainActor (ToolbarConfigService) -> Void
) -> ToolbarConfigAsyncTask {
    runtimeMakeDelayedTask(delayNs: delayNs, owner: owner, action)
}
