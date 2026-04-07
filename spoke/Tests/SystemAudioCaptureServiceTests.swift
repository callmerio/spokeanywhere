import Testing
@testable import SpokenAnyWhere

@Suite("SystemAudioCaptureService 测试")
struct SystemAudioCaptureServiceTests {

    @Test("权限检查保持保守返回 true")
    @MainActor
    func permissionCheckRemainsConservative() {
        if #available(macOS 12.3, *) {
            #expect(Bool(SystemAudioCaptureService.checkScreenCapturePermission()))
        } else {
            #expect(Bool(true))
        }
    }
}
