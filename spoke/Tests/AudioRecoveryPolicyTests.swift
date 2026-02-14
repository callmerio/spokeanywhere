import AVFoundation
import Testing
@testable import SpokenAnyWhere

@Suite("AudioRecoveryPolicy 边界测试")
struct AudioRecoveryPolicyTests {

    private let policy = AudioRecoveryPolicy()

    @Test("无输入设备时应快速失败，避免恢复重试风暴")
    func noInputDeviceFailsFast() {
        let decision = policy.configurationChangeDecision(
            isRecording: true,
            permissionStatus: .authorized,
            hasInputDevice: false
        )

        #expect(decision == .fail(.noInputDevice))
    }

    @Test("配置变化在可恢复条件下应进入恢复流程")
    func recoverableConfigurationChangeAttemptsRecovery() {
        let decision = policy.configurationChangeDecision(
            isRecording: true,
            permissionStatus: .authorized,
            hasInputDevice: true
        )

        #expect(decision == .attemptRecovery)
    }

    @Test("权限边界应走可解释失败而非继续重试")
    func permissionEdgeFallsBackGracefully() {
        let deniedDecision = policy.configurationChangeDecision(
            isRecording: true,
            permissionStatus: .denied,
            hasInputDevice: true
        )
        #expect(deniedDecision == .fail(.permissionDenied))

        let notRecordingDecision = policy.configurationChangeDecision(
            isRecording: false,
            permissionStatus: .authorized,
            hasInputDevice: true
        )
        #expect(notRecordingDecision == .ignore)
    }
}
