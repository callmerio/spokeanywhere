import Foundation

func runAudioPlayerOnMain(
    _ service: AudioPlayerService?,
    _ action: @escaping @MainActor (AudioPlayerService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}

func makeAudioPlayerProgressTimer(
    owner: AudioPlayerService,
    action: @escaping @MainActor (AudioPlayerService) -> Void
) -> Timer {
    runtimeMakeOwnedTimer(
        interval: 0.1,
        repeats: true,
        owner: owner,
        action: action
    )
}
