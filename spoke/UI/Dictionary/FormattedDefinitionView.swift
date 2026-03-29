import SwiftUI

// MARK: - Formatted Definition View

struct FormattedDefinitionView: View {
    let result: LocalDictionaryResult
    let isVocabulary: Bool
    private let dependencies: FormattedDefinitionViewDependencies
    var onWordTap: ((String) -> Void)?
    
    private var parsedDefinition: ParsedDefinition {
        dependencies.parse(result.word, result.definition)
    }

    init(
        result: LocalDictionaryResult,
        isVocabulary: Bool,
        onWordTap: ((String) -> Void)? = nil
    ) {
        self.init(
            result: result,
            isVocabulary: isVocabulary,
            dependencies: .live,
            onWordTap: onWordTap
        )
    }

    @MainActor
    init(
        result: LocalDictionaryResult,
        isVocabulary: Bool,
        dependencies: FormattedDefinitionViewDependencies,
        onWordTap: ((String) -> Void)? = nil
    ) {
        self.result = result
        self.isVocabulary = isVocabulary
        self.dependencies = dependencies
        self.onWordTap = onWordTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            
            Divider().background(DesignTokens.Colors.borderPrimary)
            
            if parsedDefinition.sections.isEmpty {
                rawDefinitionView
            } else {
                formattedSectionsView
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(result.word)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(isVocabulary ? DesignTokens.Colors.warning : DesignTokens.Colors.textPrimary)
                
                if let phonetic = parsedDefinition.phonetic ?? result.phonetic {
                    Text("| \(phonetic) |")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignTokens.Colors.textSecondary.opacity(0.8))
                }
            }
        }
    }
    
    // MARK: - Formatted Sections
    
    private var formattedSectionsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(Array(parsedDefinition.sections.enumerated()), id: \.offset) { index, section in
                sectionView(section, index: index)
            }
        }
    }
    
    private func sectionView(_ section: DefinitionSection, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let label = section.label {
                    Text("\(label).")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }
                
                if !section.pos.isEmpty {
                    Text(section.pos)
                        .font(.system(size: 15, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(section.senses) { sense in
                    senseView(sense)
                }
            }
            .padding(.leading, 8)
        }
    }
    
    private func senseView(_ sense: DefinitionSense) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                if let number = sense.number {
                    Text(number)
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 20, alignment: .leading)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    senseMeaningRow(sense)
                    
                    if !sense.examples.isEmpty {
                        examplesView(sense.examples)
                    }
                }
            }
        }
    }
    
    private func senseMeaningRow(_ sense: DefinitionSense) -> some View {
        HStack(spacing: 6) {
            if let gloss = sense.gloss {
                Text(gloss)
                    .font(.system(size: 14))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            
            if let chinese = sense.chinese {
                Text(chinese)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }
            
            if let pinyin = sense.pinyin {
                Text(pinyin)
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.Colors.textPlaceholder)
            }
        }
    }
    
    private func examplesView(_ examples: [DefinitionExample]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 每个义项最多显示1个例句
            ForEach(examples.prefix(1)) { example in
                exampleRow(example)
            }
        }
        .padding(.leading, 4)
    }
    
    private func exampleRow(_ example: DefinitionExample) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("‣")
                .font(.system(size: 13))
                .foregroundStyle(DesignTokens.Colors.textPlaceholder)
            
            VStack(alignment: .leading, spacing: 3) {
                clickableEnglishText(example.english)
                
                if let chinese = example.chinese {
                    Text(chinese)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                }
            }
        }
    }
    
    // MARK: - Clickable English Text (单词跳转)
    
    @ViewBuilder
    private func clickableEnglishText(_ text: String) -> some View {
        if onWordTap != nil {
            // 将英文分词，每个单词可点击
            let words = text.components(separatedBy: .whitespaces)
            WrappingHStack(alignment: .leading, spacing: 4) {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    let cleanWord = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                    Text(word)
                        .font(.system(size: 14))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .underline(cleanWord.count > 2, color: DesignTokens.Colors.textSecondary.opacity(0.3))
                        .onTapGesture {
                            if cleanWord.count > 2 {
                                onWordTap?(cleanWord.lowercased())
                            }
                        }
                }
            }
        } else {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
    }
    
    // MARK: - Raw Definition Fallback
    
    private var rawDefinitionView: some View {
        Text(result.definition)
            .font(DesignTokens.Typography.content)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .lineSpacing(DesignTokens.LineSpacing.normal)
            .textSelection(.enabled)
    }
}

// MARK: - Wrapping HStack (for clickable words)

struct WrappingHStack: Layout {
    var alignment: Alignment = .leading
    var spacing: CGFloat = 4
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX)
            totalHeight = currentY + lineHeight
        }
        
        return (CGSize(width: totalWidth, height: totalHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        FormattedDefinitionView(
            result: LocalDictionaryResult(
                word: "part",
                definition: """
                part | BrE pɑːt, AmE pɑrt |
                A. noun
                ① (piece, section) 部分 bùfen‣ the eastern/northern part 东部/北部‣ I'm only here part of the time 我只是部分时间在这里
                ② Motor Vehicles, Technology 部件 bùjiàn‣ parts and labour 零件带人工费
                B. verb
                ① (separate) 分开 fēnkāi
                """,
                pos: "noun",
                phonetic: "BrE pɑːt, AmE pɑrt",
                chineseDefinition: "部分"
            ),
            isVocabulary: true
        )
        .padding()
    }
    .frame(width: 600, height: 400)
    .background(DesignTokens.Colors.settingsBackground)
}
