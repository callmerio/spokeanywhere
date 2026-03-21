import Foundation

enum AppLifecycleStepID: String, Equatable {
    case installCrashLogger = "install-crash-logger"
    case checkAccessibility = "check-accessibility"
    case setupMenuBar = "setup-menu-bar"
    case startClipboardService = "start-clipboard-service"
    case startRecordingController = "start-recording-controller"
    case configureHistoryManager = "configure-history-manager"
    case performHistoryCleanup = "perform-history-cleanup"
    case performOrphanCleanup = "perform-orphan-cleanup"
    case prepareDictionary = "prepare-dictionary"
    case warmupSpeechEngine = "warmup-speech-engine"
    case setupTrackpadGesture = "setup-trackpad-gesture"
    case setupResourceMonitor = "setup-resource-monitor"
    case setupSelectionToolbar = "setup-selection-toolbar"
    case setupScreenshotService = "setup-screenshot-service"
    case setupDictionaryPanel = "setup-dictionary-panel"
    case setupDebugAutomationTrigger = "setup-debug-automation-trigger"
    case stopRecordingController = "stop-recording-controller"
    case stopTrackpadGesture = "stop-trackpad-gesture"
    case stopSelectionToolbar = "stop-selection-toolbar"
    case stopResourceMonitor = "stop-resource-monitor"
    case removeNotificationObservers = "remove-notification-observers"
    case stopDebugAutomationTrigger = "stop-debug-automation-trigger"
}

struct AppLifecycleStepSpec: Equatable {
    let id: AppLifecycleStepID
    let name: String
}

enum AppLifecyclePlan {
    static func startup(includeDebugAutomation: Bool) -> [AppLifecycleStepSpec] {
        var steps: [AppLifecycleStepSpec] = [
            .init(id: .installCrashLogger, name: "Step 0: Installing crash logger..."),
            .init(id: .checkAccessibility, name: "Step 1: Checking accessibility permission..."),
            .init(id: .setupMenuBar, name: "Step 2: Setting up status bar..."),
            .init(id: .startClipboardService, name: "Step 3: Starting clipboard service..."),
            .init(id: .startRecordingController, name: "Step 4: Starting recording controller..."),
            .init(id: .configureHistoryManager, name: "Step 5: Configuring HistoryManager..."),
            .init(id: .performHistoryCleanup, name: "Step 6: Performing history cleanup..."),
            .init(id: .performOrphanCleanup, name: "Step 6.1: Cleaning orphaned audio files..."),
            .init(id: .prepareDictionary, name: "Step 6.5: Checking dictionary precompilation..."),
            .init(id: .warmupSpeechEngine, name: "Step 6.6: Warming up speech engine (background)..."),
            .init(id: .setupTrackpadGesture, name: "Step 7: Setting up trackpad gesture..."),
            .init(id: .setupResourceMonitor, name: "Step 8: Starting resource monitor..."),
            .init(id: .setupSelectionToolbar, name: "Step 9: Starting selection toolbar..."),
            .init(id: .setupScreenshotService, name: "Step 10: Setting up screenshot service..."),
            .init(id: .setupDictionaryPanel, name: "Step 11: Setting up dictionary panel...")
        ]

        if includeDebugAutomation {
            steps.append(
                .init(
                    id: .setupDebugAutomationTrigger,
                    name: "Step 11.5: Setting up debug automation trigger..."
                )
            )
        }

        return steps
    }

    static func shutdown(includeDebugAutomation: Bool) -> [AppLifecycleStepSpec] {
        var steps: [AppLifecycleStepSpec] = [
            .init(id: .stopRecordingController, name: "stop recording controller"),
            .init(id: .stopTrackpadGesture, name: "stop trackpad gesture"),
            .init(id: .stopSelectionToolbar, name: "stop selection toolbar"),
            .init(id: .stopResourceMonitor, name: "stop resource monitor"),
            .init(id: .removeNotificationObservers, name: "remove notification observers")
        ]

        if includeDebugAutomation {
            steps.append(
                .init(
                    id: .stopDebugAutomationTrigger,
                    name: "stop debug automation trigger"
                )
            )
        }

        return steps
    }
}
