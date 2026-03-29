import Foundation

@available(macOS 12.3, *)
func runScreenCaptureBlurAsync(
    _ service: ScreenCaptureBlurService?,
    _ action: @escaping @MainActor (ScreenCaptureBlurService) async -> Void
) {
    runtimeRunOnMainAsync(owner: service, action)
}

@available(macOS 12.3, *)
func runScreenCaptureBlurOnMain(
    _ service: ScreenCaptureBlurService?,
    _ action: @escaping @MainActor (ScreenCaptureBlurService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}
