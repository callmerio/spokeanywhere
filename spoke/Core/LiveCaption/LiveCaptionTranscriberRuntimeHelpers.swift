import Foundation
import Speech

func runLiveCaptionTranscriberOnMain(
    _ transcriber: LiveCaptionTranscriber?,
    result: SFSpeechRecognitionResult?,
    error: Error?
) {
    runtimeRunOnMain(owner: transcriber) { owner in
        owner.handleRecognitionResult(result, error: error)
    }
}
