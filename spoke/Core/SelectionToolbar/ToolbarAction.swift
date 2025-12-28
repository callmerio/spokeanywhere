import SwiftUI

import Foundation

// MARK: - 工具栏动作类型

/// 工具栏动作类型
enum ToolbarActionKind: Codable, Equatable {
    /// 内置动作
    case builtin(SelectionToolbarActionType)
    /// 自定义动作 (提示词模板，使用 {{selection}} 占位符)
    case custom(prompt: String)
    
    /// 获取内置类型 (如果是内置动作)
    var builtinType: SelectionToolbarActionType? {
        if case .builtin(let type) = self { return type }
        return nil
    }
    
    /// 是否为内置动作
    var isBuiltin: Bool {
        if case .builtin = self { return true }
        return false
    }
}

// MARK: - 工具栏动作

/// 工具栏动作 (统一模型，支持内置和自定义)
struct ToolbarAction: Identifiable, Codable, Equatable {
    /// 唯一 ID (内置: "builtin.{type}", 自定义: "custom.{uuid}")
    let id: String
    /// 显示名称
    var name: String
    /// 图标 (SF Symbol 名称)
    var icon: String
    /// 图标颜色 (Hex 格式)
    var iconColorHex: String
    /// 动作类型
    var kind: ToolbarActionKind
    /// 是否启用
    var isEnabled: Bool
    /// 自定义提示词 (nil 表示使用默认)
    var customPrompt: String?
    /// 指定的 LLM Profile ID (nil 表示使用默认对话模型)
    var profileId: UUID?
    /// 是否启用联网搜索
    var enableSearch: Bool
    
    // MARK: - Computed Properties
    
    /// 是否为内置动作
    var isBuiltin: Bool { kind.isBuiltin }
    
    /// 图标颜色
    var iconColor: Color {
        Color(hex: iconColorHex)
    }
    
    /// 获取内置类型
    var builtinType: SelectionToolbarActionType? {
        kind.builtinType
    }
    
    /// 是否为 AI 动作（需要 LLM）
    var isAIAction: Bool {
        guard let builtin = builtinType else { return true } // 自定义都是 AI
        return builtin.requiresLLM || builtin == .translate
    }
    
    /// 获取实际使用的提示词
    var effectivePrompt: String? {
        // 自定义提示词优先
        if let custom = customPrompt, !custom.isEmpty {
            return custom
        }
        // 内置动作使用默认提示词
        if let builtin = builtinType {
            return ToolbarActionDefaults.prompt(for: builtin)
        }
        // 自定义动作从 kind 获取
        if case .custom(let prompt) = kind {
            return prompt
        }
        return nil
    }
    
    // MARK: - Codable (兼容旧版本)
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, iconColorHex, kind, isEnabled, customPrompt, profileId, enableSearch
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        iconColorHex = try container.decode(String.self, forKey: .iconColorHex)
        kind = try container.decode(ToolbarActionKind.self, forKey: .kind)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        customPrompt = try container.decodeIfPresent(String.self, forKey: .customPrompt)
        profileId = try container.decodeIfPresent(UUID.self, forKey: .profileId)
        enableSearch = try container.decodeIfPresent(Bool.self, forKey: .enableSearch) ?? false
    }
    
    init(id: String, name: String, icon: String, iconColorHex: String, kind: ToolbarActionKind, isEnabled: Bool, customPrompt: String? = nil, profileId: UUID? = nil, enableSearch: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.iconColorHex = iconColorHex
        self.kind = kind
        self.isEnabled = isEnabled
        self.customPrompt = customPrompt
        self.profileId = profileId
        self.enableSearch = enableSearch
    }
    
    // MARK: - 工厂方法
    
    /// 创建内置动作
    static func builtin(_ type: SelectionToolbarActionType) -> ToolbarAction {
        ToolbarAction(
            id: "builtin.\(type.rawValue)",
            name: type.displayName,
            icon: type.iconName,
            iconColorHex: type.iconColor.toHex() ?? "#808080",
            kind: .builtin(type),
            isEnabled: true,
            customPrompt: nil,
            profileId: nil,
            enableSearch: ToolbarActionDefaults.enableSearch(for: type)
        )
    }
    
    /// 创建自定义动作
    static func custom(name: String, icon: String, iconColorHex: String, prompt: String, profileId: UUID? = nil) -> ToolbarAction {
        ToolbarAction(
            id: "custom.\(UUID().uuidString)",
            name: name,
            icon: icon,
            iconColorHex: iconColorHex,
            kind: .custom(prompt: prompt),
            isEnabled: true,
            customPrompt: nil,
            profileId: profileId,
            enableSearch: false
        )
    }
    
    /// 默认动作列表
    static let defaults: [ToolbarAction] = [
        .builtin(.speak),
        .builtin(.dictionary),
        .builtin(.lookup),
        .builtin(.translate),
        .builtin(.summarize),
        .builtin(.copy)
    ]
    
    // MARK: - 修改辅助
    
    /// 返回禁用/启用后的副本
    func toggled() -> ToolbarAction {
        var copy = self
        copy.isEnabled = !isEnabled
        return copy
    }
    
    /// 返回更新属性后的副本
    func with(name: String? = nil, icon: String? = nil, iconColorHex: String? = nil, isEnabled: Bool? = nil, customPrompt: String?? = nil, profileId: UUID?? = nil, enableSearch: Bool? = nil) -> ToolbarAction {
        var copy = self
        if let name = name { copy.name = name }
        if let icon = icon { copy.icon = icon }
        if let iconColorHex = iconColorHex { copy.iconColorHex = iconColorHex }
        if let isEnabled = isEnabled { copy.isEnabled = isEnabled }
        if let customPrompt = customPrompt { copy.customPrompt = customPrompt }
        if let profileId = profileId { copy.profileId = profileId }
        if let enableSearch = enableSearch { copy.enableSearch = enableSearch }
        return copy
    }
    
    /// 重置为默认设置
    func resetToDefault() -> ToolbarAction {
        guard let builtin = builtinType else { return self }
        var copy = self
        copy.customPrompt = nil
        copy.profileId = nil
        copy.enableSearch = ToolbarActionDefaults.enableSearch(for: builtin)
        return copy
    }
}

// MARK: - 默认提示词

enum ToolbarActionDefaults {
    
    /// 获取内置动作的默认提示词
    static func prompt(for type: SelectionToolbarActionType) -> String? {
        switch type {
        case .lookup:
            return lookupPrompt
        case .translate:
            return translatePrompt
        case .summarize:
            return summarizePrompt
        default:
            return nil
        }
    }
    
    /// 获取内置动作是否默认启用联网搜索
    static func enableSearch(for type: SelectionToolbarActionType) -> Bool {
        switch type {
        case .lookup:
            return true  // 查询需要联网
        default:
            return false
        }
    }
    
    /// 查询提示词
    static let lookupPrompt = """
你是一个知识助手。用户选中了一段文本，请帮助解释或回答相关问题。

## 屏幕上下文（如有）
{{context}}

## 用户选中的内容
{{selection}}

## 要求
1. 简洁明了地解释或回答
2. 如果是专业术语，给出定义和例子
3. 如果是问题，直接回答
4. 使用中文回复
"""
    
    /// 翻译提示词
    static let translatePrompt = """
请将以下文本翻译成中文，保持原文的格式和语气：

{{selection}}

只输出翻译结果，不要添加任何解释。
"""
    
    /// 总结提示词
    static let summarizePrompt = """
请对以下内容进行简洁的总结，提取关键要点：

---
{{selection}}
---

要求：
1. 使用中文回答
2. 分点列出主要内容
3. 控制在 200 字以内
"""
}

// MARK: - Color 扩展 (toHex)

extension Color {
    /// 转换为 Hex 字符串
    func toHex() -> String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB)?.cgColor.components,
              components.count >= 3 else {
            return nil
        }
        
        let red = Int(components[0] * 255)
        let green = Int(components[1] * 255)
        let blue = Int(components[2] * 255)
        
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// MARK: - 占位符常量

enum ToolbarActionPlaceholder {
    /// 选中文本占位符
    static let selection = "{{selection}}"
    /// OCR 上下文占位符
    static let context = "{{context}}"
}
