import Testing
@testable import SpokenAnyWhere

@Suite("LLMSettings 测试", .serialized)
@MainActor
struct LLMSettingsTests {

    @Test("无选中 provider/profile 时 currentProviderName 回退为 Unknown")
    func currentProviderNameFallsBackPredictably() {
        let settings = LLMSettings.makeTesting()
        let originalProfiles = settings.profiles
        let originalSelectedProfileId = settings.selectedProfileId
        let originalSelectedProviderType = settings.selectedProviderType
        defer {
            settings.profiles = originalProfiles
            settings.selectedProfileId = originalSelectedProfileId
            settings.selectedProviderType = originalSelectedProviderType
        }

        settings.profiles = []
        settings.selectedProfileId = nil
        settings.selectedProviderType = nil

        #expect(settings.currentProviderName == "Unknown")
    }

    @Test("duplicateProfile 会复制 profile 基本属性")
    func duplicateProfileCopiesCoreFields() {
        let settings = LLMSettings.makeTesting()
        let originalProfiles = settings.profiles
        let profile = settings.createProfile(for: .openai, name: "Primary")
        defer { settings.profiles = originalProfiles }

        let duplicated = settings.duplicateProfile(profile.id)

        #expect(duplicated?.id != profile.id)
        #expect(duplicated?.providerType == profile.providerType)
        #expect(duplicated?.name.contains("Primary") == true)
    }
}
