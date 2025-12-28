import SwiftUI

extension AnswerPanelView {
    // MARK: - Workflow Picker Overlay
    
    /// 悬浮的 Workflow Picker（覆盖在对话上方，不挡住输入框）
    var workflowPickerOverlay: some View {
        WorkflowPickerView(
            filter: workflowState.filterKeyword,
            onSelect: { workflow in
                selectWorkflowForInput(workflow)
            }
        )
        .frame(maxWidth: .infinity, maxHeight: 200)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            ZStack {
                VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
                Color.black.opacity(0.3)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 16, y: -4)
        .padding(.horizontal, 16)
        .padding(.bottom, 140)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeOut(duration: 0.2), value: workflowState.isPickerVisible)
    }
    
    /// 选择 Workflow 后显示标签在输入框中
    func selectWorkflowForInput(_ workflow: WorkflowAction) {
        workflowState.select(workflow)
        followUpInput = ""
    }
}
