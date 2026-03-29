import Foundation

struct DictionarySelectableTextDependencies {
    let postAddToDictionaryRequest: (_ userInfo: [String: Any]) -> Void
}

extension DictionarySelectableTextDependencies {
    static func makeLive() -> Self {
        DictionarySelectableTextDependencies(
            postAddToDictionaryRequest: { userInfo in
                NotificationCenter.default.post(
                    name: .requestAddToDictionary,
                    object: nil,
                    userInfo: userInfo
                )
            }
        )
    }
}
