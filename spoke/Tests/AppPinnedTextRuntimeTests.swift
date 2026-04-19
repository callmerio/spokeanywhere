import CoreGraphics
import Testing
@testable import SpokenAnyWhere

@Suite("AppPinnedTextRuntime 测试")
@MainActor
struct AppPinnedTextRuntimeTests {
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
            text: "hello",
            frame: CGRect(x: 40, y: 50, width: 300, height: 180)
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
        window.onFrameChanged?(CGRect(x: 20, y: 30, width: 360, height: 220))

        #expect(updates.last == CGRect(x: 20, y: 30, width: 360, height: 220))
    }
}
