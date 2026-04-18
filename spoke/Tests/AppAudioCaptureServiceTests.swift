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

@available(macOS 14.0, *)
private enum PickerTestError: Error, Equatable {
    case startFailed
}

@Suite("AppAudioCaptureService 测试")
struct AppAudioCaptureServiceTests {

    @MainActor
    private func waitUntil(
        _ description: String,
        attempts: Int = 20,
        sleepNs: UInt64 = 10_000_000,
        predicate: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<attempts {
            if predicate() {
                return
            }
            try? await Task.sleep(nanoseconds: sleepNs)
        }

        Issue.record(Comment(rawValue: description))
    }

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

    @Test("stopCapture 会撤回 picker 活跃状态并清空等待状态")
    @MainActor
    func stopCaptureResetsPickerActivity() async {
        if #available(macOS 14.0, *) {
            let picker = FakeContentSharingPicker()
            picker.isActive = true

            let service = AppAudioCaptureService.makeTesting(
                dependencies: .init(picker: picker)
            )

            service.presentPicker()
            service.testingSetCaptureState(
                isCapturing: true,
                isRetrying: false,
                currentAppName: "Existing App"
            )
            await service.stopCapture()

            #expect(picker.isActive == false)
            #expect(service.isWaitingForSelection == false)
            #expect(service.isRetrying == false)
            #expect(service.currentAppName == nil)
        } else {
            #expect(Bool(true))
        }
    }

    @Test("用户取消应用选择后会撤回 picker 活跃状态")
    @MainActor
    func cancelSelectionDeactivatesPicker() async {
        if #available(macOS 14.0, *) {
            let picker = FakeContentSharingPicker()
            let service = AppAudioCaptureService.makeTesting(
                dependencies: .init(picker: picker)
            )
            var didCancel = false

            service.presentPicker()
            service.onSelectionCancelled = {
                didCancel = true
            }
            service.contentSharingPicker(
                SCContentSharingPicker.shared,
                didCancelFor: nil
            )

            await waitUntil(
                "expected cancel callback to deactivate picker and clear waiting state"
            ) {
                picker.isActive == false &&
                service.isWaitingForSelection == false &&
                didCancel
            }

            #expect(picker.isActive == false)
            #expect(service.isWaitingForSelection == false)
            #expect(didCancel)
        } else {
            #expect(Bool(true))
        }
    }

    @Test("成功选择应用后会撤回 picker 活跃状态并记录应用名")
    @MainActor
    func successfulPickerUpdateDeactivatesPicker() async {
        if #available(macOS 14.0, *) {
            let picker = FakeContentSharingPicker()
            let service = AppAudioCaptureService.makeTesting(
                dependencies: .init(picker: picker)
            )
            var selectionCompleted = false

            service.onSelectionComplete = { success in
                selectionCompleted = success
            }
            service.presentPicker()

            await service.testingHandlePickerUpdate(appName: "Selected App") {
                // No-op: test only cares that success path performs state cleanup.
            }

            #expect(picker.isActive == false)
            #expect(service.isWaitingForSelection == false)
            #expect(service.currentAppName == "Selected App")
            #expect(selectionCompleted)
        } else {
            #expect(Bool(true))
        }
    }

    @Test("picker 启动失败后会撤活并回调错误")
    @MainActor
    func pickerStartFailureDeactivatesPickerAndReportsError() async {
        if #available(macOS 14.0, *) {
            let picker = FakeContentSharingPicker()
            let service = AppAudioCaptureService.makeTesting(
                dependencies: .init(picker: picker)
            )
            var receivedError: PickerTestError?

            service.presentPicker()
            service.onError = { error in
                receivedError = error as? PickerTestError
            }
            service.contentSharingPickerStartDidFailWithError(PickerTestError.startFailed)

            await waitUntil(
                "expected picker start failure to deactivate picker, clear waiting state, and report error"
            ) {
                picker.isActive == false &&
                service.isWaitingForSelection == false &&
                receivedError == .startFailed
            }

            #expect(picker.isActive == false)
            #expect(service.isWaitingForSelection == false)
            #expect(receivedError == .startFailed)
        } else {
            #expect(Bool(true))
        }
    }
}
