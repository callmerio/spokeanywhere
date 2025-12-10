import SwiftUI

// MARK: - 常用图标列表

private let commonIcons: [[String]] = [
    ["sparkles", "wand.and.stars", "star.fill", "heart.fill", "bolt.fill"],
    ["magnifyingglass", "globe", "brain.head.profile", "lightbulb.fill", "book.fill"],
    ["doc.text.fill", "text.bubble.fill", "quote.bubble.fill", "list.bullet", "pencil"],
    ["checkmark.circle.fill", "arrow.triangle.2.circlepath", "play.fill", "pause.fill", "stop.fill"],
    ["folder.fill", "tray.fill", "archivebox.fill", "trash.fill", "gear"]
]

// MARK: - 工具栏设置视图

struct ToolbarSettingsView: View {
    @ObservedObject private var configService = ToolbarConfigService.shared
    @State private var showAddSheet = false
    @State private var editingAction: ToolbarAction?
    @State private var editingAIAction: ToolbarAction?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 预览区
            ToolbarPreviewSection()
            
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
                .font(.caption)
                .foregroundColor(.secondary)
            
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
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .sheet(isPresented: $showAddSheet) {
            AddActionSheet()
        }
        .sheet(item: $editingAction) { action in
            EditActionSheet(action: action)
        }
        .sheet(item: $editingAIAction) { action in
            AIActionEditSheet(action: action)
        }
    }
}

// MARK: - 预览区

private struct ToolbarPreviewSection: View {
    @ObservedObject private var configService = ToolbarConfigService.shared
    
    var body: some View {
        VStack(spacing: 12) {
            Text("预览")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 模拟工具栏
            HStack(spacing: 0) {
                // Logo
                HStack(spacing: 0) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.8, green: 0.4, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 44)
                }
                
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: 18)
                
                // Actions
                HStack(spacing: 2) {
                    ForEach(configService.visibleActions) { action in
                        HStack(spacing: 6) {
                            Image(systemName: action.icon)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                            Text(action.name)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 32)
                        // Hover effect simulation
                        .background(Color.clear)
                    }
                }
                .padding(.horizontal, 4)
                
                if configService.hasMenuActions {
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 1, height: 18)
                    
                    // Menu Button
                    HStack {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(width: 32, height: 44)
                }
            }
            .frame(height: 44)
            .background(Color(hex: "1F1F1F"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.15))
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
        HStack(spacing: 12) {
            // 拖动手柄
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            
            // 图标
            Image(systemName: action.icon)
                .foregroundColor(action.iconColor)
                .frame(width: 20)
            
            // 名称
            Text(action.name)
                .font(.body)
            
            // 类型标签
            if !action.isBuiltin {
                Text("自定义")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            } else if action.isAIAction {
                // AI 动作显示模型名称
                let modelName = action.profileId.flatMap { id in
                    LLMSettings.shared.profiles.first { $0.id == id }?.name
                } ?? "默认"
                
                HStack(spacing: 4) {
                    Text(modelName)
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    if action.enableSearch {
                        Image(systemName: "network")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(4)
            }
            
            Spacer()
            
            // 操作按钮 (hover 显示)
            if isHovered {
                HStack(spacing: 8) {
                    // AI 动作编辑按钮
                    if action.isAIAction {
                        Button(action: onEditAI) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("编辑提示词和模型")
                    }
                    
                    // 编辑按钮 (仅自定义动作)
                    if !action.isBuiltin {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // 删除/禁用按钮
                    Button(action: onDelete) {
                        Image(systemName: action.isBuiltin ? "eye.slash" : "trash")
                            .foregroundColor(.secondary)
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
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.white.opacity(0.05) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - 添加技能弹窗

struct AddActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configService = ToolbarConfigService.shared
    
    @State private var name = ""
    @State private var icon = "sparkles"
    @State private var iconColorHex = "#007AFF"
    @State private var prompt = ""
    @State private var validationError: String?
    @State private var showIconPicker = false
    
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
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // 名称和图标
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("技能名称和图标")
                    Text("*").foregroundColor(.red)
                }
                .font(.subheadline)
                
                HStack {
                    TextField("在这里命名你的技能...", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("\(name.count)/20")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 图标选择按钮
                    Button {
                        showIconPicker = true
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
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
                    Text("*").foregroundColor(.red)
                    Spacer()
                    Text("使用 \(ToolbarActionPlaceholder.selection) 代表选中文字")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // 验证错误
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
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
    @ObservedObject private var configService = ToolbarConfigService.shared
    
    @State private var name: String
    @State private var icon: String
    @State private var prompt: String
    @State private var validationError: String?
    @State private var showIconPicker = false
    
    init(action: ToolbarAction) {
        self.action = action
        _name = State(initialValue: action.name)
        _icon = State(initialValue: action.icon)
        if case .custom(let p) = action.kind {
            _prompt = State(initialValue: p)
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
                        .foregroundColor(.secondary)
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
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(6)
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
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            
            if let error = validationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
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
    @ObservedObject private var configService = ToolbarConfigService.shared
    @State private var llmSettings = LLMSettings.shared
    
    @State private var editingPrompt: String
    @State private var editingProfileId: UUID?
    @State private var editingEnableSearch: Bool
    
    init(action: ToolbarAction) {
        self.action = action
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
                    .font(.system(size: 18))
                    .foregroundColor(action.iconColor)
                Text("编辑 \(action.name)")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(hex: "1a1a1a"))
            
            Divider().background(Color.white.opacity(0.1))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 模型选择
                    modelSelectionSection
                    
                    // 联网搜索开关
                    searchToggleSection
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    // 提示词编辑
                    promptSection
                }
                .padding(20)
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // 底部按钮
            HStack {
                Button("恢复默认") {
                    resetToDefault()
                }
                .foregroundColor(.orange)
                
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
            .padding(20)
            .background(Color(hex: "1a1a1a"))
        }
        .frame(width: 520, height: 560)
        .background(Color(hex: "1f1f1f"))
    }
    
    // MARK: - 模型选择区
    
    private var modelSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AI 模型")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                if editingProfileId == nil {
                    Text("使用默认")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
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
                
                Divider().background(Color.white.opacity(0.06))
                
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
                        Divider().background(Color.white.opacity(0.06))
                    }
                }
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func modelRow(name: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 选中标记
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .blue : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 联网搜索开关
    
    private var searchToggleSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("启用联网搜索")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Text("查询时联网获取最新信息")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $editingEnableSearch)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - 提示词区
    
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("提示词")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                HStack(spacing: 6) {
                    placeholderBadge("{{selection}}", color: .blue)
                    placeholderBadge("{{context}}", color: .green)
                }
            }
            
            TextEditor(text: $editingPrompt)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 160)
                .padding(10)
                .background(Color(hex: "141414"))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    private func placeholderBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .cornerRadius(4)
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
                                            ? Color.accentColor.opacity(0.2)
                                            : Color.secondary.opacity(0.1)
                                    )
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                selectedIcon == iconName
                                                    ? Color.accentColor
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
