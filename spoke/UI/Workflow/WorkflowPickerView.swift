import SwiftUI

private typealias DS = DesignTokens

/// Workflow 选择器视图
/// 显示在 Quick Ask 输入框上方，支持键盘导航
struct WorkflowPickerView: View {
    
    /// 过滤关键词（用户输入的 /xxx 部分）
    let filter: String
    /// 选择回调
    let onSelect: (WorkflowAction) -> Void
    
    private let configService = WorkflowConfigService.shared
    private var workflowState: WorkflowState { WorkflowState.shared }
    
    private var filteredWorkflows: [WorkflowAction] {
        configService.search(keyword: filter)
    }
    
    private var groupedWorkflows: [(title: String, workflows: [WorkflowAction])] {
        configService.groupedWorkflows(filter: filter)
    }
    
    private var flatWorkflows: [WorkflowAction] {
        groupedWorkflows.flatMap { $0.workflows }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if flatWorkflows.isEmpty {
                emptyState
            } else {
                workflowList
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .onChange(of: filter) { _, _ in
            workflowState.selectedIndex = 0
        }
    }
    
    // MARK: - Workflow List
    
    private var workflowList: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(flatWorkflows.enumerated()), id: \.element.id) { index, workflow in
                        WorkflowOptionRow(
                            workflow: workflow,
                            isSelected: index == workflowState.selectedIndex,
                            filter: filter
                        )
                        .id(workflow.id)
                        .onTapGesture {
                            onSelect(workflow)
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 260)
            .onChange(of: workflowState.selectedIndex) { _, newIndex in
                if let workflow = flatWorkflows[safe: newIndex] {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(workflow.id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("没有匹配的 Workflow")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("输入 / 查看所有可用项")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Workflow Option Row

struct WorkflowOptionRow: View {
    let workflow: WorkflowAction
    let isSelected: Bool
    let filter: String
    
    var body: some View {
        HStack(spacing: 8) {
            // 名称
            Text(workflow.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            
            // 描述（一行，超出截断）
            Text(workflow.description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? DS.Colors.accentPrimary.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }
}

// MARK: - Array Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
