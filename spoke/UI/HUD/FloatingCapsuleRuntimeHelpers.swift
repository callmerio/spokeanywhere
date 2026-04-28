import CoreGraphics
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

func floatingCapsuleShouldUpdateMeasuredHeight(
    currentHeight: CGFloat,
    newHeight: CGFloat,
    tolerance: CGFloat = 0.5
) -> Bool {
    abs(currentHeight - newHeight) > tolerance
}
