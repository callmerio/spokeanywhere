import AppKit

/// 热键处理器协议
/// 每个热键功能实现此协议来处理对应的快捷键事件
@MainActor
protocol HotKeyHandler: AnyObject {
    /// 处理器对应的热键类型
    var hotKeyType: HotKeyType { get }

    /// 当前的热键绑定配置
    var binding: HotKeyBinding { get set }

    /// 处理 keyDown 事件
    /// - Returns: 是否已处理（true 则吞掉事件，false 则放行）
    func handleKeyDown() -> Bool

    /// 处理 keyUp 事件
    /// - Returns: 是否已处理
    func handleKeyUp() -> Bool

    /// 重新加载快捷键配置
    func reloadBinding()
}

/// 默认实现：keyUp 不处理
extension HotKeyHandler {
    func handleKeyUp() -> Bool {
        return false
    }
}

/// 简单触发型处理器的基类
/// 用于只需要在 keyDown 时触发回调的热键（如 Screenshot、LiveCaption 等）
@MainActor
class SimpleTriggerHandler: HotKeyHandler {
    let hotKeyType: HotKeyType
    var binding: HotKeyBinding
    var onTrigger: (() -> Void)?

    init(type: HotKeyType, binding: HotKeyBinding) {
        self.hotKeyType = type
        self.binding = binding
    }

    func handleKeyDown() -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.onTrigger?()
        }
        return true
    }

    func reloadBinding() {
        // 子类实现
    }
}
