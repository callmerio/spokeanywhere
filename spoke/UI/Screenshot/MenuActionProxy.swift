import AppKit

// MARK: - Menu Action Proxy

/// 专用 Target 类，绕过 View Responder Chain 问题
/// 将菜单事件转发给 View 处理
@objc final class MenuActionProxy: NSObject {
    weak var view: ScreenshotContentView?

    init(view: ScreenshotContentView) {
        self.view = view
    }

    @objc func performPinAction() { view?.performPinAction() }
    @objc func performMarkAction() { view?.performMarkAction() }
    @objc func performCopyImage() { view?.performCopyImage() }
    @objc func performCopyEnhancedImage() { view?.performCopyEnhancedImage() }
    @objc func performCopyText() { view?.performCopyText() }
    @objc func performQuickAsk() { view?.performQuickAsk() }
    @objc func performCloseAction() { view?.performCloseAction() }
}
