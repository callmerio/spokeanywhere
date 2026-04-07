import Foundation

enum AppIdentity {
    static let displayName = "SpokenAnyWhere"
    static let bundleIdentifier = "com.spokeanywhere"
    static let logSubsystem = "com.spokeanywhere"

    private static let legacyBundleIdentifiers = ["app.spokenly"]
    private static let userDefaultsMigrationKey = "AppIdentityMigratedToComSpokeAnywhere"

    static func migrateLegacyUserDefaultsIfNeeded(_ defaults: UserDefaults = .standard) {
        guard Bundle.main.bundleIdentifier == bundleIdentifier else {
            return
        }

        if defaults.bool(forKey: userDefaultsMigrationKey) {
            return
        }

        var targetDomain = defaults.persistentDomain(forName: bundleIdentifier) ?? [:]
        var didMigrate = false

        for legacyBundleIdentifier in legacyBundleIdentifiers {
            guard let legacyDomain = defaults.persistentDomain(forName: legacyBundleIdentifier),
                  !legacyDomain.isEmpty else {
                continue
            }

            for (key, value) in legacyDomain where targetDomain[key] == nil {
                targetDomain[key] = value
                didMigrate = true
            }
        }

        if didMigrate {
            defaults.setPersistentDomain(targetDomain, forName: bundleIdentifier)
        }

        defaults.set(true, forKey: userDefaultsMigrationKey)
    }
}
