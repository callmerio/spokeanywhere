import Foundation

struct RecordingCapturedSession {
    let transcription: String
    let audioURL: URL?
    let appBundleId: String?
    let sourceApp: SourceAppInfo?
}

enum RecordingSessionContextAssembler {
    static func capture(
        transcription: String,
        audioURL: URL?,
        targetApp: TargetAppInfo?
    ) -> RecordingCapturedSession {
        RecordingCapturedSession(
            transcription: transcription,
            audioURL: audioURL,
            appBundleId: targetApp?.bundleIdentifier,
            sourceApp: targetApp.map(SourceAppInfo.from)
        )
    }
}
