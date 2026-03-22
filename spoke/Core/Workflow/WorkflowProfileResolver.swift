import Foundation

struct WorkflowProfileResolver {
    let availableProfiles: [ProviderProfile]
    let chatProfileId: UUID?
    let summaryProfileId: UUID?
    let selectedProfileId: UUID?

    func resolve(for workflow: WorkflowAction) -> ProviderProfile? {
        if let profileId = workflow.profileId {
            return profile(matching: profileId)
        }

        if let preferredProfileId = preferredProfileID(for: workflow.modelHint) {
            return profile(matching: preferredProfileId)
        }

        if requiresExplicitProfile(for: workflow.modelHint) {
            return nil
        }

        if let selectedProfileId {
            return profile(matching: selectedProfileId)
        }

        return availableProfiles.first
    }

    private func preferredProfileID(for modelHint: WorkflowModelHint) -> UUID? {
        switch modelHint {
        case .fast:
            return chatProfileId
        case .advanced:
            return summaryProfileId
        case .default, .imageGen, .code:
            return nil
        }
    }

    private func requiresExplicitProfile(for modelHint: WorkflowModelHint) -> Bool {
        switch modelHint {
        case .imageGen, .code:
            return true
        case .default, .fast, .advanced:
            return false
        }
    }

    private func profile(matching id: UUID) -> ProviderProfile? {
        availableProfiles.first { $0.id == id }
    }
}
