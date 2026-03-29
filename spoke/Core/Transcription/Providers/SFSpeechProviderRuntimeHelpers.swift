import Foundation

func runSFSpeechProviderOnMain(
    _ provider: SFSpeechProvider?,
    _ action: @escaping @MainActor (SFSpeechProvider) -> Void
) {
    runtimeRunOnMain(owner: provider, action)
}
