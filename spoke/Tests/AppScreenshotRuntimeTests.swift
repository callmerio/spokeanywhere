import CoreGraphics
import Testing
@testable import SpokenAnyWhere

@Suite("AppScreenshotRuntime 测试")
@MainActor
struct AppScreenshotRuntimeTests {
    @Test("windowFactory 会为窗口绑定 frame 更新回调")
    func windowFactoryBindsFrameCallback() throws {
        let item = ScreenshotItem(imagePath: "/tmp/demo.png", frame: .zero)
        var updates: [CGRect] = []

        let runtime = AppScreenshotRuntime(
            makeWindow: { item in
                ScreenshotWindow(item: item)
            },
            updateFrame: { frame, _ in
                updates.append(frame)
            },
            restoreAll: {},
            captureRegion: {},
            debugCaptureForAutomation: {}
        )

        let panel = runtime.makeWindowFactory()(item)
        let window = try #require(panel as? ScreenshotWindow)
        window.onFrameChanged?(CGRect(x: 1, y: 2, width: 3, height: 4))

        #expect(updates == [CGRect(x: 1, y: 2, width: 3, height: 4)])
    }
}
