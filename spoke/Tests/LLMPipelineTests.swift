import Testing
@testable import SpokenAnyWhere

@Suite("LLMPipeline 测试", .serialized)
@MainActor
struct LLMPipelineTests {

    @Test("未启用时 chat 返回 notConfigured")
    func chatReturnsNotConfiguredWhenDisabled() async {
        let settings = LLMSettings.makeTesting()
        let originalEnabled = settings.isEnabled
        defer { settings.isEnabled = originalEnabled }
        settings.isEnabled = false

        let pipeline = LLMPipeline.makeTesting(
            dependencies: LLMPipelineDependencies(
                settings: settings,
                contextService: ContextService.shared,
                clipboardHistory: ClipboardHistoryService.shared,
                screenOCR: ScreenOCRService.shared,
                shouldUseLLMForCorrection: { true },
                dictionaryEntries: { [] }
            )
        )

        let result = await pipeline.chat("hello")

        switch result {
        case .failure(.notConfigured):
            #expect(Bool(true))
        default:
            Issue.record("expected notConfigured")
        }
    }

    @Test("未启用时 refine 直接返回原文")
    func refineFallsBackToOriginalWhenDisabled() async {
        let settings = LLMSettings.makeTesting()
        let originalEnabled = settings.isEnabled
        defer { settings.isEnabled = originalEnabled }
        settings.isEnabled = false

        let pipeline = LLMPipeline.makeTesting(
            dependencies: LLMPipelineDependencies(
                settings: settings,
                contextService: ContextService.shared,
                clipboardHistory: ClipboardHistoryService.shared,
                screenOCR: ScreenOCRService.shared,
                shouldUseLLMForCorrection: { true },
                dictionaryEntries: { [] }
            )
        )

        let result = await pipeline.refine("raw text")

        switch result {
        case .success(let text):
            #expect(text == "raw text")
        default:
            Issue.record("expected raw text fallback")
        }
    }
}
