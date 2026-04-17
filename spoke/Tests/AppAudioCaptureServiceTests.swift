@preconcurrency import ScreenCaptureKit
import Testing
@testable import SpokenAnyWhere

@available(macOS 14.0, *)
@MainActor
private final class FakeContentSharingPicker: AppAudioCapturePickerProtocol {
    var defaultConfiguration = SCContentSharingPickerConfiguration()
    var isActive = false
    var addObserverCalls = 0
    var presentCalls = 0
    var presentForStreamCalls = 0

    func add(_ observer: any SCContentSharingPickerObserver) {
        addObserverCalls += 1
    }

    func present() {
        presentCalls += 1
    }

    func present(for stream: SCStream) {
        presentForStreamCalls += 1
    }
}

@Suite("AppAudioCaptureService 测试")
struct AppAudioCaptureServiceTests {

    @Test("初始化 AppAudioCaptureService 不会自动激活 picker")
    @MainActor
    func initDoesNotActivatePicker() {
        if #available(macOS 14.0, *) {
            let picker = FakeContentSharingPicker()

            _ = AppAudioCaptureService.makeTesting(
                dependencies: .init(picker: picker)
            )

            #expect(picker.addObserverCalls == 1)
            #expect(picker.isActive == false)
        } else {
            #expect(Bool(true))
        }
    }

    @Test("presentPicker 才会激活 picker")
    @MainActor
    func presentPickerActivatesPicker() {
        if #available(macOS 14.0, *) {
            let picker = FakeContentSharingPicker()
            let service = AppAudioCaptureService.makeTesting(
                dependencies: .init(picker: picker)
            )

            service.presentPicker()

            #expect(picker.isActive)
            #expect(picker.addObserverCalls == 1)
            #expect(picker.presentCalls == 1)
        } else {
            #expect(Bool(true))
        }
    }

    @Test("reselectApp 会激活 picker")
    @MainActor
    func reselectAppActivatesPicker() {
        if #available(macOS 14.0, *) {
            let picker = FakeContentSharingPicker()
            let service = AppAudioCaptureService.makeTesting(
                dependencies: .init(picker: picker)
            )

            service.reselectApp()

            #expect(picker.isActive)
            #expect(picker.addObserverCalls == 1)
            #expect(picker.presentCalls == 1)
        } else {
            #expect(Bool(true))
        }
    }
}
