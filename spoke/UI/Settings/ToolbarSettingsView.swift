import SwiftUI

private typealias DS = DesignTokens

// MARK: - 常用图标列表

private let commonIcons: [[String]] = [
    ["sparkles", "wand.and.stars", "star.fill", "heart.fill", "bolt.fill"],
    ["magnifyingglass", "globe", "brain.head.profile", "lightbulb.fill", "book.fill"],
    ["doc.text.fill", "text.bubble.fill", "quote.bubble.fill", "list.bullet", "pencil"],
    ["checkmark.circle.fill", "arrow.triangle.2.circlepath", "play.fill", "pause.fill", "stop.fill"],
    ["folder.fill", "tray.fill", "archivebox.fill", "trash.fill", "gear"]
]

@MainActor
struct ToolbarSettingsDependencies {
    let configService: ToolbarConfigService
    let llmSettings: LLMSettings
}

@MainActor
extension ToolbarSettingsDependencies {
    static let live = ToolbarSettingsDependencies(
        configService: .shared,
        llmSettings: .shared
    )
}

// MARK: - 工具栏设置视图

struct ToolbarSettingsView: View {
    @ObservedObject private var configService: ToolbarConfigService
    private let dependencies: ToolbarSettingsDependencies
    @State private var showAddSheet = false
    @State private var editingAction: ToolbarAction?
    @State private var editingAIAction: ToolbarAction?

    init(dependencies: ToolbarSettingsDependencies) {
        self.dependencies = dependencies
        self.configService = dependencies.configService
    }

    init() {
        self.init(dependencies: .live)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // 预览区
            ToolbarPreviewSection(configService: dependencies.configService)
            
            Divider()
            
            // 全局开关
            Toggle("当选中文本时显示工具栏", isOn: $configService.isEnabled)
            
            Divider()
            
            // 技能管理头部
            HStack {
                Text("技能管理")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showAddSheet = true
                } label: {
                    Label("添加技能", systemImage: "plus")
                }
            }
            
            HStack {
                Text("主栏显示数量")
                Spacer()
                Stepper("\(configService.visibleCount)", value: $configService.visibleCount, in: 1...10)
                    .fixedSize()
            }
            
            Text("前 \(configService.visibleCount) 个启用技能将显示在工具栏上，其余的将收纳在更多菜单中。")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
            
            // 可拖拽列表
            List {
                ForEach(configService.actions) { action in
                    ActionRowView(
                        action: action,
                        onToggle: { configService.toggleAction(id: action.id) },
                        onDelete: { configService.removeAction(id: action.id) },
                        onEdit: { editingAction = action },
                        onEditAI: { editingAIAction = action }
                    )
                }
                .onMove { from, to in
                    configService.moveAction(from: from, to: to)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 300)
            
            // 恢复默认按钮
            HStack {
                Spacer()
                Button("恢复默认") {
                    configService.resetToDefaults()
                }
                .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .padding(DS.Spacing.xl)
        .sheet(isPresented: $showAddSheet) {
            AddActionSheet(configService: dependencies.configService)
        }
        .sheet(item: $editingAction) { action in
            EditActionSheet(action: action, configService: dependencies.configService)
        }
        .sheet(item: $editingAIAction) { action in
            AIActionEditSheet(
                action: action,
                configService: dependencies.configService,
                llmSettings: dependencies.llmSettings
            )
        }
    }
}

// MARK: - 预览区

private struct ToolbarPreviewSection: View {
    @ObservedObject private var configService: ToolbarConfigService

    init(configService: ToolbarConfigService) {
        self.configService = configService
    }
    
    var body: some View {
        let previewShadow = DS.Shadow.medium()

        return VStack(spacing: DS.Spacing.lg) {
            Text("预览")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 模拟工具栏
            HStack(spacing: 0) {
                // Logo
                HStack(spacing: 0) {
                    Image(systemName: "sparkles")
                        .font(.system(size: DS.Layout.iconSizeToolbar, weight: .semibold))
                        .foregroundStyle(DS.Gradients.toolbarLogo)
                        .frame(width: DS.Layout.toolbarHeight, height: DS.Layout.toolbarHeight)
                }
                
                // Divider
                Rectangle()
                    .fill(DS.Colors.separator)
                    .frame(width: DS.BorderWidth.thin, height: DS.Layout.toolbarSeparatorHeight)
                
                // Actions
                HStack(spacing: DS.Spacing.xxs) {
                    ForEach(configService.visibleActions) { action in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: action.icon)
                                .font(.system(size: DS.Layout.iconSizeToolbar))
                                .foregroundStyle(DS.Colors.icon)
                            Text(action.name)
                                .font(DS.Typography.button)
                                .foregroundStyle(DS.Colors.textPrimary)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(height: DS.Layout.toolbarButtonHeight)
                        // Hover effect simulation
                        .background(Color.clear)
                    }
                }
                .padding(.horizontal, DS.Spacing.xs)
                
                if configService.hasMenuActions {
                    // Divider
                    Rectangle()
                        .fill(DS.Colors.separator)
                        .frame(width: DS.BorderWidth.thin, height: DS.Layout.toolbarSeparatorHeight)
                    
                    // Menu Button
                    HStack {
                        Image(systemName: "chevron.up")
                            .font(.system(size: DS.Layout.iconSizeSmall, weight: .bold))
                            .foregroundStyle(DS.Colors.icon)
                    }
                    .frame(width: DS.Layout.toolbarButtonHeight, height: DS.Layout.toolbarHeight)
                }
            }
            .frame(height: DS.Layout.toolbarHeight)
            .background(DS.Colors.toolbarBackground)
            .cornerRadius(DS.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.lg)
                    .stroke(DS.Colors.borderPrimary, lineWidth: DS.BorderWidth.hairline)
            )
            .shadow(
                color: previewShadow.color,
                radius: previewShadow.radius,
                x: previewShadow.x,
                y: previewShadow.y
            )
        }
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.lg)
                .fill(DS.Colors.settingsSurfaceElevated)
        )
    }
}

// MARK: - 动作行

private struct ActionRowView: View {
    let action: ToolbarAction
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onEditAI: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.lg) {
            // 拖动手柄
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(DS.Colors.textSecondary)
                .font(DS.Typography.caption)
            
            // 图标
            Image(systemName: action.icon)
                .foregroundColor(action.iconColor)
                .frame(width: DS.Layout.iconSizeStandard)
            
            // 名称
            Text(action.name)
                .font(.body)
            
            // 类型标签
            if !action.isBuiltin {
                Text("自定义")
                    .font(.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.badgeBackground)
                    .cornerRadius(DS.CornerRadius.xs)
            } else if action.isAIAction {
                // AI 动作显示模型名称
                let modelName = action.profileId.flatMap { id in
                    LLMSettings.shared.profiles.first { $0.id == id }?.name
                } ?? "默认"
                
                HStack(spacing: DS.Spacing.xxs) {
                    Text(modelName)
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.accentInfo)
                    
                    if action.enableSearch {
                        Image(systemName: "network")
                            .font(.system(size: DS.Layout.iconSizeSmall))
                            .foregroundStyle(DS.Colors.success)
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(DS.Colors.accentInfo.opacity(0.15))
                .cornerRadius(DS.CornerRadius.xs)
            }
            
            Spacer()
            
            // 操作按钮 (hover 显示)
            if isHovered {
                HStack(spacing: DS.Spacing.md) {
                    // AI 动作编辑按钮
                    if action.isAIAction {
                        Button(action: onEditAI) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(DS.Colors.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .help("编辑提示词和模型")
                    }
                    
                    // 编辑按钮 (仅自定义动作)
                    if !action.isBuiltin {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 删除/禁用按钮
                    Button(action: onDelete) {
                        Image(systemName: action.isBuiltin ? "eye.slash" : "trash")
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help(action.isBuiltin ? "禁用" : "删除")
                }
            }
            
            // 启用开关
            Toggle("", isOn: Binding(
                get: { action.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                .fill(isHovered ? DS.Colors.rowHover : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - 添加技能弹窗

struct AddActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configService: ToolbarConfigService
    
    @State private var name = ""
    @State private var icon = "sparkles"
    @State private var iconColorHex = "#007AFF"
    @State private var prompt = ""
    @State private var validationError: String?
    @State private var showIconPicker = false

    init(configService: ToolbarConfigService) {
        self.configService = configService
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Text("添加技能")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // 名称和图标
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("技能名称和图标")
                    Text("*").foregroundStyle(DS.Colors.error)
                }
                .font(.subheadline)
                
                HStack {
                    TextField("在这里命名你的技能...", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("\(name.count)/20")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    
                    // 图标选择按钮
                    Button {
                        showIconPicker = true
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(DS.Colors.iconButtonBackground)
                            .cornerRadius(DS.CornerRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showIconPicker) {
                        IconPickerPopover(selectedIcon: $icon)
                    }
                }
            }
            
            // 提示词
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("提示词内容")
                    Text("*").foregroundStyle(DS.Colors.error)
                    Spacer()
                    Text("使用 \(ToolbarActionPlaceholder.selection) 代表选中文字")
                        .font(.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Button("示例") {
                        prompt = "请用简单易懂的语言解释以下内容：\n\n\(ToolbarActionPlaceholder.selection)"
                    }
                    .font(.caption)
                }
                .font(.subheadline)
                
                TextEditor(text: $prompt)
                    .font(.body)
                    .frame(minHeight: 150)
                    .padding(4)
                    .background(DS.Colors.textFieldBackground)
                    .cornerRadius(DS.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                            .stroke(DS.Colors.fieldBorder, lineWidth: DS.BorderWidth.thin)
                    )
            }
            
            // 验证错误
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.error)
            }
            
            Spacer()
            
            // 按钮
            HStack {
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("保存") {
                    save()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 500, height: 420)
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !prompt.trimmingCharacters(in: .whitespaces).isEmpty &&
        prompt.contains(ToolbarActionPlaceholder.selection)
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespaces)
        
        if trimmedName.isEmpty {
            validationError = "请输入技能名称"
            return
        }
        if trimmedName.count > 20 {
            validationError = "技能名称不能超过 20 个字符"
            return
        }
        if trimmedPrompt.isEmpty {
            validationError = "请输入提示词内容"
            return
        }
        if !trimmedPrompt.contains(ToolbarActionPlaceholder.selection) {
            validationError = "提示词必须包含 \(ToolbarActionPlaceholder.selection) 占位符"
            return
        }
        
        configService.addCustomAction(
            name: trimmedName,
            icon: icon,
            iconColorHex: iconColorHex,
            prompt: trimmedPrompt
        )
        
        dismiss()
    }
}

// MARK: - 编辑技能弹窗

struct EditActionSheet: View {
    let action: ToolbarAction
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configService: ToolbarConfigService
    
    @State private var name: String
    @State private var icon: String
    @State private var prompt: String
    @State private var validationError: String?
    @State private var showIconPicker = false
    
    init(action: ToolbarAction, configService: ToolbarConfigService) {
        self.action = action
        self.configService = configService
        _name = State(initialValue: action.name)
        _icon = State(initialValue: action.icon)
        if case .custom(let promptText) = action.kind {
            _prompt = State(initialValue: promptText)
        } else {
            _prompt = State(initialValue: "")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("编辑技能")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // 名称和图标
            VStack(alignment: .leading, spacing: 6) {
                Text("技能名称和图标")
                    .font(.subheadline)
                
                HStack {
                    TextField("名称", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    // 图标选择按钮
                    Button {
                        showIconPicker = true
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(DS.Colors.iconButtonBackground)
                            .cornerRadius(DS.CornerRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showIconPicker) {
                        IconPickerPopover(selectedIcon: $icon)
                    }
                }
            }
            
            // 提示词
            VStack(alignment: .leading, spacing: 6) {
                Text("提示词内容")
                    .font(.subheadline)
                
                TextEditor(text: $prompt)
                    .font(.body)
                    .frame(minHeight: 150)
                    .padding(4)
                    .background(DS.Colors.textFieldBackground)
                    .cornerRadius(DS.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.CornerRadius.sm)
                            .stroke(DS.Colors.fieldBorder, lineWidth: DS.BorderWidth.thin)
                    )
            }
            
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.error)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.escape)
                
                Button("保存") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 500, height: 420)
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            validationError = "请输入技能名称"
            return
        }
        guard !trimmedPrompt.isEmpty else {
            validationError = "请输入提示词"
            return
        }
        guard trimmedPrompt.contains(ToolbarActionPlaceholder.selection) else {
            validationError = "提示词必须包含 \(ToolbarActionPlaceholder.selection)"
            return
        }
        
        let updated = ToolbarAction(
            id: action.id,
            name: trimmedName,
            icon: icon,
            iconColorHex: action.iconColorHex,
            kind: .custom(prompt: trimmedPrompt),
            isEnabled: action.isEnabled
        )
        
        configService.updateAction(updated)
        dismiss()
    }
}

// MARK: - AI 动作编辑弹窗

struct AIActionEditSheet: View {
    let action: ToolbarAction
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configService: ToolbarConfigService
    @State private var llmSettings: LLMSettings
    
    @State private var editingPrompt: String
    @State private var editingProfileId: UUID?
    @State private var editingEnableSearch: Bool
    
    init(action: ToolbarAction, configService: ToolbarConfigService, llmSettings: LLMSettings) {
        self.action = action
        self.configService = configService
        self._llmSettings = State(initialValue: llmSettings)
        _editingPrompt = State(initialValue: action.customPrompt ?? action.effectivePrompt ?? "")
        _editingProfileId = State(initialValue: action.profileId)
        _editingEnableSearch = State(initialValue: action.enableSearch)
    }
    
    private var selectedProfile: ProviderProfile? {
        guard let id = editingProfileId else { return nil }
        return llmSettings.profiles.first { $0.id == id }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: action.icon)
                    .font(.system(size: DS.Layout.iconSizeStandard))
                    .foregroundColor(action.iconColor)
                Text("编辑 \(action.name)")
                    .font(DS.Typography.title)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DS.Layout.iconSizeStandard))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(DS.Spacing.xxl)
            .background(DS.Colors.settingsBackground)
            
            Divider().background(DS.Colors.borderPrimary)
            
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                    // 模型选择
                    modelSelectionSection
                    
                    // 联网搜索开关
                    searchToggleSection
                    
                    Divider().background(DS.Colors.borderPrimary)
                    
                    // 提示词编辑
                    promptSection
                }
                .padding(DS.Spacing.xxl)
            }
            
            Divider().background(DS.Colors.borderPrimary)
            
            // 底部按钮
            HStack {
                Button("恢复默认") {
                    resetToDefault()
                }
                .foregroundStyle(DS.Colors.warning)
                
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("保存") {
                    save()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding(DS.Spacing.xxl)
            .background(DS.Colors.settingsBackground)
        }
        .frame(width: 520, height: 560)
        .background(DS.Colors.toolbarBackground)
    }
    
    // MARK: - 模型选择区
    
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack {
                Text("AI 模型")
                    .font(DS.Typography.button.weight(.medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                if editingProfileId == nil {
                    Text("使用默认")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xxs)
                        .background(DS.Colors.buttonHover)
                        .cornerRadius(DS.CornerRadius.xs)
                }
            }
            
            // 模型列表
            VStack(spacing: 0) {
                // 默认选项
                modelRow(
                    name: "跟随默认对话模型",
                    subtitle: llmSettings.chatProfile?.modelName ?? "未配置",
                    isSelected: editingProfileId == nil
                ) {
                    editingProfileId = nil
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                // 已配置的模型列表
                ForEach(llmSettings.profiles, id: \.id) { profile in
                    modelRow(
                        name: profile.name,
                        subtitle: profile.modelName,
                        isSelected: editingProfileId == profile.id
                    ) {
                        editingProfileId = profile.id
                    }
                    
                    if profile.id != llmSettings.profiles.last?.id {
                        Divider().background(DS.Colors.settingsCardBorder)
                    }
                }
            }
            .background(DS.Colors.rowHover)
            .cornerRadius(DS.CornerRadius.md)
        }
    }
    
    private func modelRow(name: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.lg) {
                // 选中标记
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: DS.Layout.iconSizeToolbar))
                    .foregroundStyle(isSelected ? DS.Colors.accentPrimary : DS.Colors.textSecondary)
                
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(name)
                        .font(DS.Typography.button.weight(.medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(subtitle)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.lg)
            .background(isSelected ? DS.Colors.accentPrimary.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 联网搜索开关
    
    private var searchToggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("启用联网搜索")
                    .font(DS.Typography.button.weight(.medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("查询时联网获取最新信息")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $editingEnableSearch)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.rowHover)
        .cornerRadius(DS.CornerRadius.md)
    }
    
    // MARK: - 提示词区
    
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("提示词")
                    .font(DS.Typography.button.weight(.medium))
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                HStack(spacing: DS.Spacing.sm) {
                    placeholderBadge("{{selection}}", color: DS.Colors.accentPrimary)
                    placeholderBadge("{{context}}", color: DS.Colors.success)
                }
            }
            
            TextEditor(text: $editingPrompt)
                .font(.system(size: DS.Typography.fontSizeCaption, design: .monospaced))
                .frame(minHeight: 160)
                .padding(DS.Spacing.lg)
                .background(DS.Colors.settingsSidebarBackground)
                .cornerRadius(DS.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.CornerRadius.md)
                        .stroke(DS.Colors.borderPrimary, lineWidth: DS.BorderWidth.thin)
                )
        }
    }
    
    private func placeholderBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: DS.Typography.fontSizeTimestamp, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(color.opacity(0.15))
            .cornerRadius(DS.CornerRadius.xs)
    }
    
    // MARK: - Actions
    
    private func resetToDefault() {
        if let builtin = action.builtinType {
            editingPrompt = ToolbarActionDefaults.prompt(for: builtin) ?? ""
            editingProfileId = nil
            editingEnableSearch = ToolbarActionDefaults.enableSearch(for: builtin)
        }
    }
    
    private func save() {
        configService.updateAction(id: action.id) { act in
            act.customPrompt = editingPrompt.isEmpty ? nil : editingPrompt
            act.profileId = editingProfileId
            act.enableSearch = editingEnableSearch
        }
        dismiss()
    }
}

// MARK: - 图标选择 Popover

struct IconPickerPopover: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 12) {
            Text("选择图标")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(commonIcons, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { iconName in
                            Button {
                                selectedIcon = iconName
                                dismiss()
                            } label: {
                                Image(systemName: iconName)
                                    .font(.system(size: 18))
                                    .frame(width: 36, height: 36)
                                    .background(
                                        selectedIcon == iconName
                                            ? DS.Colors.accentPrimary.opacity(0.2)
                                            : DS.Colors.textSecondary.opacity(0.1)
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedIcon == iconName
                                                    ? DS.Colors.accentPrimary
                                                    : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
    }
}

// MARK: - Preview

#Preview {
    ToolbarSettingsView()
        .frame(width: 600, height: 700)
}
