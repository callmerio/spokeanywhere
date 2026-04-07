import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("KeychainService 迁移测试", .serialized)
struct KeychainServiceMigrationTests {

    @Test("load 会将遗留 UserDefaults 凭据迁移到 Keychain")
    func migratesLegacyValueOnLoad() throws {
        let key = "keychain.migration.\(UUID().uuidString)"
        let legacyStorageKey = "debug.apikey." + key
        let value = "secret-\(UUID().uuidString)"
        let originalMode = KeychainService.useSimpleStorage

        defer {
            KeychainService.useSimpleStorage = originalMode
            KeychainService.clearCache()
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            try? KeychainService.delete(key: key)
        }

        KeychainService.useSimpleStorage = false
        KeychainService.clearCache()
        try? KeychainService.delete(key: key)
        UserDefaults.standard.set(value, forKey: legacyStorageKey)

        let loaded = KeychainService.load(key: key)

        #expect(loaded == value)
        #expect(UserDefaults.standard.string(forKey: legacyStorageKey) == nil)
        #expect(KeychainService.exists(key: key))
    }

    @Test("delete 会同时清理 Keychain 与遗留 UserDefaults")
    func deleteCleansKeychainAndLegacyStorage() throws {
        let key = "keychain.delete.\(UUID().uuidString)"
        let legacyStorageKey = "debug.apikey." + key
        let value = "secret-\(UUID().uuidString)"
        let originalMode = KeychainService.useSimpleStorage

        defer {
            KeychainService.useSimpleStorage = originalMode
            KeychainService.clearCache()
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
            try? KeychainService.delete(key: key)
        }

        KeychainService.useSimpleStorage = false
        KeychainService.clearCache()
        UserDefaults.standard.set(value, forKey: legacyStorageKey)
        try KeychainService.save(key: key, value: value)

        try KeychainService.delete(key: key)

        #expect(UserDefaults.standard.string(forKey: legacyStorageKey) == nil)
        #expect(KeychainService.load(key: key) == nil)
        #expect(!KeychainService.exists(key: key))
    }
}
