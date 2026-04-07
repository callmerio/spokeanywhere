import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionManager 测试", .serialized)
@MainActor
struct LiveCaptionManagerTests {

    @Test("setLocale 在未激活状态下应直接更新 captionLocale")
    func setLocaleUpdatesInactiveManager() async {
        let manager = LiveCaptionManager.makeTesting()
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
}
