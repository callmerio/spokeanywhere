import Testing
@testable import SpokenAnyWhere

@Suite("WorkflowProfileResolver 测试")
struct WorkflowProfileResolverTests {

    @Test("显式 profileId 优先于 model hint 和 selected profile")
    func explicitProfileWins() {
        let explicit = ProviderProfile(name: "Explicit", providerType: .openai)
        let fallback = ProviderProfile(name: "Fallback", providerType: .anthropic)
        let resolver = WorkflowProfileResolver(
            availableProfiles: [explicit, fallback],
            chatProfileId: fallback.id,
            summaryProfileId: fallback.id,
            selectedProfileId: fallback.id
        )
        let workflow = WorkflowAction(
            id: "custom.explicit",
            name: "显式",
            keyword: "explicit",
            description: "test",
            icon: "sparkles",
            iconColorHex: "#007AFF",
            promptTemplate: "hi",
            isBuiltin: false,
            profileId: explicit.id,
            modelHint: .advanced
        )

        let resolved = resolver.resolve(for: workflow)

        #expect(resolved?.id == explicit.id)
    }

    @Test("fast 和 advanced 分别走 chat/summary profile")
    func modelHintUsesPreferredProfiles() {
        let fast = ProviderProfile(name: "Fast", providerType: .openai)
        let advanced = ProviderProfile(name: "Advanced", providerType: .anthropic)
        let selected = ProviderProfile(name: "Selected", providerType: .googleGemini)
        let resolver = WorkflowProfileResolver(
            availableProfiles: [fast, advanced, selected],
            chatProfileId: fast.id,
            summaryProfileId: advanced.id,
            selectedProfileId: selected.id
        )

        let fastWorkflow = WorkflowAction.builtin(
            keyword: "fast",
            name: "fast",
            description: "fast",
            icon: "bolt",
            iconColorHex: "#34C759",
            promptTemplate: "fast",
            modelHint: .fast
        )
        let advancedWorkflow = WorkflowAction.builtin(
            keyword: "advanced",
            name: "advanced",
            description: "advanced",
            icon: "brain.head.profile",
            iconColorHex: "#FF9500",
            promptTemplate: "advanced",
            modelHint: .advanced
        )

        #expect(resolver.resolve(for: fastWorkflow)?.id == fast.id)
        #expect(resolver.resolve(for: advancedWorkflow)?.id == advanced.id)
    }

    @Test("需要显式 profile 的 hint 在未配置时返回 nil")
    func explicitProfileHintsDoNotFallback() {
        let selected = ProviderProfile(name: "Selected", providerType: .openai)
        let resolver = WorkflowProfileResolver(
            availableProfiles: [selected],
            chatProfileId: nil,
            summaryProfileId: nil,
            selectedProfileId: selected.id
        )
        let workflow = WorkflowAction.builtin(
            keyword: "code",
            name: "code",
            description: "code",
            icon: "curlybraces",
            iconColorHex: "#5856D6",
            promptTemplate: "code",
            modelHint: .code
        )

        #expect(resolver.resolve(for: workflow) == nil)
    }

    @Test("default hint 在无显式偏好时回退到 selected 再到第一个 profile")
    func defaultHintFallsBackPredictably() {
        let first = ProviderProfile(name: "First", providerType: .openai)
        let second = ProviderProfile(name: "Second", providerType: .anthropic)
        let workflow = WorkflowAction.builtin(
            keyword: "default",
            name: "default",
            description: "default",
            icon: "text.bubble",
            iconColorHex: "#007AFF",
            promptTemplate: "default",
            modelHint: .default
        )

        let selectedResolver = WorkflowProfileResolver(
            availableProfiles: [first, second],
            chatProfileId: nil,
            summaryProfileId: nil,
            selectedProfileId: second.id
        )
        #expect(selectedResolver.resolve(for: workflow)?.id == second.id)

        let firstResolver = WorkflowProfileResolver(
            availableProfiles: [first, second],
            chatProfileId: nil,
            summaryProfileId: nil,
            selectedProfileId: nil
        )
        #expect(firstResolver.resolve(for: workflow)?.id == first.id)
    }
}
