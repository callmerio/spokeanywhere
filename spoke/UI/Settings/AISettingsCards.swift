import SwiftUI

private typealias DS = DesignTokens

struct RefineSettingsCard: View {
    @Bindable var llmSettings: LLMSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("润色（转录后处理）")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, 4)

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    // 系统提示词（可折叠）
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 10) {
                            TextEditor(text: Binding(
                                get: { llmSettings.systemPrompt },
                                set: { llmSettings.systemPrompt = $0 }
                            ))
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(DS.Colors.rowHover)
                            .cornerRadius(DS.CornerRadius.md)
                            .frame(height: 80)

                            HStack {
                                Button("重置为默认") {
                                    llmSettings.resetToDefaultPrompt()
                                }
                                .buttonStyle(.bordered)
                                .tint(DS.Colors.textSecondary)
                                .controlSize(.small)

                                Spacer()

                                Text("\(llmSettings.systemPrompt.count) 字符")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        Label("系统提示词", systemImage: "text.quote")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.Colors.textPrimary)
                    }
                    .tint(DS.Colors.textSecondary)

                    Divider().background(DS.Colors.settingsCardBorder)

                    // 上下文选项
                    HStack(spacing: 24) {
                        Toggle(isOn: Binding(
                            get: { llmSettings.includeActiveApp },
                            set: { llmSettings.includeActiveApp = $0 }
                        )) {
                            Label("应用 OCR", systemImage: "text.viewfinder")
                                .font(.system(size: 12))
                        }
                        .toggleStyle(.switch)
                        .tint(DS.Colors.accentPrimary)

                        Toggle(isOn: Binding(
                            get: { llmSettings.includeClipboard },
                            set: { llmSettings.includeClipboard = $0 }
                        )) {
                            Label("包含剪贴板", systemImage: "doc.on.clipboard")
                                .font(.system(size: 12))
                        }
                        .toggleStyle(.switch)
                        .tint(DS.Colors.accentPrimary)
                    }

                    Divider().background(DS.Colors.settingsCardBorder)

                    // AI 生成标题
                    Toggle(isOn: Binding(
                        get: { llmSettings.aiGeneratedTitleEnabled },
                        set: { llmSettings.aiGeneratedTitleEnabled = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("AI 生成标题", systemImage: "textformat")
                                .font(.system(size: 13, weight: .medium))
                            Text("为历史记录自动生成简洁标题")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accentPrimary)

                    Divider().background(DS.Colors.settingsCardBorder)

                    // 自动总结
                    Toggle(isOn: Binding(
                        get: { llmSettings.summaryAutoEnabled },
                        set: { llmSettings.summaryAutoEnabled = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("自动生成总结", systemImage: "text.quote")
                                .font(.system(size: 13, weight: .medium))
                            Text("切换到 Todo/Note 时自动生成内容摘要")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accentPrimary)
                }
                .padding(16)
            }
        }
    }
}

struct QuickAskSettingsCard: View {
    @Bindable var llmSettings: LLMSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Ask（快捷提问）")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, 4)

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    // 上下文来源标题
                    Text("上下文来源")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DS.Colors.textSecondary)

                    // 应用 OCR
                    Toggle(isOn: Binding(
                        get: { llmSettings.quickAskIncludeOCR },
                        set: { llmSettings.quickAskIncludeOCR = $0 }
                    )) {
                        Label("应用 OCR", systemImage: "text.viewfinder")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accentPrimary)

                    // 应用截图
                    Toggle(isOn: Binding(
                        get: { llmSettings.quickAskIncludeScreenshot },
                        set: { llmSettings.quickAskIncludeScreenshot = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("应用截图", systemImage: "photo")
                                .font(.system(size: 12))
                            Text("多模态模型可理解图片内容")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accentPrimary)

                    // 剪贴板
                    Toggle(isOn: Binding(
                        get: { llmSettings.quickAskIncludeClipboard },
                        set: { llmSettings.quickAskIncludeClipboard = $0 }
                    )) {
                        Label("剪贴板历史", systemImage: "doc.on.clipboard")
                            .font(.system(size: 12))
                    }
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accentPrimary)

                    Divider().background(DS.Colors.settingsCardBorder)

                    // 实时字幕上下文
                    Toggle(isOn: Binding(
                        get: { llmSettings.quickAskIncludeLiveCaption },
                        set: { llmSettings.quickAskIncludeLiveCaption = $0 }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("实时字幕", systemImage: "captions.bubble")
                                .font(.system(size: 12))
                            Text("适合视频学习场景")
                                .font(.system(size: 10))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(DS.Colors.accentPrimary)

                    // 字幕条数限制（仅在开启时显示）
                    if llmSettings.quickAskIncludeLiveCaption {
                        HStack {
                            Text("字幕范围")
                                .font(.system(size: 11))
                                .foregroundStyle(DS.Colors.textPrimary.opacity(0.8))

                            Spacer()

                            Picker("", selection: Binding(
                                get: { llmSettings.quickAskLiveCaptionLimit },
                                set: { llmSettings.quickAskLiveCaptionLimit = $0 }
                            )) {
                                Text("最近 50 条").tag(50)
                                Text("全量").tag(0)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                        }
                        .padding(.leading, 24)
                    }
                }
                .padding(16)
            }
        }
    }
}
