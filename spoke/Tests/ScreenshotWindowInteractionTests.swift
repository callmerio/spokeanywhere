import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("Screenshot 主试点测试")
@MainActor
struct ScreenshotWindowInteractionTests {
    private func makeTempImageURL() throws -> URL {
        let image = NSImage(size: NSSize(width: 24, height: 24))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 24, height: 24)).fill()
        image.unlockFocus()

        let tiffData = try #require(image.tiffRepresentation)
        let rep = try #require(NSBitmapImageRep(data: tiffData))
        let data = try #require(rep.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("screenshot-window-test-\(UUID().uuidString).png")
        try data.write(to: url)
        return url
    }

    private func makeKeyEvent(window: NSWindow, key: String) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: window.windowNumber,
                context: nil,
                characters: key,
                charactersIgnoringModifiers: key,
                isARepeat: false,
                keyCode: 0
            )
        )
    }

    @Test("窗口快捷键会沿完整交互链派发 Pin / Quick Ask / Close")
    func keyShortcutsDispatchThroughInjectedWindowChain() throws {
        let imageURL = try makeTempImageURL()
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let item = ScreenshotItem(
            imagePath: imageURL.path,
            frame: CGRect(x: 0, y: 0, width: 160, height: 120)
        )

        var pinCalls = 0
        var quickAskImages: [NSImage] = []
        var closeCalls: [UUID] = []

        let dependencies = ScreenshotActionDependencies(
            togglePin: { item in
                pinCalls += 1
                item.isPinned.toggle()
            },
            toggleLock: { _ in },
            toggleMark: { _ in },
            withWindow: { _, _ in },
            updateWindowCollectionBehavior: { _ in },
            updateWindowMovable: { _ in },
            copyImage: { _, _ in },
            copyRawImage: { _ in },
            closeWindow: { item in
                closeCalls.append(item.id)
            },
            startQuickAsk: { image in
                quickAskImages.append(image)
            },
            enhanceImage: { image, _ in image },
            enhanceBasic: { _, _ in nil },
            enhanceAIHighRes: { _ in nil },
            scaleImage: { image, _, _ in image },
            shouldShowEnhancedCopy: { false },
            showSelectionToolbar: { _, _ in },
            saveWindowState: {},
            notificationCenter: .default,
            copyText: { _ in }
        )

        let window = ScreenshotWindow(item: item, dependencies: dependencies)

        try window.keyDown(with: makeKeyEvent(window: window, key: "p"))
        #expect(pinCalls == 1)
        #expect(item.isPinned == true)
        #expect(window.collectionBehavior.isEmpty)

        try window.keyDown(with: makeKeyEvent(window: window, key: "a"))
        #expect(quickAskImages.count == 1)

        try window.keyDown(with: makeKeyEvent(window: window, key: "q"))
        #expect(closeCalls == [item.id])
    }

    @Test("截图 Pin 状态显示黑色 idle 光晕，Unpin 状态无光晕")
    func screenshotPinnedIdleGlowIsBlackAndUnpinnedIsClear() throws {
        let imageURL = try makeTempImageURL()
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let item = ScreenshotItem(
            imagePath: imageURL.path,
            frame: CGRect(x: 0, y: 0, width: 160, height: 120)
        )

        let dependencies = ScreenshotActionDependencies(
            togglePin: { _ in },
            toggleLock: { _ in },
            toggleMark: { _ in },
            withWindow: { _, _ in },
            updateWindowCollectionBehavior: { _ in },
            updateWindowMovable: { _ in },
            copyImage: { _, _ in },
            copyRawImage: { _ in },
            closeWindow: { _ in },
            startQuickAsk: { _ in },
            enhanceImage: { image, _ in image },
            enhanceBasic: { _, _ in nil },
            enhanceAIHighRes: { _ in nil },
            scaleImage: { image, _, _ in image },
            shouldShowEnhancedCopy: { false },
            showSelectionToolbar: { _, _ in },
            saveWindowState: {},
            notificationCenter: .default,
            copyText: { _ in }
        )

        let content = ScreenshotContentView(item: item, dependencies: dependencies)
        content.frame = CGRect(origin: .zero, size: item.frame.size)
        content.layoutSubtreeIfNeeded()

        let glowLayer = try #require(
            content.layer?.sublayers?
                .compactMap { $0 as? CAShapeLayer }
                .first { $0.zPosition == -1 }
        )

        content.updateGlow(isHovered: false, isMarked: false, isPinned: true)

        #expect(glowLayer.strokeColor != nil)
        #expect(glowLayer.lineWidth == DesignTokens.Glow.ScreenshotCard.idle.lineWidth)
        #expect(glowLayer.shadowRadius == DesignTokens.Glow.ScreenshotCard.idle.shadowRadius)
        #expect(glowLayer.shadowOpacity == DesignTokens.Glow.ScreenshotCard.idle.shadowOpacity)

        let shadowCGColor = try #require(glowLayer.shadowColor)
        let shadowColor = try #require(NSColor(cgColor: shadowCGColor)?.usingColorSpace(.deviceRGB))
        #expect(shadowColor.redComponent == 0)
        #expect(shadowColor.greenComponent == 0)
        #expect(shadowColor.blueComponent == 0)

        content.updateGlow(isHovered: false, isMarked: false, isPinned: false)

        #expect(glowLayer.strokeColor == nil)
        #expect(glowLayer.lineWidth == 0)
        #expect(glowLayer.shadowColor == nil)
        #expect(glowLayer.shadowOpacity == 0)
    }
}
