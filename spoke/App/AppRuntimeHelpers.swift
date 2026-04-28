import Foundation

@MainActor
enum AppDebugLaunchContext {
    static var liveCaptionMockScenarioActive = false
    static var liveCaptionMockScenarioName: String?
}

@MainActor
func appShouldSkipSpeechPreparationForMockScenario(
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> Bool {
    AppDebugLaunchContext.liveCaptionMockScenarioActive || liveCaptionMockScenarioFromEnvironment(environment) != nil
}

@MainActor
func appShouldEagerResolveQuickAskService(
    environment: [String: String] = ProcessInfo.processInfo.environment
) -> Bool {
    !appShouldSkipSpeechPreparationForMockScenario(environment: environment)
}

func runAppMainActorAsync(
    _ operation: @escaping @MainActor () async -> Void
) {
    runtimeRunOnMainAsync(operation)
}

func runAppMainActor(
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(operation)
}

func runAppDelegateUtilityTask(
    _ delegate: AppDelegate?,
    _ operation: @escaping @MainActor (AppDelegate) async -> Void
) {
    Task(priority: .utility) { @MainActor [weak delegate] in
        guard let delegate else { return }
        await operation(delegate)
    }
}

func runAppDetached(
    priority: TaskPriority = .background,
    _ operation: @escaping @Sendable () async -> Void
) {
    Task.detached(priority: priority) {
        await operation()
    }
}
