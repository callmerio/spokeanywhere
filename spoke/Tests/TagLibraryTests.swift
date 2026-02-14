import Foundation
import Testing
@testable import SpokenAnyWhere

// MARK: - CardTag Tests

@Suite("CardTag 测试")
struct CardTagTests {

    @Test("初始化时应生成唯一 ID")
    func initGeneratesUniqueId() {
        let tag1 = CardTag(name: "tag1")
        let tag2 = CardTag(name: "tag2")
        #expect(tag1.id != tag2.id)
    }

    @Test("初始化时应设置默认颜色")
    func initSetsDefaultColor() {
        let tag = CardTag(name: "test")
        // 默认颜色应该是有效的 TagColor
        #expect(TagColor.allCases.contains(tag.color))
    }

    @Test("初始化时可以指定颜色")
    func initWithCustomColor() {
        let tag = CardTag(name: "test", color: .blue)
        #expect(tag.color == .blue)
    }
}

// MARK: - TagLibrary Tests

@Suite("TagLibrary 测试")
@MainActor
struct TagLibraryTests {

    private func makeIsolatedLibrary() -> TagLibrary {
        let baseDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoke-tag-library-tests-\(UUID().uuidString)", isDirectory: true)
        let storageURL = baseDir.appendingPathComponent("tag_library.json")
        let recentURL = baseDir.appendingPathComponent("recent_tags.json")
        return TagLibrary(
            storageURL: storageURL,
            recentTagIdsURL: recentURL,
            loadPersistedData: false
        )
    }

    // MARK: - Singleton

    @Test("shared 单例应存在且始终一致")
    func sharedInstanceConsistent() {
        let library1 = TagLibrary.shared
        let library2 = TagLibrary.shared

        #expect(library1 === library2)
    }

    // MARK: - Create Tag

    @Test("创建标签应返回新标签")
    func createTagReturnsNewTag() {
        let library = makeIsolatedLibrary()
        let uniqueName = "test_tag_\(Date().timeIntervalSince1970)"

        let tag = library.createTag(name: uniqueName)

        #expect(tag.name == uniqueName)

        // 清理
        library.deleteTag(tag.id)
    }

    @Test("创建标签时应自动去除首尾空白")
    func createTagTrimsWhitespace() {
        let library = makeIsolatedLibrary()
        let uniqueName = "trimtest_\(Date().timeIntervalSince1970)"

        let tag = library.createTag(name: "  \(uniqueName)  ")

        #expect(tag.name == uniqueName)

        // 清理
        library.deleteTag(tag.id)
    }

    @Test("创建空名称标签应返回默认名称")
    func createEmptyNameReturnsDefault() {
        let library = makeIsolatedLibrary()

        let tag = library.createTag(name: "")

        #expect(tag.name == "未命名")

        // 清理
        library.deleteTag(tag.id)
    }

    @Test("创建重复名称标签应返回已存在的标签")
    func createDuplicateReturnsExisting() {
        let library = makeIsolatedLibrary()
        let uniqueName = "duplicate_\(Date().timeIntervalSince1970)"

        let first = library.createTag(name: uniqueName)
        let second = library.createTag(name: uniqueName)

        #expect(first.id == second.id)

        // 清理
        library.deleteTag(first.id)
    }

    @Test("创建标签时可以指定颜色")
    func createTagWithColor() {
        let library = makeIsolatedLibrary()
        let uniqueName = "colored_\(Date().timeIntervalSince1970)"

        let tag = library.createTag(name: uniqueName, color: .green)

        #expect(tag.color == .green)

        // 清理
        library.deleteTag(tag.id)
    }

    // MARK: - Query

    @Test("tag(for:) 应根据 ID 返回标签")
    func tagForIdReturnsTag() {
        let library = makeIsolatedLibrary()
        let uniqueName = "query_id_\(Date().timeIntervalSince1970)"

        let created = library.createTag(name: uniqueName)
        let found = library.tag(for: created.id)

        #expect(found != nil)
        #expect(found?.id == created.id)

        // 清理
        library.deleteTag(created.id)
    }

    @Test("tag(for:) 对不存在的 ID 应返回 nil")
    func tagForNonExistentIdReturnsNil() {
        let library = makeIsolatedLibrary()

        let found = library.tag(for: UUID())

        #expect(found == nil)
    }

    @Test("tag(named:) 应根据名称返回标签（忽略大小写）")
    func tagNamedIgnoresCase() {
        let library = makeIsolatedLibrary()
        let uniqueName = "CaseTest_\(Date().timeIntervalSince1970)"

        let created = library.createTag(name: uniqueName)
        let found = library.tag(named: uniqueName.lowercased())

        #expect(found != nil)
        #expect(found?.id == created.id)

        // 清理
        library.deleteTag(created.id)
    }

    @Test("tags(for:) 应根据 ID 列表返回标签（保持顺序）")
    func tagsForIdsPreservesOrder() {
        let library = makeIsolatedLibrary()
        let name1 = "order1_\(Date().timeIntervalSince1970)"
        let name2 = "order2_\(Date().timeIntervalSince1970)"

        let tag1 = library.createTag(name: name1)
        let tag2 = library.createTag(name: name2)

        let tags = library.tags(for: [tag2.id, tag1.id])

        #expect(tags.count == 2)
        #expect(tags[0].id == tag2.id)
        #expect(tags[1].id == tag1.id)

        // 清理
        library.deleteTag(tag1.id)
        library.deleteTag(tag2.id)
    }

    // MARK: - Search

    @Test("search 应支持前缀匹配")
    func searchPrefixMatch() {
        let library = makeIsolatedLibrary()
        let prefix = "searchprefix_\(Int(Date().timeIntervalSince1970))"

        let tag1 = library.createTag(name: "\(prefix)_one")
        let tag2 = library.createTag(name: "\(prefix)_two")
        let tag3 = library.createTag(name: "other_tag")

        let results = library.search(prefix)

        #expect(results.count >= 2)
        #expect(results.contains { $0.id == tag1.id })
        #expect(results.contains { $0.id == tag2.id })

        // 清理
        library.deleteTag(tag1.id)
        library.deleteTag(tag2.id)
        library.deleteTag(tag3.id)
    }

    @Test("search 空字符串应返回所有标签")
    func searchEmptyReturnsAll() {
        let library = makeIsolatedLibrary()

        let results = library.search("")

        #expect(results.count == library.tags.count)
    }

    // MARK: - Update

    @Test("updateTagName 应更新标签名称")
    func updateTagNameWorks() {
        let library = makeIsolatedLibrary()
        let originalName = "original_\(Date().timeIntervalSince1970)"
        let newName = "updated_\(Date().timeIntervalSince1970)"

        let tag = library.createTag(name: originalName)
        library.updateTagName(tag.id, name: newName)

        let updated = library.tag(for: tag.id)
        #expect(updated?.name == newName)

        // 清理
        library.deleteTag(tag.id)
    }

    @Test("updateTagColor 应更新标签颜色")
    func updateTagColorWorks() {
        let library = makeIsolatedLibrary()
        let uniqueName = "colorupdate_\(Date().timeIntervalSince1970)"

        let tag = library.createTag(name: uniqueName, color: .red)
        library.updateTagColor(tag.id, color: .purple)

        let updated = library.tag(for: tag.id)
        #expect(updated?.color == .purple)

        // 清理
        library.deleteTag(tag.id)
    }

    // MARK: - Delete

    @Test("deleteTag 应删除标签")
    func deleteTagRemovesTag() {
        let library = makeIsolatedLibrary()
        let uniqueName = "todelete_\(Date().timeIntervalSince1970)"

        let tag = library.createTag(name: uniqueName)
        let id = tag.id

        library.deleteTag(id)

        #expect(library.tag(for: id) == nil)
    }

    @Test("deleteTag 对不存在的 ID 应无副作用")
    func deleteNonExistentIdNoOp() {
        let library = makeIsolatedLibrary()
        let initialCount = library.tags.count

        library.deleteTag(UUID())

        #expect(library.tags.count == initialCount)
    }

    // MARK: - Recent Tags

    @Test("markAsRecentlyUsed 应将标签添加到最近使用")
    func markAsRecentlyUsedAddsToRecent() {
        let library = makeIsolatedLibrary()
        let uniqueName = "recent_\(Date().timeIntervalSince1970)"

        let tag = library.createTag(name: uniqueName)
        library.markAsRecentlyUsed(tag.id)

        #expect(library.recentTags.contains { $0.id == tag.id })

        // 清理
        library.deleteTag(tag.id)
    }

    @Test("markAsRecentlyUsed 应将标签移到最前面")
    func markAsRecentlyUsedMovesToFront() {
        let library = makeIsolatedLibrary()
        let name1 = "recent1_\(Date().timeIntervalSince1970)"
        let name2 = "recent2_\(Date().timeIntervalSince1970)"

        let tag1 = library.createTag(name: name1)
        let tag2 = library.createTag(name: name2)

        library.markAsRecentlyUsed(tag1.id)
        library.markAsRecentlyUsed(tag2.id)
        library.markAsRecentlyUsed(tag1.id) // 再次使用 tag1

        #expect(library.recentTags.first?.id == tag1.id)

        // 清理
        library.deleteTag(tag1.id)
        library.deleteTag(tag2.id)
    }

    @Test("隔离存储实例之间不应共享状态")
    func isolatedStorageDoesNotShareState() {
        let library1 = makeIsolatedLibrary()
        let library2 = makeIsolatedLibrary()

        let tag = library1.createTag(name: "isolated_\(Date().timeIntervalSince1970)")
        #expect(library1.tags.contains { $0.id == tag.id })
        #expect(library2.tag(named: tag.name) == nil)
    }
}

// MARK: - Notification Tests

@Suite("TagLibrary 通知测试")
struct TagLibraryNotificationTests {

    @Test("tagDeleted 通知名称应正确定义")
    func notificationNameExists() {
        let name = Notification.Name.tagDeleted
        #expect(name.rawValue == "tagDeleted")
    }
}
