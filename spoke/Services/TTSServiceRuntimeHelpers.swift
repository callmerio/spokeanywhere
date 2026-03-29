import Foundation

func runTTSServiceOnMain(
    _ service: TTSService?,
    _ action: @escaping @MainActor (TTSService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}

func runTTSServiceAsync(
    _ service: TTSService?,
    _ action: @escaping @MainActor (TTSService) async -> Void
) {
    runtimeRunOnMainAsync(owner: service, action)
}

func makeTTSServiceTask(
    owner: TTSService,
    _ action: @escaping @MainActor (TTSService) async -> Void
) -> Task<Void, Never> {
    runtimeMakeMainActorTask(owner: owner, action)
}
