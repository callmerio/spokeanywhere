import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "WorkflowConfigService")

/// Workflow 配置服务
/// 管理 Workflow 的 CRUD、持久化、搜索
@Observable
@MainActor
final class WorkflowConfigService {
    
    // MARK: - Singleton
    
    static let shared = WorkflowConfigService()
    
    // MARK: - Storage
    
    private let storageKey = "workflow.config.v1"
    private let defaults = UserDefaults.standard
    
    // MARK: - State
    
    /// 所有 Workflow（内置 + 自定义）
    private(set) var workflows: [WorkflowAction] = []
    
    /// 最近使用的 Workflow IDs
    private(set) var recentIds: [String] = []
    
    /// 保存防抖
    private var saveTask: Task<Void, Never>?
    
    // MARK: - Init
    
    private init() {
        load()
    }
    
    // MARK: - Query
    
    /// 获取所有启用的 Workflow
    var enabledWorkflows: [WorkflowAction] {
        workflows.filter { $0.isEnabled }
    }
    
    /// 获取内置 Workflow
    var builtinWorkflows: [WorkflowAction] {
        workflows.filter { $0.isBuiltin }
    }
    
    /// 获取自定义 Workflow
    var customWorkflows: [WorkflowAction] {
        workflows.filter { !$0.isBuiltin }
    }
    
    /// 根据关键词搜索 Workflow
    func search(keyword: String) -> [WorkflowAction] {
        let query = keyword.lowercased().trimmingCharacters(in: .whitespaces)
        if query.isEmpty {
            return enabledWorkflows
        }
        return enabledWorkflows.filter { workflow in
            workflow.keyword.lowercased().contains(query) ||
            workflow.name.lowercased().contains(query)
        }
    }
    
    /// 根据 ID 获取 Workflow
    func workflow(byId id: String) -> WorkflowAction? {
        workflows.first { $0.id == id }
    }
    
    /// 根据关键词精确匹配
    func workflow(byKeyword keyword: String) -> WorkflowAction? {
        enabledWorkflows.first { $0.keyword.lowercased() == keyword.lowercased() }
    }
    
    /// 获取最近使用的 Workflow（最多 3 个）
    var recentWorkflows: [WorkflowAction] {
        recentIds.compactMap { id in
            workflows.first { $0.id == id && $0.isEnabled }
        }.prefix(3).map { $0 }
    }
    
    /// 分组后的 Workflow（最近 → 内置 → 自定义）
    func groupedWorkflows(filter: String = "") -> [(title: String, workflows: [WorkflowAction])] {
        let filtered = search(keyword: filter)
        var groups: [(title: String, workflows: [WorkflowAction])] = []
        
        // 最近使用
        let recent = recentWorkflows.filter { workflow in
            filter.isEmpty || filtered.contains { $0.id == workflow.id }
        }
        if !recent.isEmpty {
            groups.append(("最近使用", recent))
        }
        
        // 内置（排除已在最近使用中的）
        let builtin = filtered.filter { workflow in
            workflow.isBuiltin && !recent.contains { $0.id == workflow.id }
        }
        if !builtin.isEmpty {
            groups.append(("内置", builtin))
        }
        
        // 自定义
        let custom = filtered.filter { !$0.isBuiltin }
        if !custom.isEmpty {
            groups.append(("自定义", custom))
        }
        
        return groups
    }
    
    // MARK: - CRUD
    
    /// 添加自定义 Workflow
    func add(_ workflow: WorkflowAction) {
        guard !workflow.isBuiltin else {
            logger.warning("⚙️ [WorkflowConfig] 不能添加内置 Workflow")
            return
        }
        workflows.append(workflow)
        scheduleSave()
        logger.info("⚙️ [WorkflowConfig] 添加 Workflow: \(workflow.name)")
    }
    
    /// 更新 Workflow
    func update(_ workflow: WorkflowAction) {
        guard let index = workflows.firstIndex(where: { $0.id == workflow.id }) else {
            logger.warning("⚙️ [WorkflowConfig] Workflow 不存在: \(workflow.id)")
            return
        }
        workflows[index] = workflow
        scheduleSave()
        logger.info("⚙️ [WorkflowConfig] 更新 Workflow: \(workflow.name)")
    }
    
    /// 删除 Workflow
    func delete(_ id: String) {
        guard let index = workflows.firstIndex(where: { $0.id == id }) else { return }
        let workflow = workflows[index]
        if workflow.isBuiltin {
            logger.warning("⚙️ [WorkflowConfig] 不能删除内置 Workflow")
            return
        }
        workflows.remove(at: index)
        recentIds.removeAll { $0 == id }
        scheduleSave()
        logger.info("⚙️ [WorkflowConfig] 删除 Workflow: \(workflow.name)")
    }
    
    /// 切换启用状态
    func toggleEnabled(_ id: String) {
        guard let index = workflows.firstIndex(where: { $0.id == id }) else { return }
        workflows[index].isEnabled.toggle()
        scheduleSave()
    }
    
    /// 标记为最近使用
    func markAsRecent(_ id: String) {
        recentIds.removeAll { $0 == id }
        recentIds.insert(id, at: 0)
        if recentIds.count > 5 {
            recentIds = Array(recentIds.prefix(5))
        }
        scheduleSave()
    }
    
    // MARK: - Persistence
    
    private func load() {
        // 加载自定义 Workflow
        var customWorkflows: [WorkflowAction] = []
        if let data = defaults.data(forKey: storageKey) {
            do {
                let stored = try JSONDecoder().decode(StoredConfig.self, from: data)
                customWorkflows = stored.customWorkflows
                recentIds = stored.recentIds
                logger.info("⚙️ [WorkflowConfig] 加载成功 | 自定义: \(customWorkflows.count)")
            } catch {
                logger.error("⚙️ [WorkflowConfig] 解码失败: \(error.localizedDescription)")
            }
        }
        
        // 合并内置 + 自定义
        workflows = WorkflowDefaults.builtins + customWorkflows
    }
    
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            save()
        }
    }
    
    private func save() {
        let config = StoredConfig(
            customWorkflows: customWorkflows,
            recentIds: recentIds
        )
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: storageKey)
            logger.info("⚙️ [WorkflowConfig] 保存成功")
        } catch {
            logger.error("⚙️ [WorkflowConfig] 保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 重置为默认
    func resetToDefaults() {
        workflows = WorkflowDefaults.builtins
        recentIds = []
        defaults.removeObject(forKey: storageKey)
        logger.info("⚙️ [WorkflowConfig] 已重置为默认")
    }
}

// MARK: - Storage Model

private struct StoredConfig: Codable {
    let customWorkflows: [WorkflowAction]
    let recentIds: [String]
}
