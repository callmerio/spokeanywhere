import AVFoundation
import Foundation

// MARK: - Transcription Result

/// 转录结果类型
enum TranscriptionResultType {
    case partial    // 部分结果（实时预览，可能会变化）
    case final      // 最终结果（稳定，不会再变）
}

/// 转录结果
struct TranscriptionResult {
    /// 完整文本（用于显示）= finalizedText + volatileText
    let text: String
    
    /// 已确认的文本（稳定，不会再变）
    let finalizedText: String
    
    /// 预览文本（可能会变化）
    let volatileText: String
    
    let type: TranscriptionResultType
    let confidence: Float?
    let timestamp: TimeInterval?
    
    /// 完整构造器
    init(finalizedText: String, volatileText: String, type: TranscriptionResultType, confidence: Float? = nil, timestamp: TimeInterval? = nil) {
        self.finalizedText = finalizedText
        self.volatileText = volatileText
        self.text = finalizedText + volatileText
        self.type = type
        self.confidence = confidence
        self.timestamp = timestamp
    }
    
    /// 兼容旧代码的简化构造器
    init(text: String, type: TranscriptionResultType, confidence: Float? = nil, timestamp: TimeInterval? = nil) {
        self.text = text
        // 如果是 final 类型，全部作为 finalized
        // 如果是 partial 类型，全部作为 volatile（保守处理）
        if type == .final {
            self.finalizedText = text
            self.volatileText = ""
        } else {
            self.finalizedText = ""
            self.volatileText = text
        }
        self.type = type
        self.confidence = confidence
        self.timestamp = timestamp
    }
}

// MARK: - Provider Capability

/// 转录引擎能力
struct TranscriptionCapability: OptionSet {
    let rawValue: Int
    
    /// 支持实时转录（边说边出文字）
    static let realtime = TranscriptionCapability(rawValue: 1 << 0)
    /// 支持离线模式
    static let offline = TranscriptionCapability(rawValue: 1 << 1)
    /// 支持长时间录音（>1分钟）
    static let longForm = TranscriptionCapability(rawValue: 1 << 2)
    /// 支持自动添加标点
    static let punctuation = TranscriptionCapability(rawValue: 1 << 3)
    /// 支持多语言
    static let multilingual = TranscriptionCapability(rawValue: 1 << 4)
}

// MARK: - Provider Protocol

/// 转录引擎协议
/// 所有语音转文字引擎必须实现此协议
@MainActor
protocol TranscriptionProvider: AnyObject {
    
    /// 引擎唯一标识符
    var identifier: String { get }
    
    /// 引擎显示名称
    var displayName: String { get }
    
    /// 引擎能力
    var capabilities: TranscriptionCapability { get }
    
    /// 当前是否可用（权限、网络等）
    var isAvailable: Bool { get }
    
    /// 当前语言
    var locale: Locale { get set }
    
    /// 支持的语言列表
    var supportedLocales: [Locale] { get }
    
    // MARK: - Callbacks
    
    /// 转录结果回调
    var onResult: ((TranscriptionResult) -> Void)? { get set }
    
    /// 错误回调
    var onError: ((Error) -> Void)? { get set }
    
    // MARK: - Lifecycle
    
    /// 请求必要权限
    func requestAuthorization() async -> Bool
    
    /// 准备引擎（预热、加载模型等）
    func prepare() async throws
    
    /// 处理音频缓冲区
    func process(buffer: AVAudioPCMBuffer) throws
    
    /// 结束音频输入（等待最终结果）
    func finishProcessing() async throws
    
    /// 取消当前转录
    func cancel()
    
    /// 重置状态
    func reset()
}

// MARK: - Provider Info

/// 引擎信息（用于 UI 展示）
struct TranscriptionProviderInfo {
    let identifier: String
    let displayName: String
    let description: String
    let capabilities: TranscriptionCapability
    let minOSVersion: String
    let isAvailable: Bool
}

// MARK: - Provider Error

enum TranscriptionError: LocalizedError {
    case notAvailable
    case notAuthorized
    case engineNotReady
    case processingFailed(String)
    case unsupportedLocale(Locale)
    case modelNotInstalled
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "转录引擎不可用"
        case .notAuthorized:
            return "未授权使用语音识别"
        case .engineNotReady:
            return "引擎未就绪"
        case .processingFailed(let reason):
            return "处理失败: \(reason)"
        case .unsupportedLocale(let locale):
            return "不支持的语言: \(locale.identifier)"
        case .modelNotInstalled:
            return "语言模型未安装"
        case .cancelled:
            return "已取消"
        }
    }
}
