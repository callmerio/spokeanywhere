import Testing
@testable import SpokenAnyWhere

@MainActor
private extension LiveCaptionManagerDependencies {
    static let testing = LiveCaptionManagerDependencies(
        translator: .makePreview(),
        makeAppCaptureService: { .shared },
        makeSystemCaptureService: { .shared },
        transcriptionModelManager: .shared,
        dictionaryService: .shared,
        postTranslationUpdate: {}
    )
}

@Suite("LiveCaptionManager 测试", .serialized)
@MainActor
struct LiveCaptionManagerTests {

    @Test("setLocale 在未激活状态下应直接更新 captionLocale")
    func setLocaleUpdatesInactiveManager() async {
        let manager = LiveCaptionManager.makeTesting(dependencies: .testing)
        let originalLocale = manager.captionLocale
        defer { manager.captionLocale = originalLocale }

        await manager.setLocale("ja-JP")

        #expect(manager.captionLocale == "ja-JP")
        #expect(manager.sourceLanguage == "ja-JP")
    }

    @Test("supportedLanguages 至少包含 4 个选项")
    func supportedLanguagesArePresent() {
        #expect(LiveCaptionManager.supportedLanguages.count >= 4)
        #expect(LiveCaptionManager.supportedLanguages.contains { $0.id == "en-US" })
    }

    @Test("inactive manager 初始化阶段不会提前解析 capture services")
    func managerInitDoesNotResolveCaptureServices() async {
        var appCaptureResolveCount = 0
        var systemCaptureResolveCount = 0

        let manager = LiveCaptionManager.makeTesting(
            dependencies: .init(
                translator: .makePreview(),
                makeAppCaptureService: {
                    appCaptureResolveCount += 1
                    return .shared
                },
                makeSystemCaptureService: {
                    systemCaptureResolveCount += 1
                    return .shared
                },
                transcriptionModelManager: .shared,
                dictionaryService: .shared,
                postTranslationUpdate: {}
            )
        )

        _ = manager.sourceLanguage

        #expect(appCaptureResolveCount == 0)
        #expect(systemCaptureResolveCount == 0)
    }

    @Test("repeated app capture reads 复用同一懒加载实例")
    func repeatedAppCaptureReadsReuseCachedService() {
        var appCaptureResolveCount = 0

        let manager = LiveCaptionManager.makeTesting(
            dependencies: .init(
                translator: .makePreview(),
                makeAppCaptureService: {
                    appCaptureResolveCount += 1
                    return .shared
                },
                makeSystemCaptureService: { .shared },
                transcriptionModelManager: .shared,
                dictionaryService: .shared,
                postTranslationUpdate: {}
            )
        )

        _ = manager.isRetrying
        _ = manager.isRetrying

        #expect(appCaptureResolveCount == 1)
    }
}
