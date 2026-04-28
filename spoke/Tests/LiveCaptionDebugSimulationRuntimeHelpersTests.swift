#if DEBUG
import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("LiveCaptionDebugSimulationRuntimeHelpers 测试")
struct LiveCaptionDebugSimulationRuntimeHelpersTests {

    @Test("long translation mock frames 会覆盖长句落地后下一句开始")
    func longTranslationFramesHaveExpectedShape() {
        let frames = makeLiveCaptionLongTranslationMockFrames()

        #expect(frames.count >= 6)
        #expect(frames.first?.kind == .pending)
        #expect(frames.contains { $0.kind == .finalized && $0.original.contains("hard and new is still something that the models need humans") })

        let finalizedIndex = frames.firstIndex {
            $0.kind == .finalized && $0.original.contains("hard and new is still something that the models need humans")
        }
        #expect(finalizedIndex != nil)

        if let finalizedIndex {
            #expect(frames.indices.contains(finalizedIndex + 1))
            #expect(frames[finalizedIndex + 1].kind == .pending)
            #expect(frames[finalizedIndex + 1].original.contains("And this is where I want to spend my time"))
        }

        #expect(frames.last?.kind == .finalized)
        #expect(frames.last?.original.contains("Let's introduce symphony") == true)
    }

    @Test("mock scenario 可从环境变量解析")
    func scenarioParsesFromEnvironment() {
        let scenario = liveCaptionMockScenarioFromEnvironment([
            liveCaptionMockScenarioEnvKey: "long_translation"
        ])

        #expect(scenario == "long_translation")
    }

    @Test("mock scenario 可从 bootstrap 文件解析")
    func scenarioParsesFromBootstrapFile() throws {
        try "long_translation".write(
            toFile: liveCaptionMockScenarioBootstrapFilePath,
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(atPath: liveCaptionMockScenarioBootstrapFilePath)
        }

        #expect(liveCaptionMockScenarioFromEnvironment([:]) == "long_translation")
        #expect(liveCaptionHasMockScenario([:]))
    }

    @Test("mock scenario 缺失时不会启用 mock 模式")
    func missingScenarioDoesNotEnableMockMode() {
        #expect(!liveCaptionHasMockScenario([:]))
    }

    @Test("mock scenario 存在时会启用 mock 模式")
    func presentScenarioEnablesMockMode() {
        #expect(liveCaptionHasMockScenario([
            liveCaptionMockScenarioEnvKey: "long_translation"
        ]))
    }
}
#endif
