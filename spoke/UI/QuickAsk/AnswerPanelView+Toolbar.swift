import SwiftUI

extension AnswerPanelView {
    // MARK: - Toolbar
    
    var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: { onClose?() }, label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(isHoveringCloseButton ? 0.9 : 0.6))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(isHoveringCloseButton ? 0.15 : 0.1))
                    .clipShape(RoundedRectangle(cornerRadius: isHoveringCloseButton ? 6 : 11))
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
                .foregroundStyle(.white.opacity(isHoveringNewChatButton ? 1.0 : 0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(isHoveringNewChatButton ? 0.15 : 0))
                .clipShape(RoundedRectangle(cornerRadius: isHoveringNewChatButton ? 6 : 12))
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
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Error
    
    func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                })
                .buttonStyle(.plain)
            }
        }
    }
}
