import SwiftUI

private typealias DS = DesignTokens

// MARK: - General Settings

struct GeneralSettingsContent: View {
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var audioManager: AudioDeviceManager
    @ObservedObject var micTester: MicrophoneTester
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 启动与行为
            Text("启动与行为")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, 4)
            
            SettingsCard {
                SettingsRow(icon: "power", title: "开机自动启动", description: "登录时自动启动 SpokenAnyWhere") {
                    Toggle("", isOn: $appSettings.startAtLogin)
                        .toggleStyle(.switch)
                        .tint(DS.Colors.accentPrimary)
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                SettingsRow(icon: "dock.rectangle", title: "在程序坞中显示") {
                    Toggle("", isOn: $appSettings.showInDock)
                        .toggleStyle(.switch)
                        .tint(DS.Colors.accentPrimary)
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                SettingsRow(icon: "menubar.rectangle", title: "在菜单栏中显示图标") {
                    Toggle("", isOn: $appSettings.showInMenuBar)
                        .toggleStyle(.switch)
                        .tint(DS.Colors.accentPrimary)
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                SettingsRow(icon: "escape", title: "按 ESC 键取消录音") {
                    Toggle("", isOn: $appSettings.pressEscToCancel)
                        .toggleStyle(.switch)
                        .tint(DS.Colors.accentPrimary)
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                SettingsRow(icon: "speaker.wave.2", title: "播放提示音效", description: "开始/结束录音时播放声音") {
                    Toggle("", isOn: $appSettings.playSoundEffect)
                        .toggleStyle(.switch)
                        .tint(DS.Colors.accentPrimary)
                }
            }
            
            // 音频设置
            Text("音频设置")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, 4)
                .padding(.top, 8)
            
            SettingsCard {
                SettingsRow(icon: "mic", title: "麦克风输入", description: "选择用于录音的麦克风设备") {
                    if audioManager.devices.isEmpty {
                        Text("无可用设备")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 180, alignment: .trailing)
                    } else {
                        Picker("", selection: $audioManager.currentInputDeviceId) {
                            ForEach(audioManager.devices) { device in
                                Text(device.name).tag(Optional(device.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 180)
                        .tint(DS.Colors.textPrimary)
                    }
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                // 真实麦克风测试
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Image(systemName: "waveform")
                            .font(.system(size: 16))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 24)
                        
                        Text("麦克风测试")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button(micTester.isRunning ? "停止" : "测试") {
                            if micTester.isRunning {
                                micTester.stop()
                            } else {
                                micTester.start()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(micTester.isRunning ? DS.Colors.warning : DS.Colors.accentPrimary)
                    }
                    
                    // 音量条 - macOS 原生风格 (长条疏朗版)
                    HStack(spacing: 5) {
                        ForEach(0..<20) { index in
                            Capsule()
                                .fill(
                                    // 根据音量决定是否点亮
                                    (Float(index) / 20.0) < micTester.level
                                        ? DS.Colors.textPrimary
                                        : DS.Colors.textPrimary.opacity(0.2)
                                )
                                .frame(width: 6, height: 12)
                                .animation(
                                    .interactiveSpring(response: 0.1, dampingFraction: 0.5),
                                    value: micTester.level
                                )
                        }
                    }
                    .padding(.leading, 38)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .onAppear {
            audioManager.refreshDevices()
        }
        .onDisappear {
            micTester.stop()
        }
        .onChange(of: audioManager.currentInputDeviceId) { _, _ in
            if micTester.isRunning {
                micTester.stop()
            }
        }
    }
}

// MARK: - Models Settings
