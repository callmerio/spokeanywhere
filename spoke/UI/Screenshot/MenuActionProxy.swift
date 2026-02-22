import AppKit

// MARK: - Menu Action Proxy

/// 专用 Target 类，绕过 View Responder Chain 问题
/// 将菜单事件转发给 View 处理
///
/// MainActor isolation: AppKit menu actions are always dispatched on main thread,
/// and ScreenshotContentView is MainActor-isolated.
@MainActor
@objc final class MenuActionProxy: NSObject {
    weak var view: ScreenshotContentView?

    init(view: ScreenshotContentView) {
        self.view = view
    }

    @objc @MainActor func performPinAction() { view?.performPinAction() }
    @objc @MainActor func performMarkAction() { view?.performMarkAction() }
    @objc @MainActor func performCopyImage() { view?.performCopyImage() }
    @objc @MainActor func performCopyEnhancedImage() { view?.performCopyEnhancedImage() }
    @objc @MainActor func performCopyText() { view?.performCopyText() }
    @objc @MainActor func performQuickAsk() { view?.performQuickAsk() }
    @objc @MainActor func performCloseAction() { view?.performCloseAction() }
}
