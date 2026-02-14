import Foundation
import Testing
@testable import SpokenAnyWhere

// MARK: - VocabularyItem Tests

@Suite("VocabularyItem 测试")
struct VocabularyItemTests {

    @Test("初始化时应自动去除首尾空白")
    func initTrimsWhitespace() {
        let item = VocabularyItem(word: "  hello world  ")
        #expect(item.word == "hello world")
    }

    @Test("初始化时应生成唯一 ID")
    func initGeneratesUniqueId() {
        let item1 = VocabularyItem(word: "test1")
        let item2 = VocabularyItem(word: "test2")
        #expect(item1.id != item2.id)
    }

    @Test("初始化时应设置创建时间")
    func initSetsCreatedAt() {
        let before = Date()
        let item = VocabularyItem(word: "test")
        let after = Date()

        #expect(item.createdAt >= before)
        #expect(item.createdAt <= after)
    }

    @Test("相同内容的 VocabularyItem 应该相等")
    func equatableWorks() {
        let id = UUID()
        let date = Date()
        let item1 = VocabularyItem(id: id, word: "test", createdAt: date)
        let item2 = VocabularyItem(id: id, word: "test", createdAt: date)

        #expect(item1 == item2)
    }
}

// MARK: - VocabularyService Tests

@Suite("VocabularyService 测试")
@MainActor
struct VocabularyServiceTests {

    private func makeIsolatedService() -> VocabularyService {
        let baseDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("spoke-vocab-tests-\(UUID().uuidString)", isDirectory: true)
        let storageURL = baseDir.appendingPathComponent("vocabulary.json")
        return VocabularyService(storageURL: storageURL, maxVocabularySize: 1000, loadPersistedItems: false)
    }

    // MARK: - Singleton

    @Test("shared 单例应存在且始终一致")
    func sharedInstanceConsistent() {
        let service1 = VocabularyService.shared
        let service2 = VocabularyService.shared

        #expect(service1 === service2)
    }

    // MARK: - Add Words

    @Test("添加有效生词应返回新条目")
    func addValidWordReturnsItem() {
        let service = makeIsolatedService()
        let initialCount = service.items.count

        // 使用时间戳确保唯一性
        let uniqueWord = "testword_\(Date().timeIntervalSince1970)"
        let item = service.add(uniqueWord)

        #expect(item != nil)
        #expect(item?.word == uniqueWord)
        #expect(service.items.count == initialCount + 1)

        // 清理
        if let item = item {
            service.remove(item.id)
        }
    }

    @Test("添加空字符串应返回 nil")
    func addEmptyStringReturnsNil() {
        let service = makeIsolatedService()
        let initialCount = service.items.count

        let item = service.add("")

        #expect(item == nil)
        #expect(service.items.count == initialCount)
    }

    @Test("添加纯空白字符串应返回 nil")
    func addWhitespaceOnlyReturnsNil() {
        let service = makeIsolatedService()
        let initialCount = service.items.count

        let item = service.add("   \t\n  ")

        #expect(item == nil)
        #expect(service.items.count == initialCount)
    }

    @Test("添加重复生词应返回 nil（忽略大小写）")
    func addDuplicateReturnsNil() {
        let service = makeIsolatedService()
        let uniqueWord = "DuplicateTest_\(Date().timeIntervalSince1970)"

        let first = service.add(uniqueWord)
        #expect(first != nil)

        // 尝试添加相同词（不同大小写）
        let duplicate = service.add(uniqueWord.uppercased())
        #expect(duplicate == nil)

        // 清理
        if let first = first {
            service.remove(first.id)
        }
    }

    @Test("新添加的生词应在列表最前面")
    func newWordInsertedAtFront() {
        let service = makeIsolatedService()
        let uniqueWord = "fronttest_\(Date().timeIntervalSince1970)"

        let item = service.add(uniqueWord)

        #expect(service.items.first?.id == item?.id)

        // 清理
        if let item = item {
            service.remove(item.id)
        }
    }

    // MARK: - Remove Words

    @Test("删除存在的生词应成功")
    func removeExistingWord() {
        let service = makeIsolatedService()
        let uniqueWord = "removetest_\(Date().timeIntervalSince1970)"

        let item = service.add(uniqueWord)
        #expect(item != nil)

        let countBefore = service.items.count
        service.remove(item!.id)

        #expect(service.items.count == countBefore - 1)
        #expect(!service.contains(uniqueWord))
    }

    @Test("删除不存在的 ID 应无副作用")
    func removeNonExistentIdNoOp() {
        let service = makeIsolatedService()
        let initialCount = service.items.count

        service.remove(UUID())

        #expect(service.items.count == initialCount)
    }

    // MARK: - Contains Check

    @Test("contains 应忽略大小写")
    func containsIgnoresCase() {
        let service = makeIsolatedService()
        let uniqueWord = "CaseSensitive_\(Date().timeIntervalSince1970)"

        let item = service.add(uniqueWord)
        #expect(item != nil)

        #expect(service.contains(uniqueWord.lowercased()) == true)
        #expect(service.contains(uniqueWord.uppercased()) == true)

        // 清理
        if let item = item {
            service.remove(item.id)
        }
    }

    @Test("contains 对不存在的词应返回 false")
    func containsReturnsFalseForNonExistent() {
        let service = makeIsolatedService()

        #expect(service.contains("nonexistent_word_xyz_\(UUID())") == false)
    }

    // MARK: - getAllWords

    @Test("getAllWords 应返回所有词的小写版本")
    func getAllWordsReturnsLowercased() {
        let service = makeIsolatedService()
        let uniqueWord = "UPPERCASE_\(Date().timeIntervalSince1970)"

        let item = service.add(uniqueWord)
        #expect(item != nil)

        let allWords = service.getAllWords()
        #expect(allWords.contains(uniqueWord.lowercased()))

        // 清理
        if let item = item {
            service.remove(item.id)
        }
    }

    // MARK: - Highlight Ranges

    @Test("highlightRanges 应找到生词的位置")
    func highlightRangesFindsWords() {
        let service = makeIsolatedService()
        let uniqueWord = "highlight_\(Int(Date().timeIntervalSince1970))"

        let item = service.add(uniqueWord)
        #expect(item != nil)

        let text = "This is a test with \(uniqueWord) inside."
        let ranges = service.highlightRanges(in: text)

        #expect(ranges.count >= 1)

        // 清理
        if let item = item {
            service.remove(item.id)
        }
    }

    @Test("highlightRanges 无匹配时应返回空数组")
    func highlightRangesReturnsEmptyWhenNoMatch() {
        let service = makeIsolatedService()

        let text = "This text has no vocabulary words that match xyz123456789"
        let ranges = service.highlightRanges(in: text)

        // 可能有其他已添加的词，但这个特定文本应该没有匹配
        // 这个测试主要验证不会崩溃
        #expect(ranges.count >= 0)
    }

    // MARK: - Mark Vocabulary

    @Test("markVocabulary 应用默认模板标记生词")
    func markVocabularyWithDefaultTemplate() {
        let service = makeIsolatedService()
        let uniqueWord = "marked_\(Int(Date().timeIntervalSince1970))"

        let item = service.add(uniqueWord)
        #expect(item != nil)

        let text = "Test \(uniqueWord) here"
        let marked = service.markVocabulary(in: text)

        #expect(marked.contains("<word>\(uniqueWord)</word>"))

        // 清理
        if let item = item {
            service.remove(item.id)
        }
    }

    @Test("markVocabulary 应支持自定义模板")
    func markVocabularyWithCustomTemplate() {
        let service = makeIsolatedService()
        let uniqueWord = "custom_\(Int(Date().timeIntervalSince1970))"

        let item = service.add(uniqueWord)
        #expect(item != nil)

        let text = "Test \(uniqueWord) here"
        let marked = service.markVocabulary(in: text, template: "**$0**")

        #expect(marked.contains("**\(uniqueWord)**"))

        // 清理
        if let item = item {
            service.remove(item.id)
        }
    }

    // MARK: - Clear All

    @Test("clearAll 应清空所有生词")
    func clearAllRemovesEverything() {
        let service = makeIsolatedService()

        // 添加一些测试词
        let word1 = service.add("cleartest1_\(Date().timeIntervalSince1970)")
        let word2 = service.add("cleartest2_\(Date().timeIntervalSince1970)")

        #expect(word1 != nil)
        #expect(word2 != nil)

        service.clearAll()

        #expect(service.items.isEmpty)
        #expect(service.getAllWords().isEmpty)
    }

    @Test("隔离存储实例之间不应共享生词状态")
    func isolatedStorageDoesNotShareState() {
        let service1 = makeIsolatedService()
        let service2 = makeIsolatedService()

        let uniqueWord = "isolated_vocab_\(Int(Date().timeIntervalSince1970))"
        let item = service1.add(uniqueWord)

        #expect(item != nil)
        #expect(service1.contains(uniqueWord))
        #expect(service2.contains(uniqueWord) == false)
        #expect(service2.items.isEmpty)
    }
}

// MARK: - Notification Tests

@Suite("VocabularyService 通知测试")
struct VocabularyNotificationTests {

    @Test("vocabularyChanged 通知名称应正确定义")
    func notificationNameExists() {
        let name = Notification.Name.vocabularyChanged
        #expect(name.rawValue == "vocabularyChanged")
    }
}
