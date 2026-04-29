import SwiftUI

private typealias DS = DesignTokens

struct DictionaryResultView: View {
    let word: String
    let data: DictionaryData?
    let error: DictionaryAPIError?
    let onDismiss: () -> Void
    
    @State private var isAppearing = false
    
    var body: some View {
        Button {
            onDismiss()
        } label: {
            HStack(spacing: DS.Spacing.lg) {
                if let data = data {
                    successContent(data)
                } else if let error = error {
                    errorContent(error)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.lg)
        .background(backgroundView)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isAppearing = true
            }
        }
        .scaleEffect(isAppearing ? 1 : 0.9)
        .opacity(isAppearing ? 1 : 0)
    }
    
    // MARK: - Success Content
    
    @ViewBuilder
    private func successContent(_ data: DictionaryData) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.xl) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(data.word)
                    .font(DS.Typography.titleLarge)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                if let phonetic = data.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary.opacity(0.8))
                }
            }
            .frame(minWidth: 60)
            
            Divider()
                .frame(height: DS.Layout.toolbarHeight)
                .background(DS.Colors.borderSecondary)
            
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(Array(data.senses.prefix(3).enumerated()), id: \.offset) { _, sense in
                    senseRow(sense)
                }
            }
        }
    }
    
    @ViewBuilder
    private func senseRow(_ sense: DictionarySense) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            if !sense.posDisplay.isEmpty {
                Text(sense.posDisplay)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(DS.Colors.accentPrimary.opacity(0.9))
                    .frame(minWidth: 30, alignment: .leading)
            }
            
            if let chinese = sense.chinese {
                Text(chinese)
                    .font(DS.Typography.content)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2)
            }
        }
    }
    
    // MARK: - Error Content
    
    @ViewBuilder
    private func errorContent(_ error: DictionaryAPIError) -> some View {
        HStack(spacing: DS.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Typography.titleLarge)
                .foregroundStyle(DS.Colors.warning)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(word)
                    .font(DS.Typography.bodySecondary)
                    .foregroundStyle(DS.Colors.textPrimary)
                
                Text(error.localizedDescription)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary.opacity(0.85))
            }
        }
    }
    
    // MARK: - Background
    
    private var backgroundView: some View {
        let shadow = DS.Shadow.far()

        return ZStack {
            // 毛玻璃效果（与工具栏/字幕卡片一致）
            VisualEffectBlur(material: .hudWindow, cornerRadius: DS.CornerRadius.lg)
            // 深色叠加
            DS.Colors.captionCardBackground
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.CornerRadius.lg)
                .strokeBorder(DS.Colors.borderPrimary, lineWidth: DS.BorderWidth.hairline)
        )
        .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Preview

#Preview("Dictionary Result") {
    VStack(spacing: 20) {
        DictionaryResultView(
            word: "prisoner",
            data: DictionaryData(
                word: "prisoner",
                phonetic: "/ˈprɪz.ən.ər/",
                senses: [
                    DictionarySense(pos: "noun", chinese: "被监禁在监狱中", english: nil, examples: nil),
                    DictionarySense(pos: "noun", chinese: "任何被违背其意愿拘禁的人。", english: nil, examples: nil),
                    DictionarySense(pos: "noun", chinese: "因某种情况或环境而感到受限或被困的人。", english: nil, examples: nil)
                ],
                lemma: nil,
                lemmaInfo: nil
            ),
            error: nil,
            onDismiss: {}
        )
        
        DictionaryResultView(
            word: "hello",
            data: DictionaryData(
                word: "hello",
                phonetic: "/həˈloʊ/",
                senses: [
                    DictionarySense(pos: "interjection", chinese: "你好；喂", english: nil, examples: nil)
                ],
                lemma: nil,
                lemmaInfo: nil
            ),
            error: nil,
            onDismiss: {}
        )
        
        DictionaryResultView(
            word: "xyz",
            data: nil,
            error: .notFound,
            onDismiss: {}
        )
    }
    .padding()
    .background(DS.Colors.settingsBackground)
}
