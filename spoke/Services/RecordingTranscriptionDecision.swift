import Foundation

struct RecordingTranscriptionDecision {
    let clipboardText: String
    let processedText: String?
    let hudCompletionText: String?
    let hudFailure: (any Error)?

    static func make(
        rawText: String,
        refineResult: Result<String, LLMError>,
        isStillRecording: Bool
    ) -> Self {
        switch refineResult {
        case .success(let refinedText):
            return .init(
                clipboardText: refinedText,
                processedText: refinedText,
                hudCompletionText: isStillRecording ? nil : refinedText,
                hudFailure: nil
            )
        case .failure(let error):
            return .init(
                clipboardText: rawText,
                processedText: nil,
                hudCompletionText: nil,
                hudFailure: isStillRecording ? nil : error
            )
        }
    }

    static func passthrough(
        rawText: String,
        isStillRecording: Bool
    ) -> Self {
        .init(
            clipboardText: rawText,
            processedText: nil,
            hudCompletionText: isStillRecording ? nil : rawText,
            hudFailure: nil
        )
    }
}
