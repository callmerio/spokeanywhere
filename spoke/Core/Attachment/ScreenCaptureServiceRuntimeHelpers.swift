import Foundation

func runScreenCaptureServiceOnMain(
    _ service: ScreenCaptureService?,
    _ action: @escaping @MainActor (ScreenCaptureService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}
