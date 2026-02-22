import Foundation
import OSLog

private let logger = Logger(subsystem: "com.spokeanywhere", category: "DictionaryAPIService")

// MARK: - 词典 API 响应模型

struct DictionaryAPIResponse: Codable {
    let success: Bool
    let data: DictionaryData?
    let error: String?
}

struct DictionaryData: Codable {
    let word: String
    let phonetic: String?
    let senses: [DictionarySense]
    let lemma: String?
    let lemmaInfo: LemmaInfo?
    
    /// 获取有效释义（优先使用原型释义）
    var effectiveSenses: [DictionarySense] {
        if let lemmaInfo = lemmaInfo, !lemmaInfo.senses.isEmpty {
            return lemmaInfo.senses
        }
        return senses
    }
    
    /// 获取词形类型描述（如"第三人称单数"）
    var formTypeDisplay: String? {
        lemmaInfo?.formTypes.first
    }
    
    /// 获取原型词
    var lemmaWord: String? {
        lemmaInfo?.lemma
    }
}

/// 原型词信息
struct LemmaInfo: Codable {
    let lemma: String
    let senses: [DictionarySense]
    let formTypes: [String]
    let formNote: String?
}

struct DictionarySense: Codable {
    let pos: String?
    let chinese: String?
    let english: String?
    let examples: [String]?
    
    var posDisplay: String {
        guard let pos = pos else { return "" }
        switch pos.lowercased() {
        case "noun", "n", "n.": return "n."
        case "verb", "v", "v.": return "v."
        case "transitive verb", "vt", "vt.": return "vt."
        case "intransitive verb", "vi", "vi.": return "vi."
        case "adjective", "adj", "adj.": return "adj."
        case "adverb", "adv", "adv.": return "adv."
        case "preposition", "prep", "prep.": return "prep."
        case "conjunction", "conj", "conj.": return "conj."
        case "pronoun", "pron", "pron.": return "pron."
        case "interjection", "interj", "interj.": return "interj."
        case "determiner", "det", "det.": return "det."
        case "article", "art", "art.": return "art."
        default: return pos
        }
    }
}

// MARK: - 词典 API 服务

@MainActor
final class DictionaryAPIService {
    
    // MARK: - Singleton
    
    static let shared = DictionaryAPIService()
    
    // MARK: - Configuration
    
    private var baseURL: String {
        if let envURL = ProcessInfo.processInfo.environment["DICTIONARY_API_URL"] {
            return envURL
        }
        return UserDefaults.standard.string(forKey: "dictionary.api.baseURL") ?? "http://localhost:3011"
    }
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Public API
    
    /// 设置 API 基础 URL
    func setBaseURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "dictionary.api.baseURL")
        logger.info("📖 [DictionaryAPI] baseURL 已更新: \(url)")
    }
    
    /// 获取当前 API 基础 URL
    func getBaseURL() -> String {
        return baseURL
    }
    
    /// 查询单词
    /// - Parameter word: 要查询的单词
    /// - Returns: 词典数据或错误
    func lookup(_ word: String) async -> Result<DictionaryData, DictionaryAPIError> {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedWord.isEmpty else {
            return .failure(.invalidWord)
        }
        
        guard let encodedWord = trimmedWord.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return .failure(.invalidWord)
        }
        
        let urlString = "\(baseURL)/api/dictionary/en/\(encodedWord)"
        
        guard let url = URL(string: urlString) else {
            logger.error("📖 [DictionaryAPI] 无效的 URL: \(urlString)")
            return .failure(.invalidURL)
        }
        
        logger.info("📖 [DictionaryAPI] 查询: \(trimmedWord)")
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.networkError("无效的响应"))
            }
            
            if httpResponse.statusCode == 404 {
                return .failure(.notFound)
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(.networkError("HTTP \(httpResponse.statusCode)"))
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(DictionaryAPIResponse.self, from: data)
            
            if apiResponse.success, let dictData = apiResponse.data {
                logger.info("📖 [DictionaryAPI] 查询成功: \(dictData.word) (\(dictData.senses.count) 个释义)")
                return .success(dictData)
            } else {
                let errorMsg = apiResponse.error ?? "未知错误"
                logger.warning("📖 [DictionaryAPI] API 返回错误: \(errorMsg)")
                return .failure(.apiError(errorMsg))
            }
        } catch let error as DecodingError {
            logger.error("📖 [DictionaryAPI] 解码失败: \(error.localizedDescription)")
            return .failure(.decodingError(error.localizedDescription))
        } catch {
            logger.error("📖 [DictionaryAPI] 网络错误: \(error.localizedDescription)")
            return .failure(.networkError(error.localizedDescription))
        }
    }
    
    /// 检查 API 是否可用
    func checkAvailability() async -> Bool {
        let result = await lookup("test")
        switch result {
        case .success:
            return true
        case .failure(let error):
            if case .notFound = error {
                return true
            }
            return false
        }
    }
}

// MARK: - 错误类型

enum DictionaryAPIError: LocalizedError {
    case invalidWord
    case invalidURL
    case notFound
    case networkError(String)
    case apiError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidWord:
            return "无效的单词"
        case .invalidURL:
            return "无效的 URL"
        case .notFound:
            return "未找到该单词"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .apiError(let msg):
            return "API 错误: \(msg)"
        case .decodingError(let msg):
            return "解析错误: \(msg)"
        }
    }

    var failureReason: String? {
        switch self {
        case .invalidWord:
            return "输入的单词格式无效或包含非法字符"
        case .invalidURL:
            return "字典 API URL 构建失败"
        case .notFound:
            return "字典 API 中没有该单词的释义"
        case .networkError(let msg):
            return "网络请求失败: \(msg)"
        case .apiError(let msg):
            return "字典 API 返回错误: \(msg)"
        case .decodingError(let msg):
            return "API 响应数据解析失败: \(msg)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidWord:
            return "请检查单词拼写，确保只包含字母和连字符"
        case .invalidURL:
            return "请检查字典 API 配置是否正确"
        case .notFound:
            return "请尝试其他单词，或使用本地字典"
        case .networkError:
            return "请检查网络连接，或稍后重试"
        case .apiError:
            return "请稍后重试，或切换到其他字典源"
        case .decodingError:
            return "请稍后重试，如果问题持续请联系支持"
        }
    }
}
