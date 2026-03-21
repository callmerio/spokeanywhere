@preconcurrency import ApplicationServices
import Foundation

/// 辅助功能权限工具
/// 提供统一的辅助功能权限请求接口，避免直接访问 Apple SDK 的非 Sendable 类型
enum AccessibilityHelper {

    /// 静默检查辅助功能权限，不触发系统弹窗
    @MainActor
    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// 请求辅助功能权限（带提示）
    /// - Returns: 当前是否已授权
    ///
    /// 注意：kAXTrustedCheckOptionPrompt 是 Apple SDK 声明为 var 的常量（非 Sendable）
    /// 此函数在 MainActor 上下文中安全访问并调用系统 API，返回 Sendable 的 Bool 结果
    @MainActor
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
