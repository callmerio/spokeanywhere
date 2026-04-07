#!/usr/bin/env swift

import AVFoundation
import CryptoKit
import Foundation

// MARK: - Edge TTS 测试脚本

print("🧪 Edge TTS 测试")
print(String(repeating: "=", count: 50))

// 配置
let text = "你好，这是语音合成测试。Hello, this is a test."
let voice = "zh-CN-XiaoxiaoNeural"
let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
let chromiumVersion = "130.0.2849.68"
let windowsFileTimeEpoch: Int64 = 11_644_473_600

// 生成 DRM Token
func generateSecMsGecToken() -> String {
    let currentTime = Int64(Date().timeIntervalSince1970)
    let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
    let roundedTicks = ticks - (ticks % 3_000_000_000)
    let strToHash = "\(roundedTicks)\(trustedClientToken)"
    let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
    return hash.map { String(format: "%02X", $0) }.joined()
}

// WebSocket Delegate
class WSDelegate: NSObject, URLSessionWebSocketDelegate {
    var onOpen: (() -> Void)?
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("   ✅ WebSocket 已连接")
        onOpen?()
    }
}

// 主测试
func runTest() async {
    print("\n📝 测试文本: \(text)")
    print("🎤 语音: \(voice)")
    
    // 构建 URL
    let secMsGec = generateSecMsGecToken()
    let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
    
    guard let url = URL(string: urlString) else {
        print("❌ URL 无效")
        return
    }
    
    // 创建 WebSocket
    print("\n🔗 正在连接...")
    var request = URLRequest(url: url)
    request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
    request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
    
    let delegate = WSDelegate()
    let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    let ws = session.webSocketTask(with: request)
    
    // 等待连接
    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
        delegate.onOpen = { cont.resume() }
        ws.resume()
    }
    
    // 发送配置
    print("📤 发送配置...")
    let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
    do {
        try await ws.send(.string(configMessage))
        print("   ✅ 配置已发送")
    } catch {
        print("   ❌ 发送配置失败: \(error)")
        return
    }
    
    // 发送 SSML
    print("📤 发送 SSML...")
    let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
    let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
    do {
        try await ws.send(.string(ssmlMessage))
        print("   ✅ SSML 已发送")
    } catch {
        print("   ❌ 发送 SSML 失败: \(error)")
        return
    }
    
    // 接收音频
    print("\n📥 接收音频数据...")
    var audioData = Data()
    var messageCount = 0
    
    while true {
        do {
            let message = try await ws.receive()
            messageCount += 1
            
            switch message {
            case .data(let data):
                // 尝试解析为字符串查看内容
                if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
                    // 找到音频分隔符后的数据
                    if let range = str.range(of: "Path:audio\r\n") {
                        let offset = range.upperBound.utf16Offset(in: str)
                        let audioChunk = data.suffix(from: offset)
                        audioData.append(audioChunk)
                        print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
                    }
                } else {
                    // 纯二进制音频
                    audioData.append(data)
                    print("   收到音频块 #\(messageCount): \(data.count) bytes")
                }
                
            case .string(let str):
                if str.contains("Path:turn.end") {
                    print("   ✅ 收到结束信号")
                    break
                } else if str.contains("Path:audio.metadata") {
                    print("   收到元数据")
                } else {
                    print("   收到文本: \(str.prefix(50))...")
                }
                continue
                
            @unknown default:
                continue
            }
            
            if messageCount > 100 { break } // 防止死循环
            
        } catch {
            print("   ⚠️ 接收错误: \(error)")
            break
        }
    }
    
    ws.cancel(with: .goingAway, reason: nil)
    
    print("\n📊 结果:")
    print("   总消息数: \(messageCount)")
    print("   音频大小: \(audioData.count) bytes")
    
    if audioData.isEmpty {
        print("   ❌ 没有收到音频数据")
        return
    }
    
    // 检查音频头
    let header = audioData.prefix(16)
    print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
    
    // MP3 文件应该以 FF FB 或 ID3 开头
    if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
        print("   ✅ 看起来是有效的 MP3 格式")
    } else {
        print("   ⚠️ 可能不是标准 MP3 格式")
    }
    
    // 保存到文件
    let tempPath = "/tmp/edge_tts_test.mp3"
    do {
        try audioData.write(to: URL(fileURLWithPath: tempPath))
        print("\n💾 已保存到: \(tempPath)")
    } catch {
        print("   ❌ 保存失败: \(error)")
        return
    }
    
    // 播放测试
    print("\n🔊 播放测试...")
    do {
        let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
        player.prepareToPlay()
        
        if player.play() {
            print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
            
            // 等待播放完成
            while player.isPlaying {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            print("   ✅ 播放完成!")
        } else {
            print("   ❌ 播放启动失败")
        }
    } catch {
        print("   ❌ 播放错误: \(error)")
        
        // 尝试用 afplay 播放
        print("\n🔧 尝试用 afplay 播放...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
        process.arguments = [tempPath]
        try? process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            print("   ✅ afplay 播放成功!")
        } else {
            print("   ❌ afplay 也失败了")
        }
    }
}

// 运行测试
Task {
    await runTest()
    exit(0)
}

// 保持运行
RunLoop.main.run()
