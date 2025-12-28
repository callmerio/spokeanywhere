import Foundation
import os
import Security

/// Keychain 服务
/// 用于安全存储 API Key
/// 使用内存缓存减少 Keychain 访问次数（避免开发阶段频繁授权弹窗）
final class KeychainService {
    
    private static let logger = Logger(subsystem: "com.spokeanywhere", category: "Keychain")
    
    /// 服务名称前缀
    private static let servicePrefix = "com.spokeanywhere.llm"
    
    /// 内存缓存（减少 Keychain 访问）
    private static var cache: [String: String] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.spokeanywhere.keychain.cache")
    
    // MARK: - Debug Mode
    
    /// ⚠️ 测试模式：使用 UserDefaults 代替 Keychain（避免每次启动输入密码）
    /// 正式发布时请设为 false
    static var useSimpleStorage: Bool = true
    
    /// UserDefaults 存储前缀（测试模式用）
    private static let simpleStoragePrefix = "debug.apikey."
    
    // MARK: - Public API
    
    /// 保存 API Key (智能更新)
    static func save(key: String, value: String) throws {
        // 测试模式：使用 UserDefaults
        if useSimpleStorage {
            UserDefaults.standard.set(value, forKey: simpleStoragePrefix + key)
            cacheQueue.sync { cache[key] = value }
            logger.info("✅ [Debug] Saved to UserDefaults: \(key)")
            return
        }
        
        // 正式模式：使用 Keychain
        let service = "\(servicePrefix).\(key)"
        
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        
        // 1. 尝试更新现有项目
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        // 2. 如果项目不存在 (errSecItemNotFound)，则添加新项目
        if status == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        
        guard status == errSecSuccess else {
            logger.error("❌ Keychain save failed: \(status)")
            throw KeychainError.saveFailed(status)
        }
        
        // 更新缓存
        cacheQueue.sync { cache[key] = value }
        
        logger.info("✅ Saved to Keychain: \(key)")
    }
    
    /// 加载 API Key（优先从缓存读取）
    static func load(key: String) -> String? {
        // 先查缓存
        if let cached = cacheQueue.sync(execute: { cache[key] }) {
            return cached
        }
        
        // 测试模式：从 UserDefaults 读取
        if useSimpleStorage {
            if let value = UserDefaults.standard.string(forKey: simpleStoragePrefix + key) {
                cacheQueue.sync { cache[key] = value }
                return value
            }
            return nil
        }
        
        // 正式模式：从 Keychain 读取
        let service = "\(servicePrefix).\(key)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // 写入缓存
        cacheQueue.sync { cache[key] = value }
        
        return value
    }
    
    /// 删除 API Key
    static func delete(key: String) throws {
        // 测试模式：从 UserDefaults 删除
        if useSimpleStorage {
            UserDefaults.standard.removeObject(forKey: simpleStoragePrefix + key)
            _ = cacheQueue.sync { cache.removeValue(forKey: key) }
            logger.info("🗑️ [Debug] Deleted from UserDefaults: \(key)")
            return
        }
        
        // 正式模式：从 Keychain 删除
        let service = "\(servicePrefix).\(key)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("❌ Keychain delete failed: \(status)")
            throw KeychainError.deleteFailed(status)
        }
        
        // 清除缓存
        _ = cacheQueue.sync { cache.removeValue(forKey: key) }
        
        logger.info("🗑️ Deleted from Keychain: \(key)")
    }
    
    /// 检查是否存在（优先查缓存）
    static func exists(key: String) -> Bool {
        // 先查缓存
        if cacheQueue.sync(execute: { cache[key] }) != nil {
            return true
        }
        return load(key: key) != nil
    }
    
    /// 清除内存缓存（调试用）
    static func clearCache() {
        cacheQueue.sync { cache.removeAll() }
    }
}

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case encodingFailed
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "数据编码失败"
        case .saveFailed(let status):
            return "Keychain 保存失败: \(status)"
        case .deleteFailed(let status):
            return "Keychain 删除失败: \(status)"
        }
    }
}
