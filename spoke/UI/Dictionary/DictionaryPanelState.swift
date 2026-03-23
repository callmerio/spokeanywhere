import Combine
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.spokeanywhere", category: "DictionaryPanelState")

// MARK: - View Mode

enum DictionaryPanelViewMode: Equatable {
    case list
    case detail(LocalDictionaryResult)
}

@MainActor
struct DictionaryPanelDependencies {
    let localDictionary: LocalDictionaryService
    let vocabularyService: VocabularyService
    let openURL: (URL) -> Void
}

// MARK: - Dictionary Panel State

@MainActor
@Observable
final class DictionaryPanelState {
    
    // MARK: - Static Access (for keyboard handling in NSTextField)
    
    static var current: DictionaryPanelState?
    
    // MARK: - Properties
    
    var searchText: String = ""
    var results: [LocalDictionaryResult] = []
    var selectedIndex: Int = 0
    var viewMode: DictionaryPanelViewMode = .list
    var isLoading: Bool = false
    
    /// 用于触发 UI 刷新（当 vocabularyService 变化时）
    var refreshTrigger: Int = 0
    
    private let dependencies: DictionaryPanelDependencies
    
    // MARK: - Debounce
    
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Computed
    
    var selectedResult: LocalDictionaryResult? {
        guard selectedIndex >= 0 && selectedIndex < results.count else { return nil }
        return results[selectedIndex]
    }
    
    var hasResults: Bool {
        !results.isEmpty
    }
    
    // MARK: - Public API

    init(
        dependencies: DictionaryPanelDependencies
    ) {
        self.dependencies = dependencies
    }
    
    func search(_ query: String) {
        searchText = query
        
        searchTask?.cancel()
        searchTask = makeDictionaryPanelSearchTask(
            delay: 0.05,
            owner: self
        ) { state in
            guard !Task.isCancelled else { return }
            
            await state.performSearch(query)
        }
    }
    
    func performSearch(_ query: String) async {
        isLoading = true
        
        // 在后台线程执行搜索，避免阻塞主线程输入
        let searchResults = await runDictionaryPanelDetached(priority: .userInitiated) { [localDictionary = dependencies.localDictionary] in
            return localDictionary.search(query)
        }
        
        // 检查是否已被取消（用户继续输入了新内容）
        guard !Task.isCancelled else { return }
        
        results = searchResults
        selectedIndex = 0
        isLoading = false
        
        logger.info("📖 [Panel] 搜索: \(query) -> \(searchResults.count) 结果")
    }
    
    func selectNext() {
        guard hasResults else { return }
        selectedIndex = min(selectedIndex + 1, results.count - 1)
    }
    
    func selectPrevious() {
        guard hasResults else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }
    
    func confirmSelection() {
        guard let result = selectedResult else { return }
        
        dependencies.localDictionary.addToHistory(result.word)
        
        viewMode = .detail(result)
        logger.info("📖 [Panel] 进入详情: \(result.word)")
    }
    
    func backToList() {
        viewMode = .list
    }
    
    func toggleVocabulary() {
        guard let result = selectedResult else { return }
        
        let word = result.word.lowercased()
        
        if dependencies.vocabularyService.contains(word) {
            if let item = dependencies.vocabularyService.items.first(where: { $0.word.lowercased() == word }) {
                dependencies.vocabularyService.remove(item.id)
                logger.info("📖 [Panel] 移除生词: \(word)")
            }
        } else {
            dependencies.vocabularyService.add(word)
            // 添加到 recent 历史
            dependencies.localDictionary.addToHistory(result.word)
            logger.info("📖 [Panel] 添加生词: \(word)")
        }
        
        // 触发 UI 刷新
        refreshTrigger += 1
    }
    
    func isVocabulary(_ word: String) -> Bool {
        dependencies.vocabularyService.contains(word.lowercased())
    }
    
    func reset() {
        searchText = ""
        results = []
        selectedIndex = 0
        viewMode = .list
        isLoading = false
        
        runDictionaryPanelAsync {
            await self.performSearch("")
        }
    }
    
    func openInDictionary() {
        guard let result = selectedResult else { return }
        
        let url = URL(string: "dict://\(result.word)")!
        dependencies.openURL(url)
        logger.info("📖 [Panel] 打开系统词典: \(result.word)")
    }
}
