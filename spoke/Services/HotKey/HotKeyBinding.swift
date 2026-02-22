import AppKit
import Carbon.HIToolbox

/// 热键绑定配置
/// 封装单个热键的 keyCode 和修饰符
struct HotKeyBinding: Equatable {
    let keyCode: UInt32
    let modifiers: NSEvent.ModifierFlags

    /// 检查给定的事件 flags 是否匹配此绑定的修饰键（严格匹配）
    func matchesModifiers(_ flags: CGEventFlags) -> Bool {
        var currentFlags: NSEvent.ModifierFlags = []

        if flags.contains(.maskAlternate) { currentFlags.insert(.option) }
        if flags.contains(.maskCommand) { currentFlags.insert(.command) }
        if flags.contains(.maskControl) { currentFlags.insert(.control) }
        if flags.contains(.maskShift) { currentFlags.insert(.shift) }

        let targetFlags = modifiers.intersection([.option, .command, .control, .shift])
        return currentFlags == targetFlags
    }

    /// 检查给定的 keyCode 是否匹配此绑定
    func matchesKeyCode(_ code: UInt32) -> Bool {
        return keyCode == code
    }

    /// 检查事件是否完全匹配此绑定（keyCode + modifiers）
    func matches(keyCode code: UInt32, flags: CGEventFlags) -> Bool {
        return matchesKeyCode(code) && matchesModifiers(flags)
    }
}

/// 热键类型枚举
enum HotKeyType: String, CaseIterable {
    case recording = "recording"
    case quickAsk = "quickAsk"
    case messagePanel = "messagePanel"
    case liveCaption = "liveCaption"
    case clipboardPipeline = "clipboardPipeline"
    case screenshot = "screenshot"
    case openSettings = "openSettings"
}
