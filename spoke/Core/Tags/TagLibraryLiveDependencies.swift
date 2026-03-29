import Foundation

func postTagDeletedNotification(id: UUID) {
    NotificationCenter.default.post(name: .tagDeleted, object: nil, userInfo: ["tagId": id])
}
