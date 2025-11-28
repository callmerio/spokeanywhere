import Foundation
import AppKit

// MARK: - Attachment Tests

/// Attachment 类型单元测试
/// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
@main
struct AttachmentTests {
    
    static var passCount = 0
    static var failCount = 0
    
    static func main() async {
        print("🧪 Attachment 类型单元测试")
        print("=" * 50)
        
        // 运行测试
        runTest("Image 类型属性") { try testImageAttachment() }
        runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
        runTest("File 类型属性") { try testFileAttachment() }
        runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
        runTest("视频文件检测") { try testVideoDetection() }
        runTest("ID 相等性判断") { try testEqualityById() }
        runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
        runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
        runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
        runTest("缩略图处理空图") { try testThumbnailZeroSize() }
        
        print("\n" + "=" * 50)
        print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
    }
    
    // MARK: - Test Runner
    
    static func runTest(_ name: String, _ test: () throws -> Void) {
        print("\n📝 测试: \(name)")
        do {
            try test()
            print("   ✅ 通过")
            passCount += 1
        } catch {
            print("   ❌ 失败: \(error)")
            failCount += 1
        }
    }
    
    // MARK: - Test Cases: Attachment Types
    
    static func testImageAttachment() throws {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
        let id = UUID()
        
        let attachment = Attachment.image(image, thumbnail, id)
        
        try assertEqual(attachment.id, id, "ID")
        try assertEqual(attachment.displayTitle, "图片", "displayTitle")
        try assertNotNil(attachment.thumbnail, "thumbnail")
        try assertNotNil(attachment.originalImage, "originalImage")
        try assertFalse(attachment.isVideo, "isVideo")
        try assertFalse(attachment.isTextBundle, "isTextBundle")
        try assertNil(attachment.textContent, "textContent")
    }
    
    static func testScreenshotAttachment() throws {
        let image = NSImage(size: NSSize(width: 1920, height: 1080))
        let id = UUID()
        
        let attachment = Attachment.screenshot(image, nil, id)
        
        try assertEqual(attachment.id, id, "ID")
        try assertEqual(attachment.displayTitle, "截图", "displayTitle")
        try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
        try assertNotNil(attachment.originalImage, "originalImage")
    }
    
    static func testFileAttachment() throws {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let id = UUID()
        
        let attachment = Attachment.file(url, id)
        
        try assertEqual(attachment.id, id, "ID")
        try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
        try assertEqual(attachment.fileName, "test.pdf", "fileName")
        try assertNil(attachment.thumbnail, "thumbnail")
        try assertNil(attachment.originalImage, "originalImage")
    }
    
    static func testTextBundleAttachment() throws {
        let content = "# Code content\nlet x = 1"
        let source = "my-project"
        let count = 42
        let id = UUID()
        
        let attachment = Attachment.textBundle(content, source, count, id)
        
        try assertEqual(attachment.id, id, "ID")
        try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
        try assertEqual(attachment.fileName, source, "fileName")
        try assertTrue(attachment.isTextBundle, "isTextBundle")
        try assertEqual(attachment.textContent, content, "textContent")
    }
    
    static func testVideoDetection() throws {
        let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
        let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
        let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
        
        try assertTrue(mp4.isVideo, "mp4 should be video")
        try assertTrue(mov.isVideo, "mov should be video")
        try assertFalse(txt.isVideo, "txt should not be video")
    }
    
    static func testEqualityById() throws {
        let id = UUID()
        let image1 = NSImage(size: NSSize(width: 100, height: 100))
        let image2 = NSImage(size: NSSize(width: 200, height: 200))
        
        let att1 = Attachment.image(image1, nil, id)
        let att2 = Attachment.image(image2, nil, id)
        let att3 = Attachment.image(image1, nil, UUID())
        
        try assertTrue(att1 == att2, "Same ID should be equal")
        try assertFalse(att1 == att3, "Different ID should not be equal")
    }
    
    // MARK: - Test Cases: Thumbnail Generation
    
    static func testThumbnailResizesLarge() throws {
        let large = createTestImage(width: 2000, height: 1000)
        let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
        
        try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
        try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
    }
    
    static func testThumbnailPreservesRatio() throws {
        let image = createTestImage(width: 2000, height: 1000)
        let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
        
        let ratio = thumb.size.width / thumb.size.height
        try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
    }
    
    static func testThumbnailNoUpscale() throws {
        let small = createTestImage(width: 50, height: 50)
        let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
        
        try assertEqual(thumb.size.width, 50, "Width")
        try assertEqual(thumb.size.height, 50, "Height")
    }
    
    static func testThumbnailZeroSize() throws {
        let zero = NSImage(size: NSSize(width: 0, height: 0))
        let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
        
        try assertEqual(thumb.size.width, 0, "Width")
    }
    
    // MARK: - Helpers
    
    static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }
}

// MARK: - Attachment Type (简化版，用于测试)

import UniformTypeIdentifiers

enum Attachment: Identifiable, Equatable {
    case image(NSImage, NSImage?, UUID)
    case screenshot(NSImage, NSImage?, UUID)
    case file(URL, UUID)
    case textBundle(String, String, Int, UUID)
    
    var id: UUID {
        switch self {
        case .image(_, _, let id), .screenshot(_, _, let id),
             .file(_, let id), .textBundle(_, _, _, let id):
            return id
        }
    }
    
    var thumbnail: NSImage? {
        switch self {
        case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
        default: return nil
        }
    }
    
    var originalImage: NSImage? {
        switch self {
        case .image(let img, _, _), .screenshot(let img, _, _): return img
        default: return nil
        }
    }
    
    var fileName: String? {
        switch self {
        case .file(let url, _): return url.lastPathComponent
        case .textBundle(_, let source, _, _): return source
        default: return nil
        }
    }
    
    var displayTitle: String {
        switch self {
        case .image: return "图片"
        case .screenshot: return "截图"
        case .file(let url, _): return url.lastPathComponent
        case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
        }
    }
    
    var isVideo: Bool {
        if case .file(let url, _) = self,
           let uti = UTType(filenameExtension: url.pathExtension) {
            return uti.conforms(to: .movie) || uti.conforms(to: .video)
        }
        return false
    }
    
    var isTextBundle: Bool {
        if case .textBundle = self { return true }
        return false
    }
    
    var textContent: String? {
        if case .textBundle(let content, _, _, _) = self { return content }
        return nil
    }
    
    static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
    
    static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
        let size = image.size
        guard size.width > 0 && size.height > 0 else { return image }
        
        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()
        return thumbnail
    }
}

// MARK: - Assertion Helpers

struct TestError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
    if actual != expected {
        throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
    }
}

func assertTrue(_ condition: Bool, _ message: String) throws {
    if !condition { throw TestError(message) }
}

func assertFalse(_ condition: Bool, _ message: String) throws {
    if condition { throw TestError(message) }
}

func assertNil<T>(_ value: T?, _ message: String) throws {
    if value != nil { throw TestError("\(message) 应该是 nil") }
}

func assertNotNil<T>(_ value: T?, _ message: String) throws {
    if value == nil { throw TestError("\(message) 不应该是 nil") }
}

extension String {
    static func * (string: String, count: Int) -> String {
        String(repeating: string, count: count)
    }
}
