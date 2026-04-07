import AppKit
import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("Attachment 测试")
@MainActor
struct AttachmentTests {

    @Test("image/screenshot/file/textBundle 基本属性正确")
    func attachmentMetadata() {
        let image = makeImage(width: 100, height: 50)
        let imageID = UUID()
        let screenshotID = UUID()
        let fileID = UUID()
        let bundleID = UUID()

        let imageAttachment = Attachment.image(image, nil, imageID)
        let screenshotAttachment = Attachment.screenshot(image, nil, screenshotID)
        let fileAttachment = Attachment.file(URL(fileURLWithPath: "/tmp/demo.mp4"), fileID)
        let textBundleAttachment = Attachment.textBundle("let value = 42", "demo.swift", 1, bundleID)

        #expect(imageAttachment.id == imageID)
        #expect(screenshotAttachment.displayTitle == "截图")
        #expect(fileAttachment.fileName == "demo.mp4")
        #expect(fileAttachment.isVideo)
        #expect(textBundleAttachment.isTextBundle)
        #expect(textBundleAttachment.textContent == "let value = 42")
    }

    @Test("makeThumbnail 会缩小大图并保持宽高比")
    func makeThumbnailResizesAndPreservesRatio() {
        let image = makeImage(width: 2000, height: 1000)
        let thumbnail = Attachment.makeThumbnail(from: image, maxSize: 256)

        #expect(thumbnail.size.width <= 256)
        #expect(thumbnail.size.height <= 256)
        #expect(abs((thumbnail.size.width / thumbnail.size.height) - 2.0) < 0.05)
    }

    @Test("makeThumbnail 不会放大小图")
    func makeThumbnailDoesNotUpscale() {
        let image = makeImage(width: 48, height: 48)
        let thumbnail = Attachment.makeThumbnail(from: image, maxSize: 256)

        #expect(thumbnail.size.width == 48)
        #expect(thumbnail.size.height == 48)
    }

    private func makeImage(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }
}
