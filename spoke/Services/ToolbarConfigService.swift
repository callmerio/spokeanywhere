import Combine
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "ToolbarConfigService")

/// 工具栏配置服务 - 管理动作列表和持久化
@MainActor
final class ToolbarConfigService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ToolbarConfigService()
    
    // MARK: - Published Properties
    
    /// 动作列表 (有序)
    @Published private(set) var actions: [ToolbarAction] = []
    
    /// 主栏显示数量 (前N个启用的动作)
    @Published var visibleCount: Int = 5 {
        didSet {
            let clamped = max(1, min(visibleCount, 10))
            if visibleCount != clamped {
                visibleCount = clamped
                return  // 避免重复 scheduleSave
            }
            if oldValue != visibleCount {
                scheduleSave()
            }
        }
    }
    
    /// 全局开关
    @Published var isEnabled: Bool = true {
        didSet { scheduleSave() }
    }
    
    // MARK: - Computed Properties
    
    /// 启用的动作
    var enabledActions: [ToolbarAction] {
        actions.filter(\.isEnabled)
    }
    
    /// 主栏显示的动作 (前N个启用的)
    var visibleActions: [ToolbarAction] {
        Array(enabledActions.prefix(visibleCount))
    }
    
    /// 下拉菜单中的动作 (启用但不在主栏的)
    var menuActions: [ToolbarAction] {
        Array(enabledActions.dropFirst(visibleCount))
    }
    
    /// 是否有下拉菜单内容
    var hasMenuActions: Bool {
        !menuActions.isEmpty
    }
    
    // MARK: - Private Properties
    
    private let storageKey = "toolbar.config.v1"
    private let backupKey = "toolbar.config.v1.backup"
    private var saveTask: ToolbarConfigAsyncTask?
    
    // MARK: - Init
    
    private init() {
        load()
    }
    
    // MARK: - Persistence
    
    /// 加载配置
    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            logger.info("📋 [ToolbarConfig] 首次使用，加载默认配置")
            actions = ToolbarAction.defaults
            return
        }
        
        do {
            let config = try JSONDecoder().decode(StoredConfig.self, from: data)
            actions = config.actions
            visibleCount = max(1, min(config.visibleCount, 10))
            isEnabled = config.isEnabled
            
            // 自动添加缺失的内置动作（新版本可能添加了新内置动作）
            addMissingBuiltinActions()
            
            logger.info("📋 [ToolbarConfig] 加载成功: \(self.actions.count) 个动作")
        } catch {
            logger.error("📋 [ToolbarConfig] 解码失败，备份原数据: \(error.localizedDescription)")
            UserDefaults.standard.set(data, forKey: backupKey)
            actions = ToolbarAction.defaults
        }
    }
    
    /// 添加缺失的内置动作（版本升级时自动添加新内置动作）
    private func addMissingBuiltinActions() {
        let existingBuiltinIds = Set(actions.compactMap { action -> String? in
            guard action.isBuiltin else { return nil }
            return action.id
        })
        
        var needsSave = false
        for defaultAction in ToolbarAction.defaults where !existingBuiltinIds.contains(defaultAction.id) {
            // 在朗读后面插入新动作（如果朗读存在），否则插入到开头
            if let speakIndex = actions.firstIndex(where: { $0.id == "builtin.speak" }) {
                actions.insert(defaultAction, at: speakIndex + 1)
            } else {
                actions.insert(defaultAction, at: 0)
            }
            logger.info("📋 [ToolbarConfig] 自动添加新内置动作: \(defaultAction.name)")
            needsSave = true
        }
        
        if needsSave {
            saveImmediately()
        }
    }
    
    /// 保存配置 (带防抖)
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = makeToolbarConfigSaveTask(owner: self) { service in
            service.saveImmediately()
        }
    }
    
    /// 立即保存
    private func saveImmediately() {
        let config = StoredConfig(actions: actions, visibleCount: visibleCount, isEnabled: isEnabled)
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: storageKey)
            logger.debug("📋 [ToolbarConfig] 保存成功")
        } catch {
            logger.error("📋 [ToolbarConfig] 保存失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CRUD Operations
    
    /// 添加自定义动作
    func addCustomAction(name: String, icon: String, iconColorHex: String, prompt: String) {
        let action = ToolbarAction.custom(name: name, icon: icon, iconColorHex: iconColorHex, prompt: prompt)
        actions.append(action)
        scheduleSave()
        logger.info("📋 [ToolbarConfig] 添加自定义动作: \(name)")
    }
    
    /// 删除动作 (内置动作只禁用)
    func removeAction(id: String) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        
        if actions[index].isBuiltin {
            actions[index] = actions[index].with(isEnabled: false)
            logger.info("📋 [ToolbarConfig] 禁用内置动作: \(id)")
        } else {
            actions.remove(at: index)
            logger.info("📋 [ToolbarConfig] 删除自定义动作: \(id)")
        }
        scheduleSave()
    }
    
    /// 切换动作启用状态
    func toggleAction(id: String) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        actions[index] = actions[index].toggled()
        scheduleSave()
    }
    
    /// 更新动作
    func updateAction(_ action: ToolbarAction) {
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else { return }
        actions[index] = action
        scheduleSave()
    }
    
    /// 使用闭包更新动作
    func updateAction(id: String, _ update: (inout ToolbarAction) -> Void) {
        guard let index = actions.firstIndex(where: { $0.id == id }) else { return }
        var action = actions[index]
        update(&action)
        actions[index] = action
        scheduleSave()
    }
    
    /// 移动动作位置
    func moveAction(from: IndexSet, to: Int) {
        actions.move(fromOffsets: from, toOffset: to)
        scheduleSave()
    }
    
    /// 恢复默认配置
    func resetToDefaults() {
        actions = ToolbarAction.defaults
        visibleCount = 5
        isEnabled = true
        saveImmediately()
        logger.info("📋 [ToolbarConfig] 已恢复默认配置")
    }
    
    // MARK: - Query
    
    /// 根据 ID 获取动作
    func action(byId id: String) -> ToolbarAction? {
        actions.first { $0.id == id }
    }
}

// MARK: - Storage Model

private struct StoredConfig: Codable {
    let actions: [ToolbarAction]
    let visibleCount: Int
    let isEnabled: Bool
}
