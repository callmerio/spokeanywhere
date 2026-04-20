import AppKit
import CoreGraphics
import Testing
@testable import SpokenAnyWhere

@Suite("AppPinnedTextRuntime 测试")
@MainActor
struct AppPinnedTextRuntimeTests {
    private func makeScrollEvent(
        deltaX: Int32 = 0,
        deltaY: Int32 = 0,
        precise: Bool = true,
        modifiers: NSEvent.ModifierFlags = [],
        phase: NSEvent.Phase = .changed
    ) throws -> NSEvent {
        let units: CGScrollEventUnit = precise ? .pixel : .line
        let cgEvent = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: units,
                wheelCount: 2,
                wheel1: deltaY,
                wheel2: deltaX,
                wheel3: 0
            )
        )
        cgEvent.flags = CGEventFlags(rawValue: UInt64(modifiers.rawValue))

        if precise {
            cgEvent.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            cgEvent.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
            cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: Int64(deltaY))
            cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: Int64(deltaX))
        }

        return try #require(NSEvent(cgEvent: cgEvent))
    }

    private func makeScrollablePreviewText(lineCount: Int = 80) -> String {
        let lines = (1...lineCount).map { index in
            "- item \(index): preview body line \(index)"
        }
        return "# Preview\n" + lines.joined(separator: "\n")
    }

    private func prepareContentForInteraction(
        _ content: PinnedTextContentView,
        in window: NSWindow
    ) {
        content.frame = CGRect(origin: .zero, size: window.frame.size)
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        content.displayIfNeeded()
        window.displayIfNeeded()
    }

    private func advanceMainLoop(by seconds: TimeInterval = 0.2) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    @Test("windowFactory 会为 pinned text 窗口绑定 frame 更新回调")
    func windowFactoryBindsFrameCallback() throws {
        let item = PinnedTextItem(
            text: "hello",
            frame: CGRect(x: 0, y: 0, width: 300, height: 180)
        )
        var updates: [CGRect] = []

        let runtime = AppPinnedTextRuntime(
            makeWindow: { item in
                PinnedTextWindow(item: item)
            },
            updateFrame: { frame, _ in
                updates.append(frame)
            },
            restoreAll: {},
            createFromClipboard: {}
        )

        let panel = runtime.makeWindowFactory()(item)
        let window = try #require(panel as? PinnedTextWindow)
        window.onFrameChanged?(CGRect(x: 4, y: 5, width: 6, height: 7))

        #expect(updates == [CGRect(x: 4, y: 5, width: 6, height: 7)])
    }

    @Test("committed zoom resizing still propagates frame updates through the runtime hook")
    func committedZoomResizeStillPropagatesFrameUpdates() throws {
        let item = PinnedTextItem(
            text: makeScrollablePreviewText(),
            frame: CGRect(x: 40, y: 50, width: 360, height: 160)
        )
        var updates: [CGRect] = []
        let dependencies = PinnedTextActionDependencies(
            togglePin: { item in item.isPinned.toggle() },
            toggleLock: { item in item.isLocked.toggle() },
            toggleMark: { item in item.isMarked.toggle() },
            updateWindowCollectionBehavior: { _ in },
            updateWindowMovable: { _ in },
            updateWindowGlow: { _ in },
            closeWindow: { _ in },
            saveWindowState: {}
        )

        let runtime = AppPinnedTextRuntime(
            makeWindow: { item in
                PinnedTextWindow(item: item, dependencies: dependencies)
            },
            updateFrame: { frame, _ in
                updates.append(frame)
            },
            restoreAll: {},
            createFromClipboard: {}
        )

        let panel = runtime.makeWindowFactory()(item)
        let window = try #require(panel as? PinnedTextWindow)
        let content = try #require(window.pinnedTextContentView)
        prepareContentForInteraction(content, in: window)

        let originalFrame = window.frame
        let originalZoom = window.item.zoomLevel

        window.handleHoverChanged(true, locationInWindow: CGPoint(x: 90, y: 80))

        let scrollEvent = try makeScrollEvent(deltaY: 30, precise: true)
        let endEvent = try makeScrollEvent(deltaY: 0, precise: true, phase: .ended)
        #expect(scrollEvent.hasPreciseScrollingDeltas == true)

        window.scrollWheel(with: scrollEvent)

        #expect(window.item.zoomLevel == originalZoom)
        window.scrollWheel(with: endEvent)
        advanceMainLoop(by: 0.35)
        #expect(window.item.zoomLevel != originalZoom)
        #expect(updates.isEmpty == false)
        #expect(updates.last?.equalTo(window.item.frame) == true)
        #expect(updates.last?.equalTo(originalFrame) == false)
    }
}
