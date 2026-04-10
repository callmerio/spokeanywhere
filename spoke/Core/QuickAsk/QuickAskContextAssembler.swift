import CoreGraphics
import Foundation

struct QuickAskCollectedContext {
    let ocrContext: String?
    let screenshotImage: CGImage?
    let contextSources: [ContextSource]
}

enum QuickAskContextAssembler {
    static func collect(
        includeOCR: Bool,
        includeScreenshot: Bool,
        getOCRContext: @escaping () async -> String?,
        captureScreenshot: @escaping () async -> CGImage?
    ) async -> QuickAskCollectedContext {
        var contextSources: [ContextSource] = []

        let ocrContext: String?
        if includeOCR {
            let collected = await getOCRContext()
            if let collected, !collected.isEmpty {
                ocrContext = collected
                contextSources.append(.ocr)
            } else {
                ocrContext = nil
            }
        } else {
            ocrContext = nil
        }

        let screenshotImage: CGImage?
        if includeScreenshot {
            let collected = await captureScreenshot()
            screenshotImage = collected
            if collected != nil {
                contextSources.append(.screenshot)
            }
        } else {
            screenshotImage = nil
        }

        return QuickAskCollectedContext(
            ocrContext: ocrContext,
            screenshotImage: screenshotImage,
            contextSources: contextSources
        )
    }
}
