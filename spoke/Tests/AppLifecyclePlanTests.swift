import Testing
@testable import SpokenAnyWhere

@Suite("AppLifecyclePlan 测试")
struct AppLifecyclePlanTests {
    @Test("startup plan 保持现有步骤顺序")
    func startupStepOrderIsStable() {
        let plan = AppLifecyclePlan.startup(includeDebugAutomation: false)

        #expect(plan.map(\.id) == [
            .installCrashLogger,
            .checkAccessibility,
            .setupMenuBar,
            .startClipboardService,
            .startRecordingController,
            .configureHistoryManager,
            .performHistoryCleanup,
            .performOrphanCleanup,
            .prepareDictionary,
            .warmupSpeechEngine,
            .setupTrackpadGesture,
            .setupResourceMonitor,
            .setupSelectionToolbar,
            .setupScreenshotService,
            .setupPinnedTextService,
            .setupDictionaryPanel
        ])
    }

    @Test("debug startup step 仅在显式开启时追加")
    func debugStepAppearsOnlyWhenEnabled() {
        let baseline = AppLifecyclePlan.startup(includeDebugAutomation: false)
        let debugPlan = AppLifecyclePlan.startup(includeDebugAutomation: true)

        #expect(!baseline.map(\.id).contains(.setupDebugAutomationTrigger))
        #expect(debugPlan.map(\.id).last == .setupDebugAutomationTrigger)
    }

    @Test("mock scenario startup plan 走最小启动路径并优先 debug automation")
    func mockScenarioUsesMinimalStartupPlan() {
        let plan = AppLifecyclePlan.startup(
            includeDebugAutomation: true,
            mockScenarioActive: true
        )

        #expect(plan.map(\.id) == [
            .installCrashLogger,
            .setupDebugAutomationTrigger,
            .setupMenuBar
        ])
    }

    @Test("mock scenario 即使不开启 debug automation 也跳过权限密集步骤")
    func mockScenarioWithoutDebugStillSkipsHeavyStartupSteps() {
        let plan = AppLifecyclePlan.startup(
            includeDebugAutomation: false,
            mockScenarioActive: true
        )

        #expect(plan.map(\.id) == [
            .installCrashLogger,
            .setupMenuBar
        ])
    }

    @Test("shutdown plan 保持现有步骤顺序")
    func shutdownStepOrderIsStable() {
        let plan = AppLifecyclePlan.shutdown(includeDebugAutomation: false)

        #expect(plan.map(\.id) == [
            .stopRecordingController,
            .stopQuickAskService,
            .stopMessagePanelManager,
            .stopLiveCaptionManager,
            .stopScreenshotManager,
            .stopPinnedTextManager,
            .stopTrackpadGesture,
            .stopSelectionToolbar,
            .stopResourceMonitor,
            .removeNotificationObservers
        ])
    }

    @Test("debug shutdown step 仅在显式开启时追加")
    func debugShutdownStepAppearsOnlyWhenEnabled() {
        let baseline = AppLifecyclePlan.shutdown(includeDebugAutomation: false)
        let debugPlan = AppLifecyclePlan.shutdown(includeDebugAutomation: true)

        #expect(!baseline.map(\.id).contains(.stopDebugAutomationTrigger))
        #expect(debugPlan.map(\.id).last == .stopDebugAutomationTrigger)
    }
}
