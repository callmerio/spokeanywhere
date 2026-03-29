import Foundation

struct TranscriptionModelManagerDependencies {
    let postModelChanged: (_ modelId: String) -> Void
    let postModelRoleChanged: (_ modelId: String, _ role: String) -> Void
}

@MainActor
extension TranscriptionModelManagerDependencies {
    static let live = TranscriptionModelManagerDependencies(
        postModelChanged: { modelId in
            NotificationCenter.default.post(
                name: .transcriptionModelChanged,
                object: nil,
                userInfo: ["modelId": modelId]
            )
        },
        postModelRoleChanged: { modelId, role in
            NotificationCenter.default.post(
                name: .transcriptionModelRoleChanged,
                object: nil,
                userInfo: ["modelId": modelId, "role": role]
            )
        }
    )
}
