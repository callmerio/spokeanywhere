import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("AppStatusMenu observer/title runtime 测试")
@MainActor
struct AppStatusMenuObserverRuntimeTests {
    @Test("标题 runtime 会同时更新录音和 Quick Ask 菜单标题")
    func titleRuntimeUpdatesBothTitles() {
        let runtime = AppStatusMenuTitleRuntime()
        var recordingTitle = ""
        var quickAskTitle = ""

        runtime.updateTitles(
            setRecordingTitle: { recordingTitle = $0 },
            setQuickAskTitle: { quickAskTitle = $0 }
        )

        #expect(recordingTitle == "录音")
        #expect(quickAskTitle == "Quick Ask")
    }

    @Test("observer runtime 会注册两个通知并在触发时刷新")
    func observerRuntimeRegistersAndRefreshes() {
        let runtime = AppStatusMenuShortcutObserverRuntime()
        var refreshCount = 0

        let observations = runtime.makeObservations {
            refreshCount += 1
        }

        #expect(observations.map(\.name) == [
            AppSettings.shortcutDidChangeNotification,
            AppSettings.quickAskShortcutDidChangeNotification
        ])

        for observation in observations {
            observation.handler(Notification(name: observation.name))
        }

        #expect(refreshCount == 2)
    }
}
