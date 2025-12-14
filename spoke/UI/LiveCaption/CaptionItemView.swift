import SwiftUI

// MARK: - Caption Item View

/// 独立的字幕项视图组件
/// 通过 @ObservedObject 订阅单个 CaptionItem 的变化
/// 当 translation 更新时，只有该视图重新渲染，不触发 ForEach 重布局
struct CaptionItemView<OriginalContent: View>: View {
    @ObservedObject var item: CaptionItem
    let isNew: Bool
    let translationFontSize: CGFloat
    let translationColor: Color
    let originalContent: () -> OriginalContent
    
    init(
        item: CaptionItem,
        isNew: Bool,
        translationFontSize: CGFloat,
        translationColor: Color,
        @ViewBuilder originalContent: @escaping () -> OriginalContent
    ) {
        self.item = item
        self.isNew = isNew
        self.translationFontSize = translationFontSize
        self.translationColor = translationColor
        self.originalContent = originalContent
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 原文（由外部提供，支持生词高亮等）
            originalContent()
            
            // 译文容器 - 三层防御的核心
            translationView
        }
    }
    
    // MARK: - Translation View
    
    /// 译文视图 - 使用 .transaction 阻断所有继承的动画
    @ViewBuilder
    private var translationView: some View {
        let hasTranslation = item.translation != nil && !item.translation!.isEmpty
        
        Text(item.translation ?? " ")
            .font(.system(size: translationFontSize, weight: .regular))
            .foregroundColor(translationColor)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            // 🔥 Layer 3: 阻断所有继承的动画事务
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            // 禁用内容变换动画
            .contentTransition(.identity)
            // 只对 opacity 应用动画（不影响布局）
            .opacity(hasTranslation ? (isNew ? 0.7 : 1.0) : 0)
            .animation(.easeOut(duration: 0.25), value: hasTranslation)
    }
}

// MARK: - Pending Text View

/// 流式文本视图（正在输入的内容）
struct PendingTextView: View {
    let pendingText: String
    let pendingTranslation: String
    let fontSize: CGFloat
    let translationFontSize: CGFloat
    let textColor: Color
    let translationColor: Color
    let highlightVocabulary: (String) -> Text
    
    var body: some View {
        let hasPendingTranslation = !pendingTranslation.isEmpty
        
        VStack(alignment: .leading, spacing: 4) {
            // 流式原文
            highlightVocabulary(pendingText)
                .font(.system(size: fontSize))
                .foregroundColor(textColor.opacity(0.7))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // 流式译文
            if hasPendingTranslation {
                Text(pendingTranslation)
                    .font(.system(size: translationFontSize, weight: .regular))
                    .foregroundColor(translationColor.opacity(0.7))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    // 阻断动画
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
                    .contentTransition(.identity)
            }
        }
    }
}
