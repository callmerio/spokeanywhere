import Foundation

func scheduleFloatingCapsuleWorkItem(
    after seconds: Double,
    _ workItem: DispatchWorkItem
) {
    runtimeRunOnMain(after: seconds) {
        guard !workItem.isCancelled else { return }
        workItem.perform()
    }
}
