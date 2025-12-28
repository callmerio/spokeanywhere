import SwiftUI

private typealias DS = DesignTokens

// MARK: - TTS Settings

struct TTSSettingsContent: View {
    @ObservedObject private var settings = TTSSettings.shared
    @ObservedObject private var ttsService = TTSService.shared
    @State private var isTesting = false
    @State private var testText = "你好，这是语音合成测试。Hello, this is a TTS test."
    @State private var testStartTime: Date?
    @State private var latencyMs: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 服务选择
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("语音合成服务")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    ForEach(TTSProvider.allCases, id: \.self) { provider in
                        TTSProviderRow(
                            provider: provider,
                            isSelected: settings.provider == provider,
                            onSelect: { settings.provider = provider }
                        )
                    }
                }
            }
            
            // Edge TTS 配置
            if settings.provider == .edge {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 20) {
                        // 标题区
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Edge TTS 配置")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DS.Colors.textPrimary)
                            
                            Text("使用微软 Edge 浏览器的 TTS 服务，免费且音质好")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Divider().opacity(0.3)
                        
                        // 语音选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("语音角色")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DS.Colors.textPrimary.opacity(0.9))
                            
                            Picker("", selection: $settings.edgeVoice) {
                                ForEach(EdgeVoice.allCases, id: \.self) { voice in
                                    Text(voice.displayName).tag(voice)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // 语速
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("语速")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.Colors.textPrimary.opacity(0.9))
                                
                                Spacer()
                                
                                Text("\(settings.edgeRate >= 0 ? "+" : "")\(settings.edgeRate)%")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(DS.Colors.accentPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(DS.Colors.accentPrimary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(settings.edgeRate) },
                                set: { settings.edgeRate = Int($0) }
                            ), in: -50...100, step: 10)
                            .tint(DS.Colors.accentPrimary)
                        }
                        
                        // 音调
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("音调")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(DS.Colors.textPrimary.opacity(0.9))
                                
                                Spacer()
                                
                                Text("\(settings.edgePitch >= 0 ? "+" : "")\(settings.edgePitch)Hz")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(settings.edgePitch) },
                                set: { settings.edgePitch = Int($0) }
                            ), in: -50...50, step: 5)
                            .tint(.purple)
                        }
                    }
                }
            }
            
            // 系统 TTS 配置
            if settings.provider == .system {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("系统语音配置")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                        
                        HStack {
                            Text("语速")
                                .font(.system(size: 12))
                                .foregroundStyle(DS.Colors.textSecondary)
                            
                            Slider(value: $settings.systemRate, in: 0...1, step: 0.1)
                            
                            Text(String(format: "%.1f", settings.systemRate))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .frame(width: 40)
                        }
                    }
                }
            }
            
            // 朗读设置
            SettingsCard {
                VStack(alignment: .leading, spacing: 20) {
                    Text("朗读设置")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Divider().opacity(0.3)
                    
                    // 自动朗读
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 16))
                            .foregroundStyle(DS.Colors.accentPrimary)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("自动朗读回复")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("AI 回复后自动开始朗读")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.autoReadAloud)
                            .toggleStyle(.switch)
                            .tint(DS.Colors.accentPrimary)
                    }
                    
                    // 分块大小
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "square.grid.3x3")
                                .font(.system(size: 14))
                                .foregroundStyle(DS.Colors.success)
                                .frame(width: 28)
                            
                            Text("分块大小")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DS.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text("\(settings.chunkSize) 字")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(DS.Colors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(DS.Colors.success.opacity(0.15))
                                .cornerRadius(4)
                        }
                        
                        HStack(spacing: 12) {
                            Text("50")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            
                            Slider(value: Binding(
                                get: { Double(settings.chunkSize) },
                                set: { settings.chunkSize = Int($0) }
                            ), in: 50...500, step: 50)
                            .tint(DS.Colors.success)
                            
                            Text("500")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 40)
                        
                        Text("分块朗读可减少首次响应延迟，数值越小延迟越低")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 40)
                    }
                }
            }
            
            // 测试区域
            SettingsCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("测试语音")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.Colors.textPrimary)
                        
                        Spacer()
                        
                        // 延迟显示
                        if let latency = latencyMs {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("首音延迟: \(latency)ms")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                            .foregroundStyle(
                                latency < 1000
                                    ? DS.Colors.success
                                    : (latency < 2000 ? DS.Colors.warning : DS.Colors.error)
                            )
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DS.Colors.rowHover)
                            .cornerRadius(4)
                        }
                    }
                    
                    // 测试文本输入
                    TextEditor(text: $testText)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(height: 80)
                        .background(DS.Colors.rowHover)
                        .cornerRadius(DS.CornerRadius.md)
                    
                    // 进度显示
                    if isTesting && ttsService.totalChunks > 1 {
                        HStack(spacing: 8) {
                            ProgressView(
                                value: Double(ttsService.currentChunkIndex + 1),
                                total: Double(ttsService.totalChunks)
                            )
                                .progressViewStyle(.linear)
                                .tint(DS.Colors.accentPrimary)
                            
                            Text("\(ttsService.currentChunkIndex + 1)/\(ttsService.totalChunks)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                    }
                    
                    // 按钮区域
                    HStack(spacing: 12) {
                        Button(action: testTTS, label: {
                            HStack(spacing: 6) {
                                if ttsService.isSynthesizing {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: isTesting ? "stop.fill" : "play.fill")
                                }
                                Text(isTesting ? (ttsService.isSynthesizing ? "合成中..." : "播放中") : "开始测试")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isTesting ? DS.Colors.warning : DS.Colors.accentPrimary)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .cornerRadius(DS.CornerRadius.md)
                        })
                        .buttonStyle(.plain)
                        
                        // 重置按钮
                        Button(action: { latencyMs = nil }, label: {
                            Image(systemName: "arrow.counterclockwise")
                                .padding(10)
                                .background(DS.Colors.rowHover)
                                .cornerRadius(DS.CornerRadius.md)
                        })
                        .buttonStyle(.plain)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .help("重置延迟统计")
                    }
                    
                    // 提示
                    Text("测试将使用当前分块设置 (\(settings.chunkSize)字/块)")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .onChange(of: ttsService.isPlaying) { _, isPlaying in
            if !isPlaying && isTesting {
                isTesting = false
            }
            // 计算首音延迟
            if isPlaying, let startTime = testStartTime {
                latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)
                testStartTime = nil
            }
        }
    }
    
    private func testTTS() {
        if isTesting {
            TTSService.shared.stop()
            isTesting = false
            testStartTime = nil
        } else {
            isTesting = true
            testStartTime = Date()  // 记录开始时间
            TTSService.shared.speak(testText)
        }
    }
}

// MARK: - TTS Provider Row

private struct TTSProviderRow: View {
    let provider: TTSProvider
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect, label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? DS.Colors.accentPrimary : DS.Colors.textSecondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)
                    
                    Text(provider.description)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(isSelected ? DS.Colors.accentPrimary.opacity(0.1) : Color.clear)
            .cornerRadius(DS.CornerRadius.md)
        })
        .buttonStyle(.plain)
    }
}
