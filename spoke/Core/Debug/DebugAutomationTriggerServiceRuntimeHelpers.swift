#if DEBUG
import Foundation

func runDebugAutomationTriggerOnMain(
    _ service: DebugAutomationTriggerService?,
    _ action: @escaping @MainActor (DebugAutomationTriggerService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}
#endif
