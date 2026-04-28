import Testing
@testable import SpokenAnyWhere

@Suite("AppRuntimeHelpers 测试")
struct AppRuntimeHelpersTests {
    @Test("无 mock scenario 时不跳过语音准备")
    @MainActor
    func noMockScenarioDoesNotSkipSpeechPreparation() {
        AppDebugLaunchContext.liveCaptionMockScenarioActive = false
        #expect(!appShouldSkipSpeechPreparationForMockScenario(environment: [:]))
        #expect(!appShouldSkipSpeechPreparationForMockScenario(environment: [
            "SPOKE_DEBUG_LIVECAPTION_SCENARIO": "   "
        ]))
    }

    @Test("有 mock scenario 时跳过语音准备")
    @MainActor
    func mockScenarioSkipsSpeechPreparation() {
        AppDebugLaunchContext.liveCaptionMockScenarioActive = false
        #expect(appShouldSkipSpeechPreparationForMockScenario(environment: [
            "SPOKE_DEBUG_LIVECAPTION_SCENARIO": "long_translation"
        ]))
    }

    @Test("有 mock scenario 时不应急切解析 Quick Ask 启动链")
    @MainActor
    func mockScenarioSkipsEagerQuickAskResolution() {
        AppDebugLaunchContext.liveCaptionMockScenarioActive = false
        #expect(!appShouldEagerResolveQuickAskService(environment: [
            "SPOKE_DEBUG_LIVECAPTION_SCENARIO": "long_translation"
        ]))
        #expect(appShouldEagerResolveQuickAskService(environment: [:]))
    }
}
