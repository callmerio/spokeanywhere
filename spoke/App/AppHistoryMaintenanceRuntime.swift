import Foundation

@MainActor
struct AppHistoryMaintenanceSettings {
    let autoCleanupEnabled: Bool
    let keepDays: Int
    let maxCount: Int
}

@MainActor
struct AppHistoryMaintenanceRuntime {
    let performCleanup: (HistoryManager.CleanupPolicy) async -> Void
    let migrateLegacyTodayRecords: () async -> Void
    let cleanupOrphanedAudioFiles: () async -> Void
    let enforceNormalRecordLimit: (Int) async -> Void
    let enforceAudioSizeLimit: (Int) async -> Void

    func runAutoCleanup(using settings: AppHistoryMaintenanceSettings) async {
        guard settings.autoCleanupEnabled else { return }

        if settings.keepDays > 0 {
            await performCleanup(.keepDays(settings.keepDays))
        }

        if settings.maxCount > 0 {
            await performCleanup(.keepCount(settings.maxCount))
        }
    }

    func runOrphanMaintenance(
        normalRecordLimit: Int = 50,
        audioSizeLimitMB: Int = 2048
    ) async {
        await migrateLegacyTodayRecords()
        await cleanupOrphanedAudioFiles()
        await enforceNormalRecordLimit(normalRecordLimit)
        await enforceAudioSizeLimit(audioSizeLimitMB)
    }
}
