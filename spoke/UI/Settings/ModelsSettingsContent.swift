import SwiftUI

private typealias DS = DesignTokens

// MARK: - Models Settings

struct ModelsSettingsContent: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            TranscriptionModelSettingsView()
        } else {
            // Fallback for older macOS versions
            ModelsSettingsContentLegacy()
        }
    }
}

/// Legacy model settings for macOS < 26
struct ModelsSettingsContentLegacy: View {
    @AppStorage("SelectedDictationModel") private var selectedModel: String = "apple_ondevice"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Speech Recognition Engine")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.leading, 4)
            
            SettingsCard {
                ModelOptionRow(
                    icon: "apple.logo",
                    title: "Apple Dictation",
                    description: "Built-in, offline, privacy-first",
                    isSelected: selectedModel == "apple_ondevice",
                    isAvailable: true
                ) {
                    selectedModel = "apple_ondevice"
                }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                ModelOptionRow(
                    icon: "waveform.badge.magnifyingglass",
                    title: "Apple SpeechTranscriber",
                    description: "Stronger model, requires macOS 26+",
                    isSelected: false,
                    isAvailable: false,
                    comingSoon: true
                ) { }
                
                Divider().background(DS.Colors.settingsCardBorder)
                
                ModelOptionRow(
                    icon: "cloud",
                    title: "OpenAI Whisper",
                    description: "Cloud processing, high accuracy",
                    isSelected: selectedModel == "openai_whisper",
                    isAvailable: false,
                    comingSoon: true
                ) { }
            }
        }
    }
}

struct ModelOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let isAvailable: Bool
    var comingSoon: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(
                        isAvailable
                            ? DS.Colors.textSecondary
                            : DS.Colors.textSecondary.opacity(0.5)
                    )
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isAvailable ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                        
                        if comingSoon {
                            Text("Coming Soon")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(DS.Colors.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DS.Colors.buttonHover)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.accentPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

// MARK: - AI Settings (Screenium 风格单列布局)
