import Foundation

/// TTS 服务提供商
enum TTSProvider: String, CaseIterable, Codable {
    case system = "system"      // macOS 原生
    case edge = "edge"          // Microsoft Edge TTS
    
    var displayName: String {
        switch self {
        case .system: return "系统原生"
        case .edge: return "Edge TTS"
        }
    }
    
    var description: String {
        switch self {
        case .system: return "使用 macOS 内置语音合成，离线可用"
        case .edge: return "使用微软 Edge TTS，音质更好，需联网"
        }
    }
}

/// Edge TTS 语音角色
enum EdgeVoice: String, CaseIterable, Codable {
    // 中文普通话
    case xiaoxiao = "zh-CN-XiaoxiaoNeural"
    case xiaoyi = "zh-CN-XiaoyiNeural"
    case yunjian = "zh-CN-YunjianNeural"
    case yunxi = "zh-CN-YunxiNeural"
    case yunxia = "zh-CN-YunxiaNeural"
    case yunyang = "zh-CN-YunyangNeural"
    
    // 中文台湾
    case hsiaoChen = "zh-TW-HsiaoChenNeural"
    case hsiaoYu = "zh-TW-HsiaoYuNeural"
    case yunJhe = "zh-TW-YunJheNeural"
    
    // 粤语
    case hiuGaai = "zh-HK-HiuGaaiNeural"
    case hiuMaan = "zh-HK-HiuMaanNeural"
    case wanLung = "zh-HK-WanLungNeural"
    
    // 英文
    case jenny = "en-US-JennyNeural"
    case guy = "en-US-GuyNeural"
    case aria = "en-US-AriaNeural"
    
    var displayName: String {
        switch self {
        case .xiaoxiao: return "晓晓 (女声·活泼)"
        case .xiaoyi: return "晓伊 (女声·温柔)"
        case .yunjian: return "云健 (男声·阳刚)"
        case .yunxi: return "云希 (男声·少年)"
        case .yunxia: return "云夏 (男声·儿童)"
        case .yunyang: return "云扬 (男声·新闻)"
        case .hsiaoChen: return "曉臻 (台湾女声)"
        case .hsiaoYu: return "曉雨 (台湾女声)"
        case .yunJhe: return "雲哲 (台湾男声)"
        case .hiuGaai: return "曉佳 (粤语女声)"
        case .hiuMaan: return "曉曼 (粤语女声)"
        case .wanLung: return "雲龍 (粤语男声)"
        case .jenny: return "Jenny (英文女声)"
        case .guy: return "Guy (英文男声)"
        case .aria: return "Aria (英文女声)"
        }
    }
    
    var language: String {
        String(rawValue.prefix(5)) // e.g., "zh-CN"
    }
}

/// TTS 设置
@MainActor
final class TTSSettings: ObservableObject {
    
    static let shared = TTSSettings()
    
    // MARK: - Keys
    
    private enum Keys {
        static let provider = "tts.provider"
        static let edgeVoice = "tts.edge.voice"
        static let edgeRate = "tts.edge.rate"
        static let edgePitch = "tts.edge.pitch"
        static let systemVoice = "tts.system.voice"
        static let systemRate = "tts.system.rate"
        static let autoReadAloud = "tts.autoReadAloud"
        static let chunkSize = "tts.chunkSize"
    }
    
    // MARK: - Properties
    
    @Published var provider: TTSProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: Keys.provider) }
    }
    
    // Edge TTS 配置
    @Published var edgeVoice: EdgeVoice {
        didSet { UserDefaults.standard.set(edgeVoice.rawValue, forKey: Keys.edgeVoice) }
    }
    
    /// 语速 (-50% ~ +100%)
    @Published var edgeRate: Int {
        didSet { UserDefaults.standard.set(edgeRate, forKey: Keys.edgeRate) }
    }
    
    /// 音调 (-50% ~ +50%)
    @Published var edgePitch: Int {
        didSet { UserDefaults.standard.set(edgePitch, forKey: Keys.edgePitch) }
    }
    
    // 系统 TTS 配置
    @Published var systemVoice: String {
        didSet { UserDefaults.standard.set(systemVoice, forKey: Keys.systemVoice) }
    }
    
    @Published var systemRate: Float {
        didSet { UserDefaults.standard.set(systemRate, forKey: Keys.systemRate) }
    }
    
    // 通用设置
    @Published var autoReadAloud: Bool {
        didSet { UserDefaults.standard.set(autoReadAloud, forKey: Keys.autoReadAloud) }
    }
    
    /// 分块大小（字符数），0 表示不分块
    @Published var chunkSize: Int {
        didSet { UserDefaults.standard.set(chunkSize, forKey: Keys.chunkSize) }
    }
    
    // MARK: - Init
    
    private init() {
        let defaults = UserDefaults.standard
        
        provider = TTSProvider(rawValue: defaults.string(forKey: Keys.provider) ?? "") ?? .edge
        
        edgeVoice = EdgeVoice(rawValue: defaults.string(forKey: Keys.edgeVoice) ?? "") ?? .xiaoxiao
        edgeRate = defaults.object(forKey: Keys.edgeRate) != nil ? defaults.integer(forKey: Keys.edgeRate) : 0
        edgePitch = defaults.object(forKey: Keys.edgePitch) != nil ? defaults.integer(forKey: Keys.edgePitch) : 0
        
        systemVoice = defaults.string(forKey: Keys.systemVoice) ?? "zh-CN"
        systemRate = defaults.float(forKey: Keys.systemRate) != 0 ? defaults.float(forKey: Keys.systemRate) : 0.5
        
        autoReadAloud = defaults.bool(forKey: Keys.autoReadAloud)
        chunkSize = defaults.integer(forKey: Keys.chunkSize) != 0 ? defaults.integer(forKey: Keys.chunkSize) : 100
    }
}
