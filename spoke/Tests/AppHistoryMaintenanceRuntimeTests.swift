import Testing
@testable import SpokenAnyWhere

@Suite("AppHistoryMaintenanceRuntime 测试")
@MainActor
struct AppHistoryMaintenanceRuntimeTests {
    @Test("自动清理只执行已启用且大于零的策略")
    func autoCleanupRespectsSettings() async {
        var policies: [HistoryManager.CleanupPolicy] = []

        let runtime = AppHistoryMaintenanceRuntime(
            performCleanup: { policies.append($0) },
            migrateLegacyTodayRecords: {},
            cleanupOrphanedAudioFiles: {},
            enforceNormalRecordLimit: { _ in },
            enforceAudioSizeLimit: { _ in }
        )

        await runtime.runAutoCleanup(
            using: AppHistoryMaintenanceSettings(
                autoCleanupEnabled: true,
                keepDays: 30,
                maxCount: 0
            )
        )

        #expect(policies.count == 1)
        if case .keepDays(let days) = policies[0] {
            #expect(days == 30)
        } else {
            Issue.record("expected keepDays policy")
        }
    }

    @Test("orphan maintenance 保持既定执行顺序")
    func orphanMaintenanceOrderIsStable() async {
        var events: [String] = []

        let runtime = AppHistoryMaintenanceRuntime(
            performCleanup: { _ in },
            migrateLegacyTodayRecords: { events.append("migrate") },
            cleanupOrphanedAudioFiles: { events.append("cleanup") },
            enforceNormalRecordLimit: { _ in events.append("limit-count") },
            enforceAudioSizeLimit: { _ in events.append("limit-size") }
        )

        await runtime.runOrphanMaintenance()

        #expect(events == ["migrate", "cleanup", "limit-count", "limit-size"])
    }
}
