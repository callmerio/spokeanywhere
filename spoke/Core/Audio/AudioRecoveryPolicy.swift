import AVFoundation

/// 配置变化时的恢复决策
enum AudioConfigurationRecoveryDecision: Equatable {
    case ignore
    case attemptRecovery
    case fail(AudioRecorderError)
}

/// 音频恢复策略（纯逻辑，可直接单测）
struct AudioRecoveryPolicy {

    func startRecordingPreconditionError(
        permissionStatus: AVAuthorizationStatus,
        hasInputDevice: Bool
    ) -> AudioRecorderError? {
        guard permissionStatus == .authorized else {
            return .permissionDenied
        }

        guard hasInputDevice else {
            return .noInputDevice
        }

        return nil
    }

    func configurationChangeDecision(
        isRecording: Bool,
        permissionStatus: AVAuthorizationStatus,
        hasInputDevice: Bool
    ) -> AudioConfigurationRecoveryDecision {
        guard isRecording else {
            return .ignore
        }

        if let error = startRecordingPreconditionError(
            permissionStatus: permissionStatus,
            hasInputDevice: hasInputDevice
        ) {
            return .fail(error)
        }

        return .attemptRecovery
    }
}
