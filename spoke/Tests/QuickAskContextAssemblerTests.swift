import CoreGraphics
import Testing
@testable import SpokenAnyWhere

@Suite("QuickAskContextAssembler 测试")
struct QuickAskContextAssemblerTests {
    private func makeTestImage() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    @Test("开启 OCR 与截图时会收集上下文来源")
    func collectsEnabledSources() async {
        let image = makeTestImage()

        let result = await QuickAskContextAssembler.collect(
            includeOCR: true,
            includeScreenshot: true,
            getOCRContext: { "窗口文本" },
            captureScreenshot: { image }
        )

        #expect(result.ocrContext == "窗口文本")
        #expect(result.screenshotImage != nil)
        #expect(result.contextSources == [.ocr, .screenshot])
    }

    @Test("空 OCR 与关闭截图时不会追加来源")
    func skipsEmptyOrDisabledSources() async {
        let result = await QuickAskContextAssembler.collect(
            includeOCR: true,
            includeScreenshot: false,
            getOCRContext: { "" },
            captureScreenshot: { nil }
        )

        #expect(result.ocrContext == nil)
        #expect(result.screenshotImage == nil)
        #expect(result.contextSources.isEmpty)
    }
}
