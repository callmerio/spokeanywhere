import Foundation

func scheduleMessageBubbleMain(
    after seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(after: seconds, operation)
}

@MainActor
struct MessageBubbleViewDependencies {
    let ttsService: TTSService
}
