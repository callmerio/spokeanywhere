import SwiftUI

private typealias DS = DesignTokens

extension AnswerPanelView {
    // MARK: - Toolbar
    
    var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: { onClose?() }, label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHoveringCloseButton ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(isHoveringCloseButton ? DS.Colors.buttonHoverStrong : DS.Colors.buttonHover)
                    .clipShape(RoundedRectangle(cornerRadius: isHoveringCloseButton ? DS.CornerRadius.sm : DS.CornerRadius.md))
                    .animation(.easeInOut(duration: 0.2), value: isHoveringCloseButton)
            })
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringCloseButton = hovering
            }
            
            Spacer()
            
            Button(action: { onNewChat?() }, label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("新对话")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(isHoveringNewChatButton ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isHoveringNewChatButton ? DS.Colors.buttonHoverStrong : DS.Colors.clear)
                .clipShape(RoundedRectangle(cornerRadius: isHoveringNewChatButton ? DS.CornerRadius.sm : DS.CornerRadius.lg))
                .animation(.easeInOut(duration: 0.2), value: isHoveringNewChatButton)
            })
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringNewChatButton = hovering
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Loading
    
    var loadingView: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("思考中...")
                .font(.system(size: 14))
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Error
    
    func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Colors.error)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(12)
        .background(DS.Colors.accentDangerBackground.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.md))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Suggested Questions
    
    var suggestedQuestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(state.suggestedQuestions, id: \.self) { question in
                Button(action: { onFollowUp?(question, []) }, label: {
                    HStack {
                        Text(question)
                            .font(.system(size: 13))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textPlaceholder)
                    }
                    .padding(12)
                    .background(DS.Colors.surfaceThin)
                    .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.md))
                })
                .buttonStyle(.plain)
            }
        }
    }
}
