import SwiftUI

private typealias DS = DesignTokens

// MARK: - Batch Import Sheet

struct BatchImportSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var dictionaryService = DictionaryService.shared
    
    @State private var importText = ""
    @State private var importResult: DictionaryImportResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            // 标题
            HStack {
                Text("批量导入")
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
            
            // 说明
            Text("每行一个词条，支持格式：")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text("• 简单格式: 词条名")
                Text("• 带纠错: 词条名=错误形式1,错误形式2")
            }
            .font(.system(size: DS.Typography.fontSizeCaptionSmall, design: .monospaced))
            .foregroundStyle(DS.Colors.textSecondary.opacity(0.8))
            .padding(DS.Spacing.lg)
            .background(DS.Colors.settingsCardBorder.opacity(0.5))
            .cornerRadius(DS.CornerRadius.md)
            
            // 输入框
            TextEditor(text: $importText)
                .font(.system(size: DS.Typography.fontSizeButton, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(DS.Spacing.lg)
                .background(DS.Colors.settingsCardBackground)
                .cornerRadius(DS.CornerRadius.md)
                .frame(height: 200)
            
            // 导入结果
            if let result = importResult {
                HStack(spacing: DS.Spacing.xl) {
                    Label("\(result.successCount) 成功", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.success)
                    
                    if result.duplicateCount > 0 {
                        Label("\(result.duplicateCount) 重复", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(DS.Colors.warning)
                    }
                    
                    if result.errorCount > 0 {
                        Label("\(result.errorCount) 失败", systemImage: "xmark.circle.fill")
                            .foregroundStyle(DS.Colors.error)
                    }
                }
                .font(DS.Typography.caption)
            }
            
            // 操作按钮
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .tint(DS.Colors.textSecondary)
                
                Spacer()
                
                Button("导入") {
                    importResult = dictionaryService.batchImport(from: importText)
                    if importResult?.successCount ?? 0 > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isPresented = false
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.Colors.warning)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 450)
        .background(DS.Colors.settingsPanelBackground)
    }
}
