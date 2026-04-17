import Foundation
@preconcurrency import ScreenCaptureKit

@available(macOS 14.0, *)
struct AppAudioCaptureServiceDependencies {
    let picker: AppAudioCapturePickerProtocol
}

@available(macOS 14.0, *)
@MainActor
final class ScreenContentSharingPickerAdapter: AppAudioCapturePickerProtocol {
    private let picker: SCContentSharingPicker

    init(picker: SCContentSharingPicker) {
        self.picker = picker
    }

    var defaultConfiguration: SCContentSharingPickerConfiguration {
        get { picker.defaultConfiguration }
        set { picker.defaultConfiguration = newValue }
    }

    var isActive: Bool {
        get { picker.isActive }
        set { picker.isActive = newValue }
    }

    func add(_ observer: any SCContentSharingPickerObserver) {
        picker.add(observer)
    }

    func present() {
        picker.present()
    }

    func present(for stream: SCStream) {
        picker.present(for: stream)
    }
}

@available(macOS 14.0, *)
@MainActor
extension AppAudioCaptureServiceDependencies {
    static let live = AppAudioCaptureServiceDependencies(
        picker: ScreenContentSharingPickerAdapter(picker: SCContentSharingPicker.shared)
    )
}
