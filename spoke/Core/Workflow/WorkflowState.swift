import AppKit
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "WorkflowState")

/// Workflow 选择器状态
@Observable
@MainActor
final class WorkflowState {
    
    // MARK: - Singleton
    
    static let shared = WorkflowState()
    
    // MARK: - State
    
    /// 是否显示 Picker
    var isPickerVisible: Bool = false
    
    /// 过滤关键词（/ 后面的部分）
    var filterKeyword: String = ""
    
    /// 当前选中的 Workflow（用于执行）
    var selectedWorkflow: WorkflowAction?
    
    /// 原始输入文本（用于恢复）
    var originalInput: String = ""
    
    /// 当前选中索引（键盘导航用）
    var selectedIndex: Int = 0
    
    /// 键盘确认选择的回调（用于触发执行）
    var onKeyboardConfirm: ((WorkflowAction) -> Void)?
    
    private let configService = WorkflowConfigService.shared
    
    private init() {}
    
    // MARK: - Actions
    
    /// 检测并处理 / 前缀
    /// - Parameter text: 当前输入文本
    /// - Parameter hasMarkedText: 是否有输入法组合状态
    /// - Returns: 是否触发了 Workflow Picker
    func detectSlashPrefix(text: String, hasMarkedText: Bool) -> Bool {
        // 输入法组合状态时不触发
        guard !hasMarkedText else { return false }
        
        if text.hasPrefix("/") {
            if !isPickerVisible {
                originalInput = ""
                isPickerVisible = true
            }
            filterKeyword = String(text.dropFirst())
            return true
        } else {
            if isPickerVisible {
                hidePicker()
            }
            return false
        }
    }
    
    /// 显示 Picker
    func showPicker() {
        isPickerVisible = true
        filterKeyword = ""
    }
    
    /// 隐藏 Picker（保留 / 前缀文本）
    func hidePicker() {
        isPickerVisible = false
        filterKeyword = ""
    }
    
    /// 取消并清除 / 前缀
    func cancel() {
        isPickerVisible = false
        filterKeyword = ""
        selectedWorkflow = nil
    }
    
    /// 选择 Workflow
    func select(_ workflow: WorkflowAction) {
        selectedWorkflow = workflow
        isPickerVisible = false
        filterKeyword = ""
        
        // 标记为最近使用
        WorkflowConfigService.shared.markAsRecent(workflow.id)
    }
    
    /// 获取用户实际输入（去掉 /keyword 部分）
    func getUserInput(from fullText: String) -> String {
        guard let workflow = selectedWorkflow else {
            return fullText
        }
        
        let prefix = "/\(workflow.keyword)"
        if fullText.hasPrefix(prefix) {
            var input = String(fullText.dropFirst(prefix.count))
            // 去掉开头的空格
            input = input.trimmingCharacters(in: .whitespaces)
            return input
        }
        return fullText
    }
    
    /// 重置状态
    func reset() {
        isPickerVisible = false
        filterKeyword = ""
        selectedWorkflow = nil
        originalInput = ""
        selectedIndex = 0
    }
    
    // MARK: - Keyboard Navigation
    
    /// 获取当前过滤后的 Workflow 列表
    private var filteredWorkflows: [WorkflowAction] {
        configService.search(keyword: filterKeyword)
    }
    
    /// 向上移动选择
    func moveUp() {
        let count = filteredWorkflows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
    }
    
    /// 向下移动选择
    func moveDown() {
        let count = filteredWorkflows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
    }
    
    /// 确认选择当前项
    func confirmSelection() -> WorkflowAction? {
        let workflows = filteredWorkflows
        guard selectedIndex < workflows.count else { return nil }
        let workflow = workflows[selectedIndex]
        
        // 先保存回调，因为 select() 会隐藏 Picker，触发 onDisappear 清空回调
        let callback = onKeyboardConfirm
        
        select(workflow)
        
        // 触发键盘确认回调
        logger.info("🔑 confirmSelection: callback=\(callback != nil ? "set" : "nil", privacy: .public)")
        callback?(workflow)
        
        return workflow
    }
    
    /// 处理键盘事件
    /// - Returns: 是否消费了该事件
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        logger.info("🔑 handleKeyEvent: keyCode=\(event.keyCode), isPickerVisible=\(self.isPickerVisible)")
        
        guard isPickerVisible else { return false }
        
        switch event.keyCode {
        case 126: // ↑
            moveUp()
            return true
        case 125: // ↓
            moveDown()
            return true
        case 36, 48: // Enter / Tab
            logger.info("🔑 handleKeyEvent: Enter/Tab pressed")
            if confirmSelection() != nil {
                logger.info("🔑 handleKeyEvent: Selection confirmed")
                return true
            }
            return false
        default:
            return false
        }
    }
}
