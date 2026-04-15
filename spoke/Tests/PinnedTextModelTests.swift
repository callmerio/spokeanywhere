import AppKit
import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("PinnedText 模型与持久化测试", .serialized)
@MainActor
struct PinnedTextModelTests {
    private final class CounterBox {
        var value = 0
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoke-pinned-text-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeManager(
        pasteboardText: String? = nil,
        storageRoot: URL,
        beepCounter: CounterBox? = nil
    ) -> PinnedTextManager {
        let manager = PinnedTextManager(
            dependencies: PinnedTextManagerDependencies(
                pasteboardText: { pasteboardText },
                storageRootDirectory: { storageRoot },
                beep: { beepCounter?.value += 1 }
            )
        )
        manager.windowFactory = { item in
            NSPanel(
                contentRect: item.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
        }
        return manager
    }

    @Test("PinnedTextItem Codable round-trip preserves user-facing state")
    func pinnedTextItemCodableRoundTrip() throws {
        let item = PinnedTextItem(
            text: "# Hello\n- world",
            frame: CGRect(x: 12, y: 34, width: 320, height: 200),
            opacity: 0.72,
            zoomLevel: 1.35,
            isPinned: true,
            isLocked: true,
            screenLocalizedName: "Studio Display",
            source: .voice,
            createdAt: Date(timeIntervalSince1970: 1_234)
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(PinnedTextItem.self, from: data)

        #expect(decoded.text == item.text)
        #expect(decoded.frame == item.frame)
        #expect(decoded.opacity == item.opacity)
        #expect(decoded.zoomLevel == item.zoomLevel)
        #expect(decoded.isPinned == item.isPinned)
        #expect(decoded.isLocked == item.isLocked)
        #expect(decoded.screenLocalizedName == item.screenLocalizedName)
        #expect(decoded.source == item.source)
    }

    @Test("clipboard creation defaults to pinned clipboard item")
    func createFromClipboardCreatesPinnedItem() throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let beeps = CounterBox()
        let manager = makeManager(
            pasteboardText: "  # Hello\n- item  ",
            storageRoot: tempDir,
            beepCounter: beeps
        )
        defer { manager.stop() }

        let item = try #require(manager.createFromClipboard())

        #expect(item.source == .clipboard)
        #expect(item.isPinned == true)
        #expect(item.text == "# Hello\n- item")
        #expect(manager.items.count == 1)
        #expect(beeps.value == 0)
    }

    @Test("restore only reloads pinned items")
    func restoreOnlyReloadsPinnedItems() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let writer = makeManager(storageRoot: tempDir)
        defer { writer.stop() }

        let pinned = try #require(writer.createFromText("Pinned", source: .manual))
        let transient = try #require(writer.createFromText("Transient", source: .manual))
        writer.unpin(transient)
        writer.saveAll()

        let reader = makeManager(storageRoot: tempDir)
        defer { reader.stop() }

        await reader.restoreAll()

        #expect(reader.items.count == 1)
        #expect(reader.items.first?.text == pinned.text)
        #expect(reader.items.first?.isPinned == true)
    }

    @Test("markdown preview renderer keeps compact inset and stronger heading hierarchy")
    func markdownPreviewRendererUsesCompactPageMetrics() throws {
        let rendered = PinnedTextMarkdownRenderer.makePreviewAttributedString(
            "# Title\nBody line\n- bullet",
            zoomLevel: 1.0
        )

        let titleFont = try #require(rendered.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let bodyRange = try #require(rendered.string.range(of: "Body line"))
        let bodyLocation = rendered.string.distance(from: rendered.string.startIndex, to: bodyRange.lowerBound)
        let bodyFont = try #require(rendered.attribute(.font, at: bodyLocation, effectiveRange: nil) as? NSFont)

        #expect(PinnedTextMarkdownRenderer.contentInsets.top == 10)
        #expect(PinnedTextMarkdownRenderer.contentInsets.left == 8)
        #expect(PinnedTextMarkdownRenderer.contentInsets.bottom == 8)
        #expect(PinnedTextMarkdownRenderer.contentInsets.right == 8)
        #expect(PinnedTextMarkdownRenderer.windowGlowPadding == ScreenshotContentView.paddingPerSide)
        #expect(PinnedTextMarkdownRenderer.bodyParagraphStyle().lineSpacing == 3)
        #expect(PinnedTextMarkdownRenderer.bodyParagraphStyle().paragraphSpacing == 6)
        #expect(titleFont.pointSize > bodyFont.pointSize)
        #expect(PinnedTextMarkdownRenderer.editorFont(for: 1.0).pointSize == bodyFont.pointSize)
        #expect(PinnedTextMarkdownRenderer.editorParagraphStyle().lineSpacing == 3)
        #expect(PinnedTextMarkdownRenderer.editorParagraphStyle().paragraphSpacing == 6)
    }
}
