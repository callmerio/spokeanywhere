import Foundation

typealias AISettingsConnectionTestRunner = @MainActor (
    _ profile: ProviderProfile,
    _ llmSettings: LLMSettings,
    _ update: @escaping @MainActor (_ isTesting: Bool, _ result: AISettingsConnectionTestResult?) -> Void
) -> Void

@MainActor
func runAISettingsConnectionTest(
    profile: ProviderProfile,
    llmSettings: LLMSettings,
    update: @escaping @MainActor (_ isTesting: Bool, _ result: AISettingsConnectionTestResult?) -> Void
) {
    guard let provider = llmSettings.createProvider(for: profile) else {
        update(false, .failure("未配置"))
        return
    }

    update(true, nil)

    Task(priority: .userInitiated) {
        do {
            let success = try await provider.testConnection()
            await MainActor.run {
                update(false, success ? .success : .failure("连接失败"))
            }
        } catch let error as LLMError {
            await MainActor.run {
                update(false, .failure(error.localizedDescription))
            }
        } catch {
            await MainActor.run {
                update(false, .failure("未知错误: \(error.localizedDescription)"))
            }
        }
    }
}
