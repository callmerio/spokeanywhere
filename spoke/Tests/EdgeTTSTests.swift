import Foundation
import AVFoundation

// MARK: - Edge TTS 单元测试

@main
struct EdgeTTSTests {
    static func main() async {
        print("🧪 Edge TTS 单元测试")
        print("=" * 50)
        
        await testSynthesizeAndPlay()
    }
    
    /// 测试合成并播放
    static func testSynthesizeAndPlay() async {
        print("\n📝 测试: 合成并播放")
        
        let text = "你好，这是语音合成测试。"
        let voice = "zh-CN-XiaoxiaoNeural"
        
        do {
            // 1. 合成音频
            print("   正在合成...")
            let audioData = try await synthesize(text: text, voice: voice)
            print("   ✅ 合成完成: \(audioData.count) bytes")
            
            // 2. 检查音频头
            print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
            
            // 3. 保存到文件测试
            let tempPath = "/tmp/edge_tts_test.mp3"
            try audioData.write(to: URL(fileURLWithPath: tempPath))
            print("   ✅ 已保存到: \(tempPath)")
            
            // 4. 用 AVAudioPlayer 播放
            print("   正在播放...")
            let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
            player.prepareToPlay()
            player.play()
            
            // 等待播放完成
            while player.isPlaying {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            print("   ✅ 播放完成!")
            
        } catch {
            print("   ❌ 错误: \(error)")
        }
    }
    
    /// 合成音频
    static func synthesize(text: String, voice: String) async throws -> Data {
        // DRM Token
        let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
        let chromiumVersion = "130.0.2849.68"
        let windowsFileTimeEpoch: Int64 = 11_644_473_600
        
        let currentTime = Int64(Date().timeIntervalSince1970)
        let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
        let roundedTicks = ticks - (ticks % 3_000_000_000)
        let strToHash = "\(roundedTicks)\(trustedClientToken)"
        
        // SHA256
        import CryptoKit
        let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
        let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
        
        // URL
        let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
        let url = URL(string: urlString)!
        
        // WebSocket
        var request = URLRequest(url: url)
        request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
        
        let session = URLSession.shared
        let ws = session.webSocketTask(with: request)
        ws.resume()
        
        // 等待连接
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // 发送配置
        let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
        try await ws.send(.string(configMessage))
        
        // 发送 SSML
        let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
        let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
        try await ws.send(.string(ssmlMessage))
        
        // 接收音频
        var audioData = Data()
        
        while true {
            let message = try await ws.receive()
            
            switch message {
            case .data(let data):
                // 检查是否包含 Path:audio
                if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
                    if let range = str.range(of: "Path:audio\r\n") {
                        let offset = range.upperBound.utf16Offset(in: str)
                        audioData.append(data[offset...])
                    }
                } else {
                    audioData.append(data)
                }
                
            case .string(let str):
                if str.contains("Path:turn.end") {
                    ws.cancel(with: .goingAway, reason: nil)
                    return audioData
                }
                
            @unknown default:
                break
            }
        }
    }
}

extension String {
    static func * (string: String, count: Int) -> String {
        String(repeating: string, count: count)
    }
}
