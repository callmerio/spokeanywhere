import SwiftUI

private typealias DS = DesignTokens

// MARK: - Add Dictionary Entry Sheet

struct AddDictionaryEntrySheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var dictionaryService = DictionaryService.shared
    
    @State private var word = ""
    @State private var correctionsText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // 标题
            HStack {
                Text("添加词条")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DS.Layout.iconSizeSmall, weight: .semibold))
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            // 词条输入
            VStack(alignment: .leading, spacing: 8) {
                Text("期望词形")
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Colors.textSecondary)
                
                TextField("如: Anthropic, Claude, GPT-4", text: $word)
                    .textFieldStyle(.plain)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.settingsCardBackground)
                    .cornerRadius(DS.CornerRadius.md)
            }
            
            // 纠错映射输入
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("纠错映射（可选）")
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Colors.textSecondary)
                    
                    Text("每行一个")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
                }
                
                TextEditor(text: $correctionsText)
                    .font(DS.Typography.button)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.lg)
                    .background(DS.Colors.settingsCardBackground)
                    .cornerRadius(DS.CornerRadius.md)
                    .frame(height: 80)
                
                Text("转录引擎可能识别成的错误形式，后处理时会自动替换为正确词形")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.7))
            }
            
            if showError {
                Text(errorMessage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.error)
            }
            
            // 操作按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.textSecondary)
                
                Spacer()
                
                Button("添加") {
                    addEntry()
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.warning)
                .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 400)
        .background(DS.Colors.settingsPanelBackground)
    }
    
    private func addEntry() {
        let corrections = correctionsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        if dictionaryService.addEntry(word: word, corrections: corrections) != nil {
            isPresented = false
        } else {
            showError = true
            errorMessage = "词条已存在或格式无效"
        }
    }
}
