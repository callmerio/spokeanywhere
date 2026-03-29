import Foundation
@preconcurrency import ScreenCaptureKit

@available(macOS 14.0, *)
struct AppAudioCaptureServiceDependencies {
    let picker: SCContentSharingPicker
}

@available(macOS 14.0, *)
@MainActor
extension AppAudioCaptureServiceDependencies {
    static let live = AppAudioCaptureServiceDependencies(
        picker: SCContentSharingPicker.shared
    )
}
