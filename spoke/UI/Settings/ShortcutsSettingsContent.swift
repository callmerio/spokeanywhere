import AppKit
import SwiftUI

private typealias DS = DesignTokens

// MARK: - Shortcuts Settings

struct ShortcutsSettingsContent: View {
    @ObservedObject var appSettings: AppSettings
    @State private var isRecordingShortcut = false
    @State private var isRecordingQuickAskShortcut = false
    @State private var isRecordingMessagePanelShortcut = false
    @State private var isRecordingLiveCaptionShortcut = false
    @State private var isRecordingClipboardPipelineShortcut = false
    @State private var isRecordingScreenshotShortcut = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("全局快捷键")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, 4)
            
            SettingsCard {
                SettingsRow(icon: "record.circle", title: "触发录音", description: "按下快捷键开始/停止录音") {
                    ShortcutRecorderButton(
                        isRecording: $isRecordingShortcut,
                        currentShortcut: appSettings.shortcutDisplayString,
                        onShortcutCaptured: { keyCode, modifiers in
                            appSettings.updateShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                    )
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                SettingsRow(icon: "bubble.left.and.bubble.right", title: "Quick Ask", description: "快速向 AI 提问") {
                    ShortcutRecorderButton(
                        isRecording: $isRecordingQuickAskShortcut,
                        currentShortcut: appSettings.quickAskShortcutDisplayString,
                        onShortcutCaptured: { keyCode, modifiers in
                            appSettings.updateQuickAskShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                    )
                }
                
                Divider().background(DS.Colors.settingsCardBorder)

                SettingsRow(icon: "menubar.rectangle", title: "消息面板", description: "显示或隐藏消息面板") {
                    ShortcutRecorderButton(
                        isRecording: $isRecordingMessagePanelShortcut,
                        currentShortcut: appSettings.messagePanelShortcutDisplayString,
                        onShortcutCaptured: { keyCode, modifiers in
                            appSettings.updateMessagePanelShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                    )
                }

                Divider().background(DS.Colors.settingsCardBorder)

                SettingsRow(icon: "captions.bubble", title: "实时字幕", description: "开始或关闭实时字幕") {
                    ShortcutRecorderButton(
                        isRecording: $isRecordingLiveCaptionShortcut,
                        currentShortcut: appSettings.liveCaptionShortcutDisplayString,
                        onShortcutCaptured: { keyCode, modifiers in
                            appSettings.updateLiveCaptionShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                    )
                }

                Divider().background(DS.Colors.settingsCardBorder)

                SettingsRow(icon: "doc.on.clipboard", title: "剪贴板注入", description: "读取剪贴板并发送到消息面板") {
                    ShortcutRecorderButton(
                        isRecording: $isRecordingClipboardPipelineShortcut,
                        currentShortcut: appSettings.clipboardPipelineShortcutDisplayString,
                        onShortcutCaptured: { keyCode, modifiers in
                            appSettings.updateClipboardPipelineShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                    )
                }

                Divider().background(DS.Colors.settingsCardBorder)

                SettingsRow(icon: "camera.viewfinder", title: "区域截图", description: "截取屏幕区域并钉住") {
                    ShortcutRecorderButton(
                        isRecording: $isRecordingScreenshotShortcut,
                        currentShortcut: appSettings.screenshotShortcutDisplayString,
                        onShortcutCaptured: { keyCode, modifiers in
                            appSettings.updateScreenshotShortcut(keyCode: keyCode, modifiers: modifiers)
                        }
                    )
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 16))
                            .foregroundStyle(DS.Colors.textSecondary)
                            .frame(width: 24)
                        
                        Text("触发模式")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(DS.Colors.textPrimary)
                    }
                    
                    Picker("", selection: $appSettings.recordingMode) {
                        ForEach(AppSettings.RecordingMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.leading, 38)
                    
                    Text("智能混合：短按切换录音状态，长按保持录音（松开结束）")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textSecondary)
                        .padding(.leading, 38)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .background(DS.Colors.rowHover)
                
                // 边说边打字
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $appSettings.realtimeTypingEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 16))
                                .foregroundStyle(DS.Colors.textPrimary.opacity(0.7))
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("边说边打字")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(DS.Colors.textPrimary)
                                
                                Text("实时将语音转录输入到当前应用")
                                    .font(.system(size: 11))
                                    .foregroundStyle(DS.Colors.textSecondary)
                            }
                        }
                    }
                    .toggleStyle(.switch)
                    
                    if appSettings.realtimeTypingEnabled {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11))
                            Text("开启后，语音转录将直接输入到光标位置，HUD 仅显示波形")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.orange.opacity(0.8))
                        .padding(.leading, 38)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Shortcut Recorder Button

struct ShortcutRecorderButton: View {
    @Binding var isRecording: Bool
    let currentShortcut: String
    let onShortcutCaptured: (Int, Int) -> Void
    
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: { toggleRecording() }, label: {
            Text(isRecording ? "输入快捷键..." : currentShortcut)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isRecording ? DS.Colors.accentPrimary.opacity(0.3) : DS.Colors.rowHover)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? DS.Colors.accentPrimary : Color.clear, lineWidth: 1)
                )
        })
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        
        // 使用 NSEvent.addLocalMonitorForEvents 监听键盘事件
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            // Escape 取消录制
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }
            
            // 必须有修饰键
            guard !modifiers.isEmpty else { return event }
            
            // 忽略纯修饰键按下
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if modifierKeyCodes.contains(event.keyCode) { return event }
            
            // 捕获快捷键
            let keyCode = Int(event.keyCode)
            let modifiersRaw = Int(modifiers.rawValue)
            
            self.onShortcutCaptured(keyCode, modifiersRaw)
            self.stopRecording()
            
            return nil
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - History Settings
