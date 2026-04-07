@preconcurrency import ScreenCaptureKit
import Testing
@testable import SpokenAnyWhere

@Suite("AppAudioCaptureService 测试")
struct AppAudioCaptureServiceTests {

    @Test("权限检查保持保守返回 true，由实际调用点处理错误")
    @MainActor
    func liveDependenciesRemainAvailable() {
        if #available(macOS 14.0, *) {
            let dependencies = AppAudioCaptureServiceDependencies.live
            #expect(Bool(dependencies.picker === SCContentSharingPicker.shared))
        } else {
            #expect(Bool(true))
        }
    }
}
