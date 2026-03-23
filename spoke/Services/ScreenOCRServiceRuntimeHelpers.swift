import Foundation
import Vision

func makeScreenOCRPrefetchTask(
    owner: ScreenOCRService,
    action: @escaping @MainActor (ScreenOCRService) async -> String?
) -> Task<String?, Never> {
    Task { @MainActor in
        await action(owner)
    }
}

func awaitScreenOCRPrefetch(
    task: Task<String?, Never>,
    timeoutNanos: UInt64
) async -> String? {
    await withTaskGroup(of: String?.self) { group in
        group.addTask {
            await task.value
        }

        group.addTask {
            try? await Task.sleep(nanoseconds: timeoutNanos)
            return nil
        }

        if let result = await group.next() {
            group.cancelAll()
            return result
        }
        return nil
    }
}

func runScreenOCRRecognition(on image: CGImage) async -> String? {
    await Task.detached(priority: .userInitiated) {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                if request.results == nil {
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text.isEmpty ? nil : text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }.value
}
