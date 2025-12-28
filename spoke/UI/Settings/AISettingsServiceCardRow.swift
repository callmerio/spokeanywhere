import AppKit
import SwiftUI

private typealias DS = DesignTokens

// MARK: - Service Card Row (可展开卡片)

struct ServiceCardRow: View {
    @Binding var profile: ProviderProfile
    let isExpanded: Bool
    let isActive: Bool
    let isTranscription: Bool
    let isChat: Bool
    let isSummary: Bool
    let hasAPIKey: Bool
    let modelRefreshTrigger: UUID
    @Binding var isTesting: Bool
    @Binding var testResult: AISettingsContent.TestResult?
    let onTap: () -> Void
    let onSetActive: () -> Void
    let onSetTranscription: () -> Void
    let onSetChat: () -> Void
    let onSetSummary: () -> Void
    let onSetAPIKey: () -> Void
    let onTest: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let getAPIKey: () -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 主行（始终显示）
            HStack(spacing: 12) {
                // Provider 图标
                ProviderIconView(provider: profile.providerType, size: 32)

                // 名称和副标题
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text(profile.modelName.isEmpty ? profile.providerType.displayName : profile.modelName)
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                // Badges
                HStack(spacing: 4) {
                    if isTranscription {
                        Text("转录")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Colors.error.opacity(0.8))
                            .cornerRadius(4)
                    }

                    if isChat {
                        Text("对话")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Colors.success.opacity(0.8))
                            .cornerRadius(4)
                    }

                    if isSummary {
                        Text("总结")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DS.Colors.warning.opacity(0.8))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // 配置按钮
                Button(action: onTap, label: {
                    Text(isExpanded ? "完成" : "配置")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(isExpanded ? DS.Colors.accentPrimary : DS.Colors.buttonHover)
                        .cornerRadius(6)
                })
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 展开的配置区域
            if isExpanded {
                Divider().background(DS.Colors.settingsCardBorder)

                ServiceCardExpandedContent(
                    profile: $profile,
                    hasAPIKey: hasAPIKey,
                    modelRefreshTrigger: modelRefreshTrigger,
                    isTesting: $isTesting,
                    testResult: $testResult,
                    onSetAPIKey: onSetAPIKey,
                    onTest: onTest,
                    onDelete: onDelete,
                    getAPIKey: getAPIKey
                )
            }
        }
        .contextMenu {
            Button(action: onSetTranscription, label: {
                Label("设为转录模型", systemImage: "waveform")
            })

            Button(action: onSetChat, label: {
                Label("设为对话模型", systemImage: "bubble.left.and.bubble.right")
            })

            Button(action: onSetSummary, label: {
                Label("设为总结模型", systemImage: "text.quote")
            })

            Divider()

            Button(action: onSetActive, label: {
                Label("设为默认", systemImage: "checkmark.circle")
            })

            Divider()

            Button(action: onDuplicate, label: {
                Label("复制配置", systemImage: "doc.on.doc")
            })
        }
    }
}

struct ServiceCardExpandedContent: View {
    @Binding var profile: ProviderProfile
    let hasAPIKey: Bool
    let modelRefreshTrigger: UUID
    @Binding var isTesting: Bool
    @Binding var testResult: AISettingsContent.TestResult?
    let onSetAPIKey: () -> Void
    let onTest: () -> Void
    let onDelete: () -> Void
    let getAPIKey: () -> String?

    @State private var copiedAPIKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 配置名称
            configRow(title: "名称") {
                TextField("配置名称", text: $profile.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DS.Colors.rowHover)
                    .cornerRadius(6)
            }

            // API Key
            if profile.providerType.requiresAPIKey {
                configRow(title: "API Key") {
                    HStack {
                        if hasAPIKey {
                            // 始终显示掩码格式：前8位 + ... + 后4位
                            if let key = getAPIKey() {
                                let masked = key.count > 12
                                    ? String(key.prefix(8)) + "..." + String(key.suffix(4))
                                    : String(repeating: "•", count: key.count)
                                Text(masked)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(DS.Colors.textPrimary.opacity(0.8))
                                    .lineLimit(1)
                            } else {
                                HStack(spacing: 4) {
                                    ForEach(0..<30, id: \.self) { _ in
                                        Circle()
                                            .fill(DS.Colors.textPrimary.opacity(0.6))
                                            .frame(width: 4, height: 4)
                                    }
                                }
                            }

                            // 复制按钮（复制完整 Key）
                            Button(action: copyAPIKey, label: {
                                Image(systemName: copiedAPIKey ? "checkmark" : "doc.on.doc")
                                    .foregroundStyle(copiedAPIKey ? DS.Colors.success : DS.Colors.textSecondary)
                            })
                            .buttonStyle(.plain)
                            .help("复制 API Key")
                        } else {
                            Text("未配置")
                                .font(.system(size: 13))
                                .foregroundStyle(DS.Colors.warning)
                        }

                        Spacer()

                        Button(hasAPIKey ? "修改" : "设置") {
                            onSetAPIKey()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DS.Colors.accentPrimary)
                        .buttonStyle(.plain)
                    }
                }

                // 官方文档链接
                if let docURL = providerDocURL {
                    HStack {
                        Spacer()
                        Link(destination: docURL) {
                            HStack(spacing: 4) {
                                Text("获取 API Key")
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Colors.accentPrimary)
                        }
                    }
                    .padding(.top, -8)
                }
            }

            // 模型选择（智能下拉 + 手动输入）
            configRow(title: "模型") {
                ModelPickerView(
                    selectedModel: $profile.modelName,
                    profile: profile,
                    placeholder: profile.providerType.defaultModel,
                    refreshTrigger: modelRefreshTrigger
                )
            }

            // API 地址（仅当不是默认地址时显示）
            configRow(title: "API 地址") {
                TextField(
                    profile.providerType.defaultBaseURL.isEmpty
                        ? "https://api.example.com/v1"
                        : profile.providerType.defaultBaseURL,
                    text: $profile.baseURL
                )
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DS.Colors.rowHover)
                    .cornerRadius(6)
            }

            // 开启思考（仅对支持思考的模型有效，如 Gemini 2.5+）
            if profile.baseURL.contains("v1beta") || profile.providerType == .googleGemini {
                configRow(title: "开启思考") {
                    HStack {
                        Text(profile.enableThinking ? "已开启" : "已关闭")
                            .font(.system(size: 12))
                            .foregroundStyle(profile.enableThinking ? DS.Colors.success : DS.Colors.textSecondary)

                        Spacer()

                        Toggle("", isOn: $profile.enableThinking)
                            .toggleStyle(.switch)
                            .tint(DS.Colors.accentPrimary)
                    }
                }

                if profile.enableThinking {
                    HStack {
                        Spacer()
                        Text("开启思考会增加响应时间和 token 消耗，但推理更准确")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .padding(.top, -8)
                }

                // Google Search 联网（Gemini 模型支持）
                configRow(title: "联网搜索") {
                    HStack {
                        Text(profile.enableSearchGrounding ? "已启用" : "已禁用")
                            .font(.system(size: 12))
                            .foregroundStyle(
                                profile.enableSearchGrounding
                                    ? DS.Colors.success
                                    : DS.Colors.textSecondary
                            )

                        Spacer()

                        Toggle("", isOn: $profile.enableSearchGrounding)
                            .toggleStyle(.switch)
                            .tint(DS.Colors.accentPrimary)
                    }
                }

                if profile.enableSearchGrounding {
                    HStack {
                        Spacer()
                        Text("启用后模型可调用 Google Search 获取实时信息")
                            .font(.system(size: 10))
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .padding(.top, -8)
                }
            }

            Divider().background(DS.Colors.settingsCardBorder)

            // 底部操作栏
            HStack {
                // 测试连接
                Button(action: onTest, label: {
                    HStack(spacing: 6) {
                        if isTesting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "network")
                                .font(.system(size: 12))
                        }
                        Text(isTesting ? "测试中..." : "测试连接")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DS.Colors.rowHover)
                    .cornerRadius(6)
                })
                .buttonStyle(.plain)
                .disabled(isTesting)

                if let result = testResult {
                    HStack(spacing: 4) {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Colors.success)
                            Text("连接成功")
                                .foregroundStyle(DS.Colors.success)
                        case .failure(let msg):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(DS.Colors.error)
                            Text(msg)
                                .foregroundStyle(DS.Colors.error)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(msg)
                        }
                    }
                    .font(.system(size: 11))
                }

                Spacer()

                // 删除按钮
                Button(action: onDelete, label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.Colors.error.opacity(0.8))
                        .padding(8)
                        .background(DS.Colors.rowHover)
                        .cornerRadius(6)
                })
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(DS.Colors.surfaceThin)
    }

    private func configRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(width: 70, alignment: .leading)

            content()
        }
    }

    private var providerDocURL: URL? {
        switch profile.providerType {
        case .openai:
            return URL(string: "https://platform.openai.com/api-keys")
        case .anthropic:
            return URL(string: "https://console.anthropic.com/settings/keys")
        case .googleGemini:
            return URL(string: "https://aistudio.google.com/app/apikey")
        case .groq:
            return URL(string: "https://console.groq.com/keys")
        case .openRouter:
            return URL(string: "https://openrouter.ai/keys")
        case .ollama, .openAICompatible:
            return nil
        }
    }

    private func copyAPIKey() {
        if let key = getAPIKey() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(key, forType: .string)
            copiedAPIKey = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copiedAPIKey = false
            }
        }
    }
}
