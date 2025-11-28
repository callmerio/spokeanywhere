import Foundation
import AVFoundation
import CryptoKit

// MARK: - Edge TTS 常量

private enum EdgeTTSConstants {
    static let chromiumVersion = "130.0.2849.68"
    static let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    static let windowsFileTimeEpoch: Int64 = 11_644_473_600
}

// MARK: - DRM Helper

private enum DRMHelper {
    /// 生成 Sec-MS-GEC Token (DRM 验证)
    static func generateSecMsGecToken() -> String {
        let currentTime = Int64(Date().timeIntervalSince1970)
        let ticks = (currentTime + EdgeTTSConstants.windowsFileTimeEpoch) * 10_000_000
        let roundedTicks = ticks - (ticks % 3_000_000_000)
        
        let strToHash = "\(roundedTicks)\(EdgeTTSConstants.trustedClientToken)"
        guard let data = strToHash.data(using: .ascii) else { return "" }
        
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02X", $0) }.joined()
    }
}

// MARK: - Edge TTS 错误

enum EdgeTTSError: Error, LocalizedError {
    case invalidURL
    case connectionFailed
    case noAudioData
    case synthesizeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .connectionFailed: return "连接失败"
        case .noAudioData: return "没有音频数据"
        case .synthesizeFailed(let msg): return "合成失败: \(msg)"
        }
    }
}

// MARK: - Edge TTS WebSocket 客户端

actor EdgeTTSClient {
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioData = Data()
    
    /// 合成语音
    func synthesize(text: String, voice: EdgeVoice, rate: Int, pitch: Int) async throws -> Data {
        audioData = Data()
        
        // 构建带 DRM Token 的 URL
        let secMsGec = DRMHelper.generateSecMsGecToken()
        let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(EdgeTTSConstants.trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(EdgeTTSConstants.chromiumVersion)"
        
        guard let url = URL(string: urlString) else {
            throw EdgeTTSError.invalidURL
        }
        
        print("[EdgeTTS] Connecting...")
        
        // 创建 WebSocket 请求
        var request = URLRequest(url: url)
        request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/\(EdgeTTSConstants.chromiumVersion) Safari/537.36 Edg/\(EdgeTTSConstants.chromiumVersion)", forHTTPHeaderField: "User-Agent")
        
        // 使用 delegate 模式连接
        let delegate = WebSocketDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // 等待连接建立
        try await delegate.waitForConnection()
        print("[EdgeTTS] Connected!")
        
        // 发送配置消息
        let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
        try await webSocketTask?.send(.string(configMessage))
        print("[EdgeTTS] Config sent")
        
        // 构建 SSML
        let rateStr = rate >= 0 ? "+\(rate)%" : "\(rate)%"
        let pitchStr = pitch >= 0 ? "+\(pitch)Hz" : "\(pitch)Hz"
        
        let ssml = """
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="\(voice.language)">
            <voice name="\(voice.rawValue)">
                <prosody rate="\(rateStr)" pitch="\(pitchStr)" volume="+0%">
                    \(escapeXML(text))
                </prosody>
            </voice>
        </speak>
        """
        
        let requestId = UUID().uuidString
        let ssmlMessage = "X-RequestId:\(requestId)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
        try await webSocketTask?.send(.string(ssmlMessage))
        print("[EdgeTTS] SSML sent, waiting for audio...")
        
        // 接收音频数据
        try await receiveMessages()
        
        print("[EdgeTTS] Received \(audioData.count) bytes")
        
        guard !audioData.isEmpty else {
            throw EdgeTTSError.noAudioData
        }
        
        return audioData
    }
    
    /// 接收消息
    private func receiveMessages() async throws {
        guard let ws = webSocketTask else { return }
        
        while true {
            do {
                let message = try await ws.receive()
                
                switch message {
                case .data(let data):
                    // 尝试解析为字符串看是否包含 Path:audio
                    if let dataStr = String(data: data, encoding: .utf8),
                       dataStr.contains("Path:audio\r\n") {
                        // 找到音频分隔符后的数据
                        let separator = "Path:audio\r\n"
                        if let range = dataStr.range(of: separator) {
                            let audioStartIndex = data.startIndex + range.upperBound.utf16Offset(in: dataStr)
                            let audioSubData = data[audioStartIndex...]
                            audioData.append(audioSubData)
                        }
                    } else {
                        // 纯二进制音频数据
                        audioData.append(data)
                    }
                    
                case .string(let text):
                    if text.contains("Path:turn.end") {
                        print("[EdgeTTS] Turn ended")
                        return
                    }
                    
                @unknown default:
                    break
                }
            } catch {
                print("[EdgeTTS] Error: \(error)")
                return
            }
        }
    }
    
    /// 转义 XML 特殊字符
    private func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
    
    /// 取消
    func cancel() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
}

// MARK: - WebSocket Delegate

private class WebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    
    func waitForConnection() async throws {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        continuation?.resume()
        continuation = nil
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }
}

// MARK: - 统一 TTS 服务

/// 统一 TTS 服务
/// 支持 macOS 原生 和 Edge TTS，支持分块朗读
@MainActor
final class TTSService: NSObject, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = TTSService()
    
    // MARK: - Properties
    
    @Published var isPlaying: Bool = false
    @Published var isSynthesizing: Bool = false
    @Published var currentChunkIndex: Int = 0
    @Published var totalChunks: Int = 0
    @Published var error: String?
    
    private let settings = TTSSettings.shared
    private let edgeClient = EdgeTTSClient()
    
    // 系统 TTS
    private let synthesizer = AVSpeechSynthesizer()
    
    // 音频播放
    private var audioPlayer: AVAudioPlayer?
    
    // 分块朗读
    private var chunks: [String] = []
    private var speakTask: Task<Void, Never>?
    
    // MARK: - Init
    
    private override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Public API
    
    /// 切换播放状态
    func toggleSpeak(_ text: String) {
        if isPlaying {
            stop()
        } else {
            speak(text)
        }
    }
    
    /// 朗读文本（支持分块）
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        
        stop()
        error = nil
        
        // 清理 Markdown 符号
        let cleanText = cleanMarkdownForTTS(text)
        
        // 分块处理
        chunks = splitTextIntoChunks(cleanText)
        totalChunks = chunks.count
        currentChunkIndex = 0
        
        isPlaying = true
        
        speakTask = Task {
            await speakChunks()
        }
    }
    
    /// 清理 Markdown 符号，使文本更适合 TTS 朗读
    private func cleanMarkdownForTTS(_ text: String) -> String {
        var result = text
        
        // 移除代码块
        result = result.replacingOccurrences(of: "```[^`]*```", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "`[^`]+`", with: "", options: .regularExpression)
        
        // 移除标题符号 # 
        result = result.replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n#{1,6}\\s*", with: "\n", options: .regularExpression)
        
        // 移除加粗/斜体 *、**、***、_、__
        result = result.replacingOccurrences(of: "\\*{1,3}([^*]+)\\*{1,3}", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_{1,2}([^_]+)_{1,2}", with: "$1", options: .regularExpression)
        
        // 移除链接 [text](url) -> text
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        
        // 移除图片 ![alt](url)
        result = result.replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]+\\)", with: "", options: .regularExpression)
        
        // 移除列表符号 - 、* 、+ 、数字.
        result = result.replacingOccurrences(of: "^[\\-\\*\\+]\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n[\\-\\*\\+]\\s+", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "^\\d+\\.\\s+", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n\\d+\\.\\s+", with: "\n", options: .regularExpression)
        
        // 移除引用符号 >
        result = result.replacingOccurrences(of: "^>\\s*", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "\n>\\s*", with: "\n", options: .regularExpression)
        
        // 移除分隔线 ---、***、___
        result = result.replacingOccurrences(of: "^[\\-\\*_]{3,}$", with: "", options: .regularExpression)
        
        // 清理多余空行
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 停止朗读
    func stop() {
        speakTask?.cancel()
        speakTask = nil
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        Task { await edgeClient.cancel() }
        chunks = []
        isPlaying = false
        isSynthesizing = false
        currentChunkIndex = 0
        totalChunks = 0
    }
    
    // MARK: - Chunk Processing
    
    /// 将文本分割成块（按句子分割）
    private func splitTextIntoChunks(_ text: String) -> [String] {
        let chunkSize = settings.chunkSize
        
        // 如果 chunkSize 为 0 或文本较短，不分块
        if chunkSize == 0 || text.count <= chunkSize {
            return [text]
        }
        
        var chunks: [String] = []
        var currentChunk = ""
        
        // 按句子分割符分割
        let sentenceDelimiters = CharacterSet(charactersIn: "。！？.!?\n")
        let sentences = text.components(separatedBy: sentenceDelimiters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for sentence in sentences {
            // 找回分隔符
            let range = text.range(of: sentence)
            var fullSentence = sentence
            if let range = range {
                let endIndex = range.upperBound
                if endIndex < text.endIndex {
                    let delimiter = text[endIndex]
                    if sentenceDelimiters.contains(delimiter.unicodeScalars.first!) {
                        fullSentence += String(delimiter)
                    }
                }
            }
            
            // 如果当前块加上新句子超过限制，保存当前块
            if currentChunk.count + fullSentence.count > chunkSize && !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = fullSentence
            } else {
                currentChunk += fullSentence
            }
        }
        
        // 保存最后一块
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks.isEmpty ? [text] : chunks
    }
    
    /// 逐块朗读
    private func speakChunks() async {
        for (index, chunk) in chunks.enumerated() {
            guard !Task.isCancelled else { break }
            
            currentChunkIndex = index
            
            switch settings.provider {
            case .system:
                await speakChunkWithSystem(chunk)
            case .edge:
                await speakChunkWithEdge(chunk)
            }
            
            guard !Task.isCancelled else { break }
        }
        
        isPlaying = false
        isSynthesizing = false
    }
    
    // MARK: - System TTS
    
    private func speakChunkWithSystem(_ text: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: settings.systemVoice)
        utterance.rate = settings.systemRate
        
        await withCheckedContinuation { continuation in
            systemContinuation = continuation
            synthesizer.speak(utterance)
        }
    }
    
    private var systemContinuation: CheckedContinuation<Void, Never>?
    
    // MARK: - Edge TTS
    
    private func speakChunkWithEdge(_ text: String) async {
        isSynthesizing = true
        
        do {
            let audioData = try await edgeClient.synthesize(
                text: text,
                voice: settings.edgeVoice,
                rate: settings.edgeRate,
                pitch: settings.edgePitch
            )
            
            isSynthesizing = false
            
            // 播放音频
            await playAudio(data: audioData)
            
        } catch {
            self.error = error.localizedDescription
            print("❌ EdgeTTS Error: \(error)")
            isSynthesizing = false
        }
    }
    
    /// 播放音频数据
    private func playAudio(data: Data) async {
        do {
            // 保存到临时文件（AVAudioPlayer 对带 header 的数据解析更可靠）
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("edge_tts_\(UUID().uuidString).mp3")
            try data.write(to: tempURL)
            
            audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            // 等待播放完成
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                audioContinuation = continuation
            }
            
            // 清理临时文件
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            print("❌ Audio playback error: \(error)")
        }
    }
    
    private var audioContinuation: CheckedContinuation<Void, Never>?
}

// MARK: - AVSpeechSynthesizerDelegate

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            systemContinuation?.resume()
            systemContinuation = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            systemContinuation?.resume()
            systemContinuation = nil
            isPlaying = false
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension TTSService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            audioContinuation?.resume()
            audioContinuation = nil
        }
    }
}

// MARK: - Legacy Alias (兼容旧代码)

typealias EdgeTTSService = TTSService
