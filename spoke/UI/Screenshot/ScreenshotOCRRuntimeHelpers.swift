import Foundation
import Vision

func runScreenshotOCR(
    _ image: CGImage,
    copyText: @escaping @MainActor (String) -> Void
) {
    runtimeRunDetachedValue(
        priority: .userInitiated,
        operation: { screenshotOCRText(image) },
        onResult: { text in
            guard !text.isEmpty else { return }
            copyText(text)
        }
    )
}

private func screenshotOCRText(_ image: CGImage) -> String? {
    var extractedText = ""
    let semaphore = DispatchSemaphore(value: 0)
    let request = VNRecognizeTextRequest { request, _ in
        defer { semaphore.signal() }
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        extractedText = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

    let handler = VNImageRequestHandler(cgImage: image, options: [:])
    try? handler.perform([request])
    semaphore.wait()
    return extractedText
}
