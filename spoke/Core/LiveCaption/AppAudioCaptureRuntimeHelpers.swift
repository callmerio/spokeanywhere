import AVFoundation
import Foundation

@available(macOS 14.0, *)
func runAppAudioCaptureOnMain(
    _ service: AppAudioCaptureService?,
    _ action: @escaping @MainActor (AppAudioCaptureService) -> Void
) {
    runtimeRunOnMain(owner: service, action)
}

@available(macOS 14.0, *)
func runAppAudioCaptureAsync(
    _ service: AppAudioCaptureService?,
    _ action: @escaping @MainActor (AppAudioCaptureService) async -> Void
) {
    runtimeRunOnMainAsync(owner: service, action)
}

@available(macOS 14.0, *)
func makeAppAudioCaptureRetryTask(
    delay: TimeInterval,
    service: AppAudioCaptureService,
    action: @escaping @MainActor (AppAudioCaptureService) async -> Void
) -> Task<Void, Never> {
    Task {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await action(service)
    }
}

@available(macOS 14.0, *)
func deliverAppAudioPCMBuffer(
    _ buffer: AVAudioPCMBuffer,
    to service: AppAudioCaptureService?
) {
    runAppAudioCaptureOnMain(service) { capture in
        capture.onPCMBuffer?(buffer)
    }
}
