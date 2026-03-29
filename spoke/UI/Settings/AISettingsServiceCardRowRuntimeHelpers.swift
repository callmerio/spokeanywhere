import Foundation

func scheduleAISettingsServiceCardRowMain(
    after seconds: Double,
    _ operation: @escaping @MainActor () -> Void
) {
    runtimeRunOnMain(after: seconds, operation)
}
