Project Path: spoke

Source Tree:

```txt
spoke
└── docs
    └── code2prompt-output
        ├── lucid-config.md
        ├── lucid-docs.md
        ├── lucid-full.md
        └── lucid-source.md

```

`spoke/docs/code2prompt-output/lucid-config.md`:

```md
Project Path: spoke

Source Tree:

```txt
spoke
└── Package.swift

```

`spoke/Package.swift`:

```swift
   1 | // swift-tools-version: 5.9
   2 | import PackageDescription
   3 | 
   4 | let package = Package(
   5 |     name: "SpokenAnyWhere",
   6 |     platforms: [
   7 |         .macOS(.v14)
   8 |     ],
   9 |     products: [
  10 |         .executable(name: "SpokenAnyWhere", targets: ["SpokenAnyWhere"])
  11 |     ],
  12 |     dependencies: [],
  13 |     targets: [
  14 |         .executableTarget(
  15 |             name: "SpokenAnyWhere",
  16 |             dependencies: [],
  17 |             path: ".",
  18 |             exclude: ["Package.swift", "Resources/LocalModels", "Tests"],
  19 |             sources: ["App", "Core", "Services", "UI"]
  20 |         )
  21 |     ]
  22 | )

```
```

`spoke/docs/code2prompt-output/lucid-docs.md`:

```md
Project Path: spoke

Source Tree:

```txt
spoke
└── docs
    └── code2prompt-output
        ├── lucid-config.md
        ├── lucid-full.md
        └── lucid-source.md

```

`spoke/docs/code2prompt-output/lucid-config.md`:

```md
Project Path: spoke

Source Tree:

```txt
spoke
└── Package.swift

```

`spoke/Package.swift`:

```swift
   1 | // swift-tools-version: 5.9
   2 | import PackageDescription
   3 | 
   4 | let package = Package(
   5 |     name: "SpokenAnyWhere",
   6 |     platforms: [
   7 |         .macOS(.v14)
   8 |     ],
   9 |     products: [
  10 |         .executable(name: "SpokenAnyWhere", targets: ["SpokenAnyWhere"])
  11 |     ],
  12 |     dependencies: [],
  13 |     targets: [
  14 |         .executableTarget(
  15 |             name: "SpokenAnyWhere",
  16 |             dependencies: [],
  17 |             path: ".",
  18 |             exclude: ["Package.swift", "Resources/LocalModels", "Tests"],
  19 |             sources: ["App", "Core", "Services", "UI"]
  20 |         )
  21 |     ]
  22 | )

```
```

`spoke/docs/code2prompt-output/lucid-full.md`:

```md
Project Path: spoke

Source Tree:

```txt
spoke
├── App
│   ├── AppDelegate.swift
│   └── SpokenlyApp.swift
├── Core
│   ├── Attachment
│   │   ├── Attachment.swift
│   │   ├── AttachmentManager.swift
│   │   ├── ScreenCaptureService.swift
│   │   └── TextExtractionService.swift
│   ├── Audio
│   │   └── AudioRecorderService.swift
│   ├── DataModels.swift
│   ├── LLM
│   │   ├── KeychainService.swift
│   │   ├── LLMPipeline.swift
│   │   ├── LLMProvider.swift
│   │   ├── LLMSettings.swift
│   │   └── OpenAICompatibleProvider.swift
│   ├── MessagePanel
│   │   └── MessagePanelState.swift
│   ├── QuickAsk
│   │   └── QuickAskState.swift
│   ├── RecordingState.swift
│   └── Transcription
│       ├── Providers
│       │   ├── SFSpeechProvider.swift
│       │   └── SpeechAnalyzerProvider.swift
│       ├── TranscriptionManager.swift
│       └── TranscriptionProvider.swift
├── Package.swift
├── Resources
│   └── LocalModels
├── Services
│   ├── AppSettings.swift
│   ├── AudioDeviceManager.swift
│   ├── AudioPlayerService.swift
│   ├── ClipboardHistoryService.swift
│   ├── ContextService.swift
│   ├── DoubaoTTSService.swift
│   ├── EdgeTTSService.swift
│   ├── FloatingHUDManager.swift
│   ├── HistoryManager.swift
│   ├── HotKeyService.swift
│   ├── InputService.swift
│   ├── MessagePanelManager.swift
│   ├── QuickAskService.swift
│   ├── RecordingController.swift
│   └── TTSSettings.swift
├── Tests
│   ├── AttachmentTests.swift
│   ├── EdgeTTSTests.swift
│   ├── TextExtractionTests.swift
│   ├── run-tests.sh
│   └── test_edge_tts.swift
├── UI
│   ├── Components
│   │   ├── AttachmentDropOverlay.swift
│   │   ├── AttachmentPickerMenu.swift
│   │   └── AttachmentThumbnailView.swift
│   ├── HUD
│   │   ├── FloatingCapsuleView.swift
│   │   ├── FloatingPanel.swift
│   │   ├── HUDTheme.swift
│   │   ├── QuickAskCapsuleView.swift
│   │   └── QuickAskInputView.swift
│   ├── MessagePanel
│   │   └── MessagePanelView.swift
│   ├── QuickAsk
│   │   ├── AnswerPanelView.swift
│   │   └── MarkdownWebView.swift
│   └── Settings
│       └── SettingsView.swift
└── docs
    └── code2prompt-output

```

`spoke/Tests/AttachmentTests.swift`:

```swift
   1 | import Foundation
   2 | import AppKit
   3 | 
   4 | // MARK: - Attachment Tests
   5 | 
   6 | /// Attachment 类型单元测试
   7 | /// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
   8 | @main
   9 | struct AttachmentTests {
  10 |     
  11 |     static var passCount = 0
  12 |     static var failCount = 0
  13 |     
  14 |     static func main() async {
  15 |         print("🧪 Attachment 类型单元测试")
  16 |         print("=" * 50)
  17 |         
  18 |         // 运行测试
  19 |         runTest("Image 类型属性") { try testImageAttachment() }
  20 |         runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
  21 |         runTest("File 类型属性") { try testFileAttachment() }
  22 |         runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
  23 |         runTest("视频文件检测") { try testVideoDetection() }
  24 |         runTest("ID 相等性判断") { try testEqualityById() }
  25 |         runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
  26 |         runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
  27 |         runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
  28 |         runTest("缩略图处理空图") { try testThumbnailZeroSize() }
  29 |         
  30 |         print("\n" + "=" * 50)
  31 |         print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  32 |     }
  33 |     
  34 |     // MARK: - Test Runner
  35 |     
  36 |     static func runTest(_ name: String, _ test: () throws -> Void) {
  37 |         print("\n📝 测试: \(name)")
  38 |         do {
  39 |             try test()
  40 |             print("   ✅ 通过")
  41 |             passCount += 1
  42 |         } catch {
  43 |             print("   ❌ 失败: \(error)")
  44 |             failCount += 1
  45 |         }
  46 |     }
  47 |     
  48 |     // MARK: - Test Cases: Attachment Types
  49 |     
  50 |     static func testImageAttachment() throws {
  51 |         let image = NSImage(size: NSSize(width: 100, height: 100))
  52 |         let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
  53 |         let id = UUID()
  54 |         
  55 |         let attachment = Attachment.image(image, thumbnail, id)
  56 |         
  57 |         try assertEqual(attachment.id, id, "ID")
  58 |         try assertEqual(attachment.displayTitle, "图片", "displayTitle")
  59 |         try assertNotNil(attachment.thumbnail, "thumbnail")
  60 |         try assertNotNil(attachment.originalImage, "originalImage")
  61 |         try assertFalse(attachment.isVideo, "isVideo")
  62 |         try assertFalse(attachment.isTextBundle, "isTextBundle")
  63 |         try assertNil(attachment.textContent, "textContent")
  64 |     }
  65 |     
  66 |     static func testScreenshotAttachment() throws {
  67 |         let image = NSImage(size: NSSize(width: 1920, height: 1080))
  68 |         let id = UUID()
  69 |         
  70 |         let attachment = Attachment.screenshot(image, nil, id)
  71 |         
  72 |         try assertEqual(attachment.id, id, "ID")
  73 |         try assertEqual(attachment.displayTitle, "截图", "displayTitle")
  74 |         try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
  75 |         try assertNotNil(attachment.originalImage, "originalImage")
  76 |     }
  77 |     
  78 |     static func testFileAttachment() throws {
  79 |         let url = URL(fileURLWithPath: "/tmp/test.pdf")
  80 |         let id = UUID()
  81 |         
  82 |         let attachment = Attachment.file(url, id)
  83 |         
  84 |         try assertEqual(attachment.id, id, "ID")
  85 |         try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
  86 |         try assertEqual(attachment.fileName, "test.pdf", "fileName")
  87 |         try assertNil(attachment.thumbnail, "thumbnail")
  88 |         try assertNil(attachment.originalImage, "originalImage")
  89 |     }
  90 |     
  91 |     static func testTextBundleAttachment() throws {
  92 |         let content = "# Code content\nlet x = 1"
  93 |         let source = "my-project"
  94 |         let count = 42
  95 |         let id = UUID()
  96 |         
  97 |         let attachment = Attachment.textBundle(content, source, count, id)
  98 |         
  99 |         try assertEqual(attachment.id, id, "ID")
 100 |         try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
 101 |         try assertEqual(attachment.fileName, source, "fileName")
 102 |         try assertTrue(attachment.isTextBundle, "isTextBundle")
 103 |         try assertEqual(attachment.textContent, content, "textContent")
 104 |     }
 105 |     
 106 |     static func testVideoDetection() throws {
 107 |         let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
 108 |         let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
 109 |         let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
 110 |         
 111 |         try assertTrue(mp4.isVideo, "mp4 should be video")
 112 |         try assertTrue(mov.isVideo, "mov should be video")
 113 |         try assertFalse(txt.isVideo, "txt should not be video")
 114 |     }
 115 |     
 116 |     static func testEqualityById() throws {
 117 |         let id = UUID()
 118 |         let image1 = NSImage(size: NSSize(width: 100, height: 100))
 119 |         let image2 = NSImage(size: NSSize(width: 200, height: 200))
 120 |         
 121 |         let att1 = Attachment.image(image1, nil, id)
 122 |         let att2 = Attachment.image(image2, nil, id)
 123 |         let att3 = Attachment.image(image1, nil, UUID())
 124 |         
 125 |         try assertTrue(att1 == att2, "Same ID should be equal")
 126 |         try assertFalse(att1 == att3, "Different ID should not be equal")
 127 |     }
 128 |     
 129 |     // MARK: - Test Cases: Thumbnail Generation
 130 |     
 131 |     static func testThumbnailResizesLarge() throws {
 132 |         let large = createTestImage(width: 2000, height: 1000)
 133 |         let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
 134 |         
 135 |         try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
 136 |         try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
 137 |     }
 138 |     
 139 |     static func testThumbnailPreservesRatio() throws {
 140 |         let image = createTestImage(width: 2000, height: 1000)
 141 |         let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
 142 |         
 143 |         let ratio = thumb.size.width / thumb.size.height
 144 |         try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
 145 |     }
 146 |     
 147 |     static func testThumbnailNoUpscale() throws {
 148 |         let small = createTestImage(width: 50, height: 50)
 149 |         let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
 150 |         
 151 |         try assertEqual(thumb.size.width, 50, "Width")
 152 |         try assertEqual(thumb.size.height, 50, "Height")
 153 |     }
 154 |     
 155 |     static func testThumbnailZeroSize() throws {
 156 |         let zero = NSImage(size: NSSize(width: 0, height: 0))
 157 |         let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
 158 |         
 159 |         try assertEqual(thumb.size.width, 0, "Width")
 160 |     }
 161 |     
 162 |     // MARK: - Helpers
 163 |     
 164 |     static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
 165 |         let image = NSImage(size: NSSize(width: width, height: height))
 166 |         image.lockFocus()
 167 |         NSColor.red.setFill()
 168 |         NSRect(x: 0, y: 0, width: width, height: height).fill()
 169 |         image.unlockFocus()
 170 |         return image
 171 |     }
 172 | }
 173 | 
 174 | // MARK: - Attachment Type (简化版，用于测试)
 175 | 
 176 | import UniformTypeIdentifiers
 177 | 
 178 | enum Attachment: Identifiable, Equatable {
 179 |     case image(NSImage, NSImage?, UUID)
 180 |     case screenshot(NSImage, NSImage?, UUID)
 181 |     case file(URL, UUID)
 182 |     case textBundle(String, String, Int, UUID)
 183 |     
 184 |     var id: UUID {
 185 |         switch self {
 186 |         case .image(_, _, let id), .screenshot(_, _, let id),
 187 |              .file(_, let id), .textBundle(_, _, _, let id):
 188 |             return id
 189 |         }
 190 |     }
 191 |     
 192 |     var thumbnail: NSImage? {
 193 |         switch self {
 194 |         case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
 195 |         default: return nil
 196 |         }
 197 |     }
 198 |     
 199 |     var originalImage: NSImage? {
 200 |         switch self {
 201 |         case .image(let img, _, _), .screenshot(let img, _, _): return img
 202 |         default: return nil
 203 |         }
 204 |     }
 205 |     
 206 |     var fileName: String? {
 207 |         switch self {
 208 |         case .file(let url, _): return url.lastPathComponent
 209 |         case .textBundle(_, let source, _, _): return source
 210 |         default: return nil
 211 |         }
 212 |     }
 213 |     
 214 |     var displayTitle: String {
 215 |         switch self {
 216 |         case .image: return "图片"
 217 |         case .screenshot: return "截图"
 218 |         case .file(let url, _): return url.lastPathComponent
 219 |         case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
 220 |         }
 221 |     }
 222 |     
 223 |     var isVideo: Bool {
 224 |         if case .file(let url, _) = self,
 225 |            let uti = UTType(filenameExtension: url.pathExtension) {
 226 |             return uti.conforms(to: .movie) || uti.conforms(to: .video)
 227 |         }
 228 |         return false
 229 |     }
 230 |     
 231 |     var isTextBundle: Bool {
 232 |         if case .textBundle = self { return true }
 233 |         return false
 234 |     }
 235 |     
 236 |     var textContent: String? {
 237 |         if case .textBundle(let content, _, _, _) = self { return content }
 238 |         return nil
 239 |     }
 240 |     
 241 |     static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
 242 |     
 243 |     static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
 244 |         let size = image.size
 245 |         guard size.width > 0 && size.height > 0 else { return image }
 246 |         
 247 |         let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
 248 |         let newSize = NSSize(width: size.width * scale, height: size.height * scale)
 249 |         
 250 |         let thumbnail = NSImage(size: newSize)
 251 |         thumbnail.lockFocus()
 252 |         image.draw(in: NSRect(origin: .zero, size: newSize),
 253 |                    from: NSRect(origin: .zero, size: size),
 254 |                    operation: .copy, fraction: 1.0)
 255 |         thumbnail.unlockFocus()
 256 |         return thumbnail
 257 |     }
 258 | }
 259 | 
 260 | // MARK: - Assertion Helpers
 261 | 
 262 | struct TestError: Error, CustomStringConvertible {
 263 |     let message: String
 264 |     init(_ message: String) { self.message = message }
 265 |     var description: String { message }
 266 | }
 267 | 
 268 | func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
 269 |     if actual != expected {
 270 |         throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
 271 |     }
 272 | }
 273 | 
 274 | func assertTrue(_ condition: Bool, _ message: String) throws {
 275 |     if !condition { throw TestError(message) }
 276 | }
 277 | 
 278 | func assertFalse(_ condition: Bool, _ message: String) throws {
 279 |     if condition { throw TestError(message) }
 280 | }
 281 | 
 282 | func assertNil<T>(_ value: T?, _ message: String) throws {
 283 |     if value != nil { throw TestError("\(message) 应该是 nil") }
 284 | }
 285 | 
 286 | func assertNotNil<T>(_ value: T?, _ message: String) throws {
 287 |     if value == nil { throw TestError("\(message) 不应该是 nil") }
 288 | }
 289 | 
 290 | extension String {
 291 |     static func * (string: String, count: Int) -> String {
 292 |         String(repeating: string, count: count)
 293 |     }
 294 | }

```

`spoke/Tests/EdgeTTSTests.swift`:

```swift
   1 | import Foundation
   2 | import AVFoundation
   3 | 
   4 | // MARK: - Edge TTS 单元测试
   5 | 
   6 | @main
   7 | struct EdgeTTSTests {
   8 |     static func main() async {
   9 |         print("🧪 Edge TTS 单元测试")
  10 |         print("=" * 50)
  11 |         
  12 |         await testSynthesizeAndPlay()
  13 |     }
  14 |     
  15 |     /// 测试合成并播放
  16 |     static func testSynthesizeAndPlay() async {
  17 |         print("\n📝 测试: 合成并播放")
  18 |         
  19 |         let text = "你好，这是语音合成测试。"
  20 |         let voice = "zh-CN-XiaoxiaoNeural"
  21 |         
  22 |         do {
  23 |             // 1. 合成音频
  24 |             print("   正在合成...")
  25 |             let audioData = try await synthesize(text: text, voice: voice)
  26 |             print("   ✅ 合成完成: \(audioData.count) bytes")
  27 |             
  28 |             // 2. 检查音频头
  29 |             print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
  30 |             
  31 |             // 3. 保存到文件测试
  32 |             let tempPath = "/tmp/edge_tts_test.mp3"
  33 |             try audioData.write(to: URL(fileURLWithPath: tempPath))
  34 |             print("   ✅ 已保存到: \(tempPath)")
  35 |             
  36 |             // 4. 用 AVAudioPlayer 播放
  37 |             print("   正在播放...")
  38 |             let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
  39 |             player.prepareToPlay()
  40 |             player.play()
  41 |             
  42 |             // 等待播放完成
  43 |             while player.isPlaying {
  44 |                 try await Task.sleep(nanoseconds: 100_000_000)
  45 |             }
  46 |             print("   ✅ 播放完成!")
  47 |             
  48 |         } catch {
  49 |             print("   ❌ 错误: \(error)")
  50 |         }
  51 |     }
  52 |     
  53 |     /// 合成音频
  54 |     static func synthesize(text: String, voice: String) async throws -> Data {
  55 |         // DRM Token
  56 |         let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
  57 |         let chromiumVersion = "130.0.2849.68"
  58 |         let windowsFileTimeEpoch: Int64 = 11_644_473_600
  59 |         
  60 |         let currentTime = Int64(Date().timeIntervalSince1970)
  61 |         let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
  62 |         let roundedTicks = ticks - (ticks % 3_000_000_000)
  63 |         let strToHash = "\(roundedTicks)\(trustedClientToken)"
  64 |         
  65 |         // SHA256
  66 |         import CryptoKit
  67 |         let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
  68 |         let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
  69 |         
  70 |         // URL
  71 |         let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
  72 |         let url = URL(string: urlString)!
  73 |         
  74 |         // WebSocket
  75 |         var request = URLRequest(url: url)
  76 |         request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
  77 |         request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
  78 |         
  79 |         let session = URLSession.shared
  80 |         let ws = session.webSocketTask(with: request)
  81 |         ws.resume()
  82 |         
  83 |         // 等待连接
  84 |         try await Task.sleep(nanoseconds: 500_000_000)
  85 |         
  86 |         // 发送配置
  87 |         let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
  88 |         try await ws.send(.string(configMessage))
  89 |         
  90 |         // 发送 SSML
  91 |         let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
  92 |         let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
  93 |         try await ws.send(.string(ssmlMessage))
  94 |         
  95 |         // 接收音频
  96 |         var audioData = Data()
  97 |         
  98 |         while true {
  99 |             let message = try await ws.receive()
 100 |             
 101 |             switch message {
 102 |             case .data(let data):
 103 |                 // 检查是否包含 Path:audio
 104 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 105 |                     if let range = str.range(of: "Path:audio\r\n") {
 106 |                         let offset = range.upperBound.utf16Offset(in: str)
 107 |                         audioData.append(data[offset...])
 108 |                     }
 109 |                 } else {
 110 |                     audioData.append(data)
 111 |                 }
 112 |                 
 113 |             case .string(let str):
 114 |                 if str.contains("Path:turn.end") {
 115 |                     ws.cancel(with: .goingAway, reason: nil)
 116 |                     return audioData
 117 |                 }
 118 |                 
 119 |             @unknown default:
 120 |                 break
 121 |             }
 122 |         }
 123 |     }
 124 | }
 125 | 
 126 | extension String {
 127 |     static func * (string: String, count: Int) -> String {
 128 |         String(repeating: string, count: count)
 129 |     }
 130 | }

```

`spoke/Tests/TextExtractionTests.swift`:

```swift
   1 | import Foundation
   2 | 
   3 | // MARK: - Text Extraction Service Tests
   4 | 
   5 | /// 独立运行的测试脚本
   6 | /// 用法: swift Tests/TextExtractionTests.swift
   7 | @main
   8 | struct TextExtractionTests {
   9 |     
  10 |     static var tempDirectory: URL!
  11 |     static var passCount = 0
  12 |     static var failCount = 0
  13 |     
  14 |     static func main() async {
  15 |         print("🧪 TextExtractionService 单元测试")
  16 |         print("=" * 50)
  17 |         
  18 |         // 创建临时目录
  19 |         tempDirectory = FileManager.default.temporaryDirectory
  20 |             .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
  21 |         try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  22 |         
  23 |         defer {
  24 |             // 清理
  25 |             try? FileManager.default.removeItem(at: tempDirectory)
  26 |             print("\n" + "=" * 50)
  27 |             print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  28 |         }
  29 |         
  30 |         // 运行测试
  31 |         await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
  32 |         await runTest("单文件提取") { try await testSingleFileExtraction() }
  33 |         await runTest("多文件合并") { try await testMultipleFilesExtraction() }
  34 |         await runTest("排除 node_modules") { try await testExcludesNodeModules() }
  35 |         await runTest("排除锁文件") { try await testExcludesLockFiles() }
  36 |         await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
  37 |         await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
  38 |         await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
  39 |         await runTest("添加行号") { try await testAddsLineNumbers() }
  40 |         await runTest("目录结构输出") { try await testDirectoryStructure() }
  41 |         await runTest("ZIP 提取") { try await testZIPExtraction() }
  42 |     }
  43 |     
  44 |     // MARK: - Test Runner
  45 |     
  46 |     static func runTest(_ name: String, _ test: () async throws -> Void) async {
  47 |         print("\n📝 测试: \(name)")
  48 |         do {
  49 |             try await test()
  50 |             print("   ✅ 通过")
  51 |             passCount += 1
  52 |         } catch {
  53 |             print("   ❌ 失败: \(error)")
  54 |             failCount += 1
  55 |         }
  56 |     }
  57 |     
  58 |     // MARK: - Helpers
  59 |     
  60 |     static func createFile(name: String, content: String) throws -> URL {
  61 |         let fileURL = tempDirectory.appendingPathComponent(name)
  62 |         let dir = fileURL.deletingLastPathComponent()
  63 |         try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  64 |         try content.write(to: fileURL, atomically: true, encoding: .utf8)
  65 |         return fileURL
  66 |     }
  67 |     
  68 |     static func createDirectory(name: String) throws -> URL {
  69 |         let dirURL = tempDirectory.appendingPathComponent(name)
  70 |         try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
  71 |         return dirURL
  72 |     }
  73 |     
  74 |     // MARK: - Test Cases
  75 |     
  76 |     static func testCodeExtensions() async throws {
  77 |         // 创建各种代码文件
  78 |         _ = try createFile(name: "test.swift", content: "let x = 1")
  79 |         _ = try createFile(name: "app.js", content: "const x = 1")
  80 |         _ = try createFile(name: "main.py", content: "x = 1")
  81 |         _ = try createFile(name: "README.md", content: "# Title")
  82 |         
  83 |         let result = await extractFromFolder(tempDirectory)
  84 |         guard case .success(let bundle) = result else {
  85 |             throw TestError("提取失败")
  86 |         }
  87 |         
  88 |         guard bundle.fileCount == 4 else {
  89 |             throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
  90 |         }
  91 |     }
  92 |     
  93 |     static func testSingleFileExtraction() async throws {
  94 |         // 清理并创建新目录
  95 |         try FileManager.default.removeItem(at: tempDirectory)
  96 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  97 |         
  98 |         _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
  99 |         
 100 |         let result = await extractFromFolder(tempDirectory)
 101 |         guard case .success(let bundle) = result else {
 102 |             throw TestError("提取失败")
 103 |         }
 104 |         
 105 |         guard bundle.fileCount == 1 else {
 106 |             throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
 107 |         }
 108 |         guard bundle.content.contains("print(\"Hello\")") else {
 109 |             throw TestError("内容不包含预期文本")
 110 |         }
 111 |     }
 112 |     
 113 |     static func testMultipleFilesExtraction() async throws {
 114 |         try FileManager.default.removeItem(at: tempDirectory)
 115 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 116 |         
 117 |         _ = try createFile(name: "a.swift", content: "let a = 1")
 118 |         _ = try createFile(name: "b.swift", content: "let b = 2")
 119 |         _ = try createFile(name: "c.js", content: "const c = 3")
 120 |         
 121 |         let result = await extractFromFolder(tempDirectory)
 122 |         guard case .success(let bundle) = result else {
 123 |             throw TestError("提取失败")
 124 |         }
 125 |         
 126 |         guard bundle.fileCount == 3 else {
 127 |             throw TestError("文件数量错误")
 128 |         }
 129 |         guard bundle.content.contains("let a = 1") &&
 130 |               bundle.content.contains("let b = 2") &&
 131 |               bundle.content.contains("const c = 3") else {
 132 |             throw TestError("内容缺失")
 133 |         }
 134 |     }
 135 |     
 136 |     static func testExcludesNodeModules() async throws {
 137 |         try FileManager.default.removeItem(at: tempDirectory)
 138 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 139 |         
 140 |         let nodeModules = try createDirectory(name: "node_modules")
 141 |         try "const secret = 'password'".write(
 142 |             to: nodeModules.appendingPathComponent("secret.js"),
 143 |             atomically: true, encoding: .utf8
 144 |         )
 145 |         _ = try createFile(name: "app.js", content: "const app = 1")
 146 |         
 147 |         let result = await extractFromFolder(tempDirectory)
 148 |         guard case .success(let bundle) = result else {
 149 |             throw TestError("提取失败")
 150 |         }
 151 |         
 152 |         guard bundle.fileCount == 1 else {
 153 |             throw TestError("应该只包含 app.js")
 154 |         }
 155 |         guard !bundle.content.contains("secret") else {
 156 |             throw TestError("不应包含 node_modules 内容")
 157 |         }
 158 |     }
 159 |     
 160 |     static func testExcludesLockFiles() async throws {
 161 |         try FileManager.default.removeItem(at: tempDirectory)
 162 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 163 |         
 164 |         _ = try createFile(name: "package-lock.json", content: "{}")
 165 |         _ = try createFile(name: "yarn.lock", content: "")
 166 |         _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
 167 |         
 168 |         let result = await extractFromFolder(tempDirectory)
 169 |         guard case .success(let bundle) = result else {
 170 |             throw TestError("提取失败")
 171 |         }
 172 |         
 173 |         guard bundle.fileCount == 1 else {
 174 |             throw TestError("应该只包含 package.json")
 175 |         }
 176 |     }
 177 |     
 178 |     static func testNestedDirectories() async throws {
 179 |         try FileManager.default.removeItem(at: tempDirectory)
 180 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 181 |         
 182 |         _ = try createFile(name: "root.swift", content: "let root = 1")
 183 |         _ = try createFile(name: "src/app.swift", content: "let src = 2")
 184 |         _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
 185 |         
 186 |         let result = await extractFromFolder(tempDirectory)
 187 |         guard case .success(let bundle) = result else {
 188 |             throw TestError("提取失败")
 189 |         }
 190 |         
 191 |         guard bundle.fileCount == 3 else {
 192 |             throw TestError("应该包含 3 个文件")
 193 |         }
 194 |         guard bundle.content.contains("let root = 1") &&
 195 |               bundle.content.contains("let src = 2") &&
 196 |               bundle.content.contains("let lib = 3") else {
 197 |             throw TestError("缺少嵌套目录内容")
 198 |         }
 199 |     }
 200 |     
 201 |     static func testEmptyFolderError() async throws {
 202 |         try FileManager.default.removeItem(at: tempDirectory)
 203 |         let emptyDir = try createDirectory(name: "empty")
 204 |         
 205 |         let result = await extractFromFolder(emptyDir)
 206 |         guard case .failure = result else {
 207 |             throw TestError("空文件夹应该返回错误")
 208 |         }
 209 |     }
 210 |     
 211 |     static func testIgnoresNonCodeFiles() async throws {
 212 |         try FileManager.default.removeItem(at: tempDirectory)
 213 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 214 |         
 215 |         _ = try createFile(name: "image.png", content: "fake")
 216 |         _ = try createFile(name: "video.mp4", content: "fake")
 217 |         _ = try createFile(name: "main.swift", content: "let x = 1")
 218 |         
 219 |         let result = await extractFromFolder(tempDirectory)
 220 |         guard case .success(let bundle) = result else {
 221 |             throw TestError("提取失败")
 222 |         }
 223 |         
 224 |         guard bundle.fileCount == 1 else {
 225 |             throw TestError("应该只包含 .swift 文件")
 226 |         }
 227 |     }
 228 |     
 229 |     static func testAddsLineNumbers() async throws {
 230 |         try FileManager.default.removeItem(at: tempDirectory)
 231 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 232 |         
 233 |         _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
 234 |         
 235 |         let result = await extractFromFolder(tempDirectory)
 236 |         guard case .success(let bundle) = result else {
 237 |             throw TestError("提取失败")
 238 |         }
 239 |         
 240 |         guard bundle.content.contains("1│") &&
 241 |               bundle.content.contains("2│") &&
 242 |               bundle.content.contains("3│") else {
 243 |             throw TestError("缺少行号")
 244 |         }
 245 |     }
 246 |     
 247 |     static func testDirectoryStructure() async throws {
 248 |         try FileManager.default.removeItem(at: tempDirectory)
 249 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 250 |         
 251 |         _ = try createFile(name: "main.swift", content: "entry")
 252 |         _ = try createFile(name: "src/app.swift", content: "code")
 253 |         
 254 |         let result = await extractFromFolder(tempDirectory)
 255 |         guard case .success(let bundle) = result else {
 256 |             throw TestError("提取失败")
 257 |         }
 258 |         
 259 |         guard bundle.content.contains("# 目录结构") else {
 260 |             throw TestError("缺少目录结构标题")
 261 |         }
 262 |     }
 263 |     
 264 |     static func testZIPExtraction() async throws {
 265 |         try FileManager.default.removeItem(at: tempDirectory)
 266 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 267 |         
 268 |         // 创建源文件
 269 |         let sourceDir = try createDirectory(name: "source")
 270 |         try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
 271 |         
 272 |         // 创建 ZIP
 273 |         let zipPath = tempDirectory.appendingPathComponent("test.zip")
 274 |         let process = Process()
 275 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
 276 |         process.currentDirectoryURL = tempDirectory
 277 |         process.arguments = ["-r", zipPath.path, "source"]
 278 |         process.standardOutput = FileHandle.nullDevice
 279 |         process.standardError = FileHandle.nullDevice
 280 |         try process.run()
 281 |         process.waitUntilExit()
 282 |         
 283 |         guard process.terminationStatus == 0 else {
 284 |             throw TestError("创建 ZIP 失败")
 285 |         }
 286 |         
 287 |         let result = await extractFromZIP(zipPath)
 288 |         guard case .success(let bundle) = result else {
 289 |             throw TestError("ZIP 提取失败")
 290 |         }
 291 |         
 292 |         guard bundle.fileCount == 1 else {
 293 |             throw TestError("ZIP 文件数量错误")
 294 |         }
 295 |         guard bundle.content.contains("let x = 1") else {
 296 |             throw TestError("ZIP 内容缺失")
 297 |         }
 298 |     }
 299 | }
 300 | 
 301 | // MARK: - TextExtractionService (简化版，用于测试)
 302 | 
 303 | struct TextBundle {
 304 |     let content: String
 305 |     let fileCount: Int
 306 |     let sourcePath: String
 307 |     let files: [String]
 308 | }
 309 | 
 310 | enum TextExtractionError: Error, Equatable {
 311 |     case folderNotFound
 312 |     case zipExtractionFailed(String)
 313 |     case noTextFilesFound
 314 |     case accessDenied
 315 | }
 316 | 
 317 | func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
 318 |     let codeExtensions: Set<String> = [
 319 |         "js", "jsx", "ts", "tsx", "mjs", "cjs",
 320 |         "html", "htm", "css", "scss", "less", "vue", "svelte",
 321 |         "py", "pyw", "pyi",
 322 |         "java", "kt", "kts", "scala",
 323 |         "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
 324 |         "rs", "go", "rb", "erb", "php", "swift",
 325 |         "sh", "bash", "zsh", "fish",
 326 |         "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
 327 |         "md", "mdx", "txt", "rst", "asciidoc",
 328 |         "sql", "graphql", "proto", "dockerfile"
 329 |     ]
 330 |     
 331 |     let excludedDirs: Set<String> = [
 332 |         "node_modules", ".git", ".svn", ".hg",
 333 |         "dist", "build", "target", ".next", ".nuxt",
 334 |         "__pycache__", ".pytest_cache", ".tox",
 335 |         "venv", "env", ".env", ".venv",
 336 |         "vendor", "Pods", "Carthage",
 337 |         ".idea", ".vscode", ".vs"
 338 |     ]
 339 |     
 340 |     let excludedFiles: Set<String> = [
 341 |         ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
 342 |         "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
 343 |         "Podfile.lock", "Gemfile.lock", "Cargo.lock"
 344 |     ]
 345 |     
 346 |     // 递归收集文件
 347 |     func collectFiles(in directory: URL) -> [URL] {
 348 |         var result: [URL] = []
 349 |         let fm = FileManager.default
 350 |         
 351 |         guard let contents = try? fm.contentsOfDirectory(
 352 |             at: directory,
 353 |             includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
 354 |             options: [.skipsHiddenFiles]
 355 |         ) else { return [] }
 356 |         
 357 |         for url in contents {
 358 |             let fileName = url.lastPathComponent
 359 |             if excludedFiles.contains(fileName) { continue }
 360 |             
 361 |             let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
 362 |             
 363 |             if values?.isDirectory == true {
 364 |                 if !excludedDirs.contains(fileName) {
 365 |                     result.append(contentsOf: collectFiles(in: url))
 366 |                 }
 367 |             } else if values?.isRegularFile == true {
 368 |                 let ext = url.pathExtension.lowercased()
 369 |                 if codeExtensions.contains(ext) {
 370 |                     result.append(url)
 371 |                 }
 372 |             }
 373 |         }
 374 |         return result.sorted { $0.path < $1.path }
 375 |     }
 376 |     
 377 |     let files = collectFiles(in: folderURL)
 378 |     guard !files.isEmpty else {
 379 |         return .failure(.noTextFilesFound)
 380 |     }
 381 |     
 382 |     // 合并内容
 383 |     var parts: [String] = ["# 目录结构\n```"]
 384 |     for file in files {
 385 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 386 |         parts.append(rel)
 387 |     }
 388 |     parts.append("```\n\n# 文件内容\n")
 389 |     
 390 |     for file in files {
 391 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 392 |         let ext = file.pathExtension
 393 |         if let content = try? String(contentsOf: file, encoding: .utf8) {
 394 |             let numbered = content.components(separatedBy: .newlines).enumerated()
 395 |                 .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
 396 |             parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
 397 |         }
 398 |     }
 399 |     
 400 |     return .success(TextBundle(
 401 |         content: parts.joined(separator: "\n"),
 402 |         fileCount: files.count,
 403 |         sourcePath: folderURL.path,
 404 |         files: files.map { $0.path }
 405 |     ))
 406 | }
 407 | 
 408 | func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
 409 |     let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
 410 |     try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
 411 |     defer { try? FileManager.default.removeItem(at: tempDir) }
 412 |     
 413 |     let process = Process()
 414 |     process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
 415 |     process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
 416 |     process.standardOutput = FileHandle.nullDevice
 417 |     process.standardError = FileHandle.nullDevice
 418 |     
 419 |     do {
 420 |         try process.run()
 421 |         process.waitUntilExit()
 422 |         
 423 |         guard process.terminationStatus == 0 else {
 424 |             return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
 425 |         }
 426 |         
 427 |         return await extractFromFolder(tempDir)
 428 |     } catch {
 429 |         return .failure(.zipExtractionFailed(error.localizedDescription))
 430 |     }
 431 | }
 432 | 
 433 | // MARK: - Helpers
 434 | 
 435 | struct TestError: Error, CustomStringConvertible {
 436 |     let message: String
 437 |     init(_ message: String) { self.message = message }
 438 |     var description: String { message }
 439 | }
 440 | 
 441 | extension String {
 442 |     static func * (string: String, count: Int) -> String {
 443 |         String(repeating: string, count: count)
 444 |     }
 445 | }

```

`spoke/Tests/run-tests.sh`:

```sh
   1 | #!/bin/bash
   2 | # 运行所有单元测试
   3 | # 用法: ./Tests/run-tests.sh
   4 | 
   5 | set -e
   6 | 
   7 | cd "$(dirname "$0")/.."
   8 | 
   9 | echo "🧪 运行所有单元测试"
  10 | echo "=================================="
  11 | 
  12 | # 编译并运行 TextExtractionTests
  13 | echo ""
  14 | echo "📦 编译 TextExtractionTests..."
  15 | swiftc -parse-as-library -o /tmp/text_extraction_tests Tests/TextExtractionTests.swift
  16 | echo "🚀 运行测试..."
  17 | /tmp/text_extraction_tests
  18 | 
  19 | echo ""
  20 | echo "=================================="
  21 | 
  22 | # 编译并运行 AttachmentTests
  23 | echo ""
  24 | echo "📦 编译 AttachmentTests..."
  25 | swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift
  26 | echo "🚀 运行测试..."
  27 | /tmp/attachment_tests
  28 | 
  29 | echo ""
  30 | echo "=================================="
  31 | echo "🎉 所有测试完成!"

```

`spoke/Tests/test_edge_tts.swift`:

```swift
   1 | #!/usr/bin/env swift
   2 | 
   3 | import Foundation
   4 | import CryptoKit
   5 | import AVFoundation
   6 | 
   7 | // MARK: - Edge TTS 测试脚本
   8 | 
   9 | print("🧪 Edge TTS 测试")
  10 | print(String(repeating: "=", count: 50))
  11 | 
  12 | // 配置
  13 | let text = "你好，这是语音合成测试。Hello, this is a test."
  14 | let voice = "zh-CN-XiaoxiaoNeural"
  15 | let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
  16 | let chromiumVersion = "130.0.2849.68"
  17 | let windowsFileTimeEpoch: Int64 = 11_644_473_600
  18 | 
  19 | // 生成 DRM Token
  20 | func generateSecMsGecToken() -> String {
  21 |     let currentTime = Int64(Date().timeIntervalSince1970)
  22 |     let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
  23 |     let roundedTicks = ticks - (ticks % 3_000_000_000)
  24 |     let strToHash = "\(roundedTicks)\(trustedClientToken)"
  25 |     let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
  26 |     return hash.map { String(format: "%02X", $0) }.joined()
  27 | }
  28 | 
  29 | // WebSocket Delegate
  30 | class WSDelegate: NSObject, URLSessionWebSocketDelegate {
  31 |     var onOpen: (() -> Void)?
  32 |     
  33 |     func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
  34 |         print("   ✅ WebSocket 已连接")
  35 |         onOpen?()
  36 |     }
  37 | }
  38 | 
  39 | // 主测试
  40 | func runTest() async {
  41 |     print("\n📝 测试文本: \(text)")
  42 |     print("🎤 语音: \(voice)")
  43 |     
  44 |     // 构建 URL
  45 |     let secMsGec = generateSecMsGecToken()
  46 |     let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
  47 |     
  48 |     guard let url = URL(string: urlString) else {
  49 |         print("❌ URL 无效")
  50 |         return
  51 |     }
  52 |     
  53 |     // 创建 WebSocket
  54 |     print("\n🔗 正在连接...")
  55 |     var request = URLRequest(url: url)
  56 |     request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
  57 |     request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
  58 |     
  59 |     let delegate = WSDelegate()
  60 |     let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
  61 |     let ws = session.webSocketTask(with: request)
  62 |     
  63 |     // 等待连接
  64 |     await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
  65 |         delegate.onOpen = { cont.resume() }
  66 |         ws.resume()
  67 |     }
  68 |     
  69 |     // 发送配置
  70 |     print("📤 发送配置...")
  71 |     let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
  72 |     do {
  73 |         try await ws.send(.string(configMessage))
  74 |         print("   ✅ 配置已发送")
  75 |     } catch {
  76 |         print("   ❌ 发送配置失败: \(error)")
  77 |         return
  78 |     }
  79 |     
  80 |     // 发送 SSML
  81 |     print("📤 发送 SSML...")
  82 |     let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
  83 |     let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
  84 |     do {
  85 |         try await ws.send(.string(ssmlMessage))
  86 |         print("   ✅ SSML 已发送")
  87 |     } catch {
  88 |         print("   ❌ 发送 SSML 失败: \(error)")
  89 |         return
  90 |     }
  91 |     
  92 |     // 接收音频
  93 |     print("\n📥 接收音频数据...")
  94 |     var audioData = Data()
  95 |     var messageCount = 0
  96 |     
  97 |     while true {
  98 |         do {
  99 |             let message = try await ws.receive()
 100 |             messageCount += 1
 101 |             
 102 |             switch message {
 103 |             case .data(let data):
 104 |                 // 尝试解析为字符串查看内容
 105 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 106 |                     // 找到音频分隔符后的数据
 107 |                     if let range = str.range(of: "Path:audio\r\n") {
 108 |                         let offset = range.upperBound.utf16Offset(in: str)
 109 |                         let audioChunk = data.suffix(from: offset)
 110 |                         audioData.append(audioChunk)
 111 |                         print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
 112 |                     }
 113 |                 } else {
 114 |                     // 纯二进制音频
 115 |                     audioData.append(data)
 116 |                     print("   收到音频块 #\(messageCount): \(data.count) bytes")
 117 |                 }
 118 |                 
 119 |             case .string(let str):
 120 |                 if str.contains("Path:turn.end") {
 121 |                     print("   ✅ 收到结束信号")
 122 |                     break
 123 |                 } else if str.contains("Path:audio.metadata") {
 124 |                     print("   收到元数据")
 125 |                 } else {
 126 |                     print("   收到文本: \(str.prefix(50))...")
 127 |                 }
 128 |                 continue
 129 |                 
 130 |             @unknown default:
 131 |                 continue
 132 |             }
 133 |             
 134 |             if messageCount > 100 { break } // 防止死循环
 135 |             
 136 |         } catch {
 137 |             print("   ⚠️ 接收错误: \(error)")
 138 |             break
 139 |         }
 140 |     }
 141 |     
 142 |     ws.cancel(with: .goingAway, reason: nil)
 143 |     
 144 |     print("\n📊 结果:")
 145 |     print("   总消息数: \(messageCount)")
 146 |     print("   音频大小: \(audioData.count) bytes")
 147 |     
 148 |     if audioData.isEmpty {
 149 |         print("   ❌ 没有收到音频数据")
 150 |         return
 151 |     }
 152 |     
 153 |     // 检查音频头
 154 |     let header = audioData.prefix(16)
 155 |     print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
 156 |     
 157 |     // MP3 文件应该以 FF FB 或 ID3 开头
 158 |     if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
 159 |         print("   ✅ 看起来是有效的 MP3 格式")
 160 |     } else {
 161 |         print("   ⚠️ 可能不是标准 MP3 格式")
 162 |     }
 163 |     
 164 |     // 保存到文件
 165 |     let tempPath = "/tmp/edge_tts_test.mp3"
 166 |     do {
 167 |         try audioData.write(to: URL(fileURLWithPath: tempPath))
 168 |         print("\n💾 已保存到: \(tempPath)")
 169 |     } catch {
 170 |         print("   ❌ 保存失败: \(error)")
 171 |         return
 172 |     }
 173 |     
 174 |     // 播放测试
 175 |     print("\n🔊 播放测试...")
 176 |     do {
 177 |         let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
 178 |         player.prepareToPlay()
 179 |         
 180 |         if player.play() {
 181 |             print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
 182 |             
 183 |             // 等待播放完成
 184 |             while player.isPlaying {
 185 |                 try await Task.sleep(nanoseconds: 100_000_000)
 186 |             }
 187 |             print("   ✅ 播放完成!")
 188 |         } else {
 189 |             print("   ❌ 播放启动失败")
 190 |         }
 191 |     } catch {
 192 |         print("   ❌ 播放错误: \(error)")
 193 |         
 194 |         // 尝试用 afplay 播放
 195 |         print("\n🔧 尝试用 afplay 播放...")
 196 |         let process = Process()
 197 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
 198 |         process.arguments = [tempPath]
 199 |         try? process.run()
 200 |         process.waitUntilExit()
 201 |         
 202 |         if process.terminationStatus == 0 {
 203 |             print("   ✅ afplay 播放成功!")
 204 |         } else {
 205 |             print("   ❌ afplay 也失败了")
 206 |         }
 207 |     }
 208 | }
 209 | 
 210 | // 运行测试
 211 | Task {
 212 |     await runTest()
 213 |     exit(0)
 214 | }
 215 | 
 216 | // 保持运行
 217 | RunLoop.main.run()

```
```

`spoke/docs/code2prompt-output/lucid-source.md`:

```md
Project Path: spoke

Source Tree:

```txt
spoke
└── Tests
    ├── AttachmentTests.swift
    ├── EdgeTTSTests.swift
    ├── TextExtractionTests.swift
    └── test_edge_tts.swift

```

`spoke/Tests/AttachmentTests.swift`:

```swift
   1 | import Foundation
   2 | import AppKit
   3 | 
   4 | // MARK: - Attachment Tests
   5 | 
   6 | /// Attachment 类型单元测试
   7 | /// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
   8 | @main
   9 | struct AttachmentTests {
  10 |     
  11 |     static var passCount = 0
  12 |     static var failCount = 0
  13 |     
  14 |     static func main() async {
  15 |         print("🧪 Attachment 类型单元测试")
  16 |         print("=" * 50)
  17 |         
  18 |         // 运行测试
  19 |         runTest("Image 类型属性") { try testImageAttachment() }
  20 |         runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
  21 |         runTest("File 类型属性") { try testFileAttachment() }
  22 |         runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
  23 |         runTest("视频文件检测") { try testVideoDetection() }
  24 |         runTest("ID 相等性判断") { try testEqualityById() }
  25 |         runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
  26 |         runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
  27 |         runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
  28 |         runTest("缩略图处理空图") { try testThumbnailZeroSize() }
  29 |         
  30 |         print("\n" + "=" * 50)
  31 |         print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  32 |     }
  33 |     
  34 |     // MARK: - Test Runner
  35 |     
  36 |     static func runTest(_ name: String, _ test: () throws -> Void) {
  37 |         print("\n📝 测试: \(name)")
  38 |         do {
  39 |             try test()
  40 |             print("   ✅ 通过")
  41 |             passCount += 1
  42 |         } catch {
  43 |             print("   ❌ 失败: \(error)")
  44 |             failCount += 1
  45 |         }
  46 |     }
  47 |     
  48 |     // MARK: - Test Cases: Attachment Types
  49 |     
  50 |     static func testImageAttachment() throws {
  51 |         let image = NSImage(size: NSSize(width: 100, height: 100))
  52 |         let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
  53 |         let id = UUID()
  54 |         
  55 |         let attachment = Attachment.image(image, thumbnail, id)
  56 |         
  57 |         try assertEqual(attachment.id, id, "ID")
  58 |         try assertEqual(attachment.displayTitle, "图片", "displayTitle")
  59 |         try assertNotNil(attachment.thumbnail, "thumbnail")
  60 |         try assertNotNil(attachment.originalImage, "originalImage")
  61 |         try assertFalse(attachment.isVideo, "isVideo")
  62 |         try assertFalse(attachment.isTextBundle, "isTextBundle")
  63 |         try assertNil(attachment.textContent, "textContent")
  64 |     }
  65 |     
  66 |     static func testScreenshotAttachment() throws {
  67 |         let image = NSImage(size: NSSize(width: 1920, height: 1080))
  68 |         let id = UUID()
  69 |         
  70 |         let attachment = Attachment.screenshot(image, nil, id)
  71 |         
  72 |         try assertEqual(attachment.id, id, "ID")
  73 |         try assertEqual(attachment.displayTitle, "截图", "displayTitle")
  74 |         try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
  75 |         try assertNotNil(attachment.originalImage, "originalImage")
  76 |     }
  77 |     
  78 |     static func testFileAttachment() throws {
  79 |         let url = URL(fileURLWithPath: "/tmp/test.pdf")
  80 |         let id = UUID()
  81 |         
  82 |         let attachment = Attachment.file(url, id)
  83 |         
  84 |         try assertEqual(attachment.id, id, "ID")
  85 |         try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
  86 |         try assertEqual(attachment.fileName, "test.pdf", "fileName")
  87 |         try assertNil(attachment.thumbnail, "thumbnail")
  88 |         try assertNil(attachment.originalImage, "originalImage")
  89 |     }
  90 |     
  91 |     static func testTextBundleAttachment() throws {
  92 |         let content = "# Code content\nlet x = 1"
  93 |         let source = "my-project"
  94 |         let count = 42
  95 |         let id = UUID()
  96 |         
  97 |         let attachment = Attachment.textBundle(content, source, count, id)
  98 |         
  99 |         try assertEqual(attachment.id, id, "ID")
 100 |         try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
 101 |         try assertEqual(attachment.fileName, source, "fileName")
 102 |         try assertTrue(attachment.isTextBundle, "isTextBundle")
 103 |         try assertEqual(attachment.textContent, content, "textContent")
 104 |     }
 105 |     
 106 |     static func testVideoDetection() throws {
 107 |         let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
 108 |         let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
 109 |         let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
 110 |         
 111 |         try assertTrue(mp4.isVideo, "mp4 should be video")
 112 |         try assertTrue(mov.isVideo, "mov should be video")
 113 |         try assertFalse(txt.isVideo, "txt should not be video")
 114 |     }
 115 |     
 116 |     static func testEqualityById() throws {
 117 |         let id = UUID()
 118 |         let image1 = NSImage(size: NSSize(width: 100, height: 100))
 119 |         let image2 = NSImage(size: NSSize(width: 200, height: 200))
 120 |         
 121 |         let att1 = Attachment.image(image1, nil, id)
 122 |         let att2 = Attachment.image(image2, nil, id)
 123 |         let att3 = Attachment.image(image1, nil, UUID())
 124 |         
 125 |         try assertTrue(att1 == att2, "Same ID should be equal")
 126 |         try assertFalse(att1 == att3, "Different ID should not be equal")
 127 |     }
 128 |     
 129 |     // MARK: - Test Cases: Thumbnail Generation
 130 |     
 131 |     static func testThumbnailResizesLarge() throws {
 132 |         let large = createTestImage(width: 2000, height: 1000)
 133 |         let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
 134 |         
 135 |         try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
 136 |         try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
 137 |     }
 138 |     
 139 |     static func testThumbnailPreservesRatio() throws {
 140 |         let image = createTestImage(width: 2000, height: 1000)
 141 |         let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
 142 |         
 143 |         let ratio = thumb.size.width / thumb.size.height
 144 |         try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
 145 |     }
 146 |     
 147 |     static func testThumbnailNoUpscale() throws {
 148 |         let small = createTestImage(width: 50, height: 50)
 149 |         let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
 150 |         
 151 |         try assertEqual(thumb.size.width, 50, "Width")
 152 |         try assertEqual(thumb.size.height, 50, "Height")
 153 |     }
 154 |     
 155 |     static func testThumbnailZeroSize() throws {
 156 |         let zero = NSImage(size: NSSize(width: 0, height: 0))
 157 |         let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
 158 |         
 159 |         try assertEqual(thumb.size.width, 0, "Width")
 160 |     }
 161 |     
 162 |     // MARK: - Helpers
 163 |     
 164 |     static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
 165 |         let image = NSImage(size: NSSize(width: width, height: height))
 166 |         image.lockFocus()
 167 |         NSColor.red.setFill()
 168 |         NSRect(x: 0, y: 0, width: width, height: height).fill()
 169 |         image.unlockFocus()
 170 |         return image
 171 |     }
 172 | }
 173 | 
 174 | // MARK: - Attachment Type (简化版，用于测试)
 175 | 
 176 | import UniformTypeIdentifiers
 177 | 
 178 | enum Attachment: Identifiable, Equatable {
 179 |     case image(NSImage, NSImage?, UUID)
 180 |     case screenshot(NSImage, NSImage?, UUID)
 181 |     case file(URL, UUID)
 182 |     case textBundle(String, String, Int, UUID)
 183 |     
 184 |     var id: UUID {
 185 |         switch self {
 186 |         case .image(_, _, let id), .screenshot(_, _, let id),
 187 |              .file(_, let id), .textBundle(_, _, _, let id):
 188 |             return id
 189 |         }
 190 |     }
 191 |     
 192 |     var thumbnail: NSImage? {
 193 |         switch self {
 194 |         case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
 195 |         default: return nil
 196 |         }
 197 |     }
 198 |     
 199 |     var originalImage: NSImage? {
 200 |         switch self {
 201 |         case .image(let img, _, _), .screenshot(let img, _, _): return img
 202 |         default: return nil
 203 |         }
 204 |     }
 205 |     
 206 |     var fileName: String? {
 207 |         switch self {
 208 |         case .file(let url, _): return url.lastPathComponent
 209 |         case .textBundle(_, let source, _, _): return source
 210 |         default: return nil
 211 |         }
 212 |     }
 213 |     
 214 |     var displayTitle: String {
 215 |         switch self {
 216 |         case .image: return "图片"
 217 |         case .screenshot: return "截图"
 218 |         case .file(let url, _): return url.lastPathComponent
 219 |         case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
 220 |         }
 221 |     }
 222 |     
 223 |     var isVideo: Bool {
 224 |         if case .file(let url, _) = self,
 225 |            let uti = UTType(filenameExtension: url.pathExtension) {
 226 |             return uti.conforms(to: .movie) || uti.conforms(to: .video)
 227 |         }
 228 |         return false
 229 |     }
 230 |     
 231 |     var isTextBundle: Bool {
 232 |         if case .textBundle = self { return true }
 233 |         return false
 234 |     }
 235 |     
 236 |     var textContent: String? {
 237 |         if case .textBundle(let content, _, _, _) = self { return content }
 238 |         return nil
 239 |     }
 240 |     
 241 |     static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
 242 |     
 243 |     static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
 244 |         let size = image.size
 245 |         guard size.width > 0 && size.height > 0 else { return image }
 246 |         
 247 |         let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
 248 |         let newSize = NSSize(width: size.width * scale, height: size.height * scale)
 249 |         
 250 |         let thumbnail = NSImage(size: newSize)
 251 |         thumbnail.lockFocus()
 252 |         image.draw(in: NSRect(origin: .zero, size: newSize),
 253 |                    from: NSRect(origin: .zero, size: size),
 254 |                    operation: .copy, fraction: 1.0)
 255 |         thumbnail.unlockFocus()
 256 |         return thumbnail
 257 |     }
 258 | }
 259 | 
 260 | // MARK: - Assertion Helpers
 261 | 
 262 | struct TestError: Error, CustomStringConvertible {
 263 |     let message: String
 264 |     init(_ message: String) { self.message = message }
 265 |     var description: String { message }
 266 | }
 267 | 
 268 | func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
 269 |     if actual != expected {
 270 |         throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
 271 |     }
 272 | }
 273 | 
 274 | func assertTrue(_ condition: Bool, _ message: String) throws {
 275 |     if !condition { throw TestError(message) }
 276 | }
 277 | 
 278 | func assertFalse(_ condition: Bool, _ message: String) throws {
 279 |     if condition { throw TestError(message) }
 280 | }
 281 | 
 282 | func assertNil<T>(_ value: T?, _ message: String) throws {
 283 |     if value != nil { throw TestError("\(message) 应该是 nil") }
 284 | }
 285 | 
 286 | func assertNotNil<T>(_ value: T?, _ message: String) throws {
 287 |     if value == nil { throw TestError("\(message) 不应该是 nil") }
 288 | }
 289 | 
 290 | extension String {
 291 |     static func * (string: String, count: Int) -> String {
 292 |         String(repeating: string, count: count)
 293 |     }
 294 | }

```

`spoke/Tests/EdgeTTSTests.swift`:

```swift
   1 | import Foundation
   2 | import AVFoundation
   3 | 
   4 | // MARK: - Edge TTS 单元测试
   5 | 
   6 | @main
   7 | struct EdgeTTSTests {
   8 |     static func main() async {
   9 |         print("🧪 Edge TTS 单元测试")
  10 |         print("=" * 50)
  11 |         
  12 |         await testSynthesizeAndPlay()
  13 |     }
  14 |     
  15 |     /// 测试合成并播放
  16 |     static func testSynthesizeAndPlay() async {
  17 |         print("\n📝 测试: 合成并播放")
  18 |         
  19 |         let text = "你好，这是语音合成测试。"
  20 |         let voice = "zh-CN-XiaoxiaoNeural"
  21 |         
  22 |         do {
  23 |             // 1. 合成音频
  24 |             print("   正在合成...")
  25 |             let audioData = try await synthesize(text: text, voice: voice)
  26 |             print("   ✅ 合成完成: \(audioData.count) bytes")
  27 |             
  28 |             // 2. 检查音频头
  29 |             print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
  30 |             
  31 |             // 3. 保存到文件测试
  32 |             let tempPath = "/tmp/edge_tts_test.mp3"
  33 |             try audioData.write(to: URL(fileURLWithPath: tempPath))
  34 |             print("   ✅ 已保存到: \(tempPath)")
  35 |             
  36 |             // 4. 用 AVAudioPlayer 播放
  37 |             print("   正在播放...")
  38 |             let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
  39 |             player.prepareToPlay()
  40 |             player.play()
  41 |             
  42 |             // 等待播放完成
  43 |             while player.isPlaying {
  44 |                 try await Task.sleep(nanoseconds: 100_000_000)
  45 |             }
  46 |             print("   ✅ 播放完成!")
  47 |             
  48 |         } catch {
  49 |             print("   ❌ 错误: \(error)")
  50 |         }
  51 |     }
  52 |     
  53 |     /// 合成音频
  54 |     static func synthesize(text: String, voice: String) async throws -> Data {
  55 |         // DRM Token
  56 |         let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
  57 |         let chromiumVersion = "130.0.2849.68"
  58 |         let windowsFileTimeEpoch: Int64 = 11_644_473_600
  59 |         
  60 |         let currentTime = Int64(Date().timeIntervalSince1970)
  61 |         let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
  62 |         let roundedTicks = ticks - (ticks % 3_000_000_000)
  63 |         let strToHash = "\(roundedTicks)\(trustedClientToken)"
  64 |         
  65 |         // SHA256
  66 |         import CryptoKit
  67 |         let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
  68 |         let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
  69 |         
  70 |         // URL
  71 |         let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
  72 |         let url = URL(string: urlString)!
  73 |         
  74 |         // WebSocket
  75 |         var request = URLRequest(url: url)
  76 |         request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
  77 |         request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
  78 |         
  79 |         let session = URLSession.shared
  80 |         let ws = session.webSocketTask(with: request)
  81 |         ws.resume()
  82 |         
  83 |         // 等待连接
  84 |         try await Task.sleep(nanoseconds: 500_000_000)
  85 |         
  86 |         // 发送配置
  87 |         let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
  88 |         try await ws.send(.string(configMessage))
  89 |         
  90 |         // 发送 SSML
  91 |         let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
  92 |         let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
  93 |         try await ws.send(.string(ssmlMessage))
  94 |         
  95 |         // 接收音频
  96 |         var audioData = Data()
  97 |         
  98 |         while true {
  99 |             let message = try await ws.receive()
 100 |             
 101 |             switch message {
 102 |             case .data(let data):
 103 |                 // 检查是否包含 Path:audio
 104 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 105 |                     if let range = str.range(of: "Path:audio\r\n") {
 106 |                         let offset = range.upperBound.utf16Offset(in: str)
 107 |                         audioData.append(data[offset...])
 108 |                     }
 109 |                 } else {
 110 |                     audioData.append(data)
 111 |                 }
 112 |                 
 113 |             case .string(let str):
 114 |                 if str.contains("Path:turn.end") {
 115 |                     ws.cancel(with: .goingAway, reason: nil)
 116 |                     return audioData
 117 |                 }
 118 |                 
 119 |             @unknown default:
 120 |                 break
 121 |             }
 122 |         }
 123 |     }
 124 | }
 125 | 
 126 | extension String {
 127 |     static func * (string: String, count: Int) -> String {
 128 |         String(repeating: string, count: count)
 129 |     }
 130 | }

```

`spoke/Tests/TextExtractionTests.swift`:

```swift
   1 | import Foundation
   2 | 
   3 | // MARK: - Text Extraction Service Tests
   4 | 
   5 | /// 独立运行的测试脚本
   6 | /// 用法: swift Tests/TextExtractionTests.swift
   7 | @main
   8 | struct TextExtractionTests {
   9 |     
  10 |     static var tempDirectory: URL!
  11 |     static var passCount = 0
  12 |     static var failCount = 0
  13 |     
  14 |     static func main() async {
  15 |         print("🧪 TextExtractionService 单元测试")
  16 |         print("=" * 50)
  17 |         
  18 |         // 创建临时目录
  19 |         tempDirectory = FileManager.default.temporaryDirectory
  20 |             .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
  21 |         try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  22 |         
  23 |         defer {
  24 |             // 清理
  25 |             try? FileManager.default.removeItem(at: tempDirectory)
  26 |             print("\n" + "=" * 50)
  27 |             print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  28 |         }
  29 |         
  30 |         // 运行测试
  31 |         await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
  32 |         await runTest("单文件提取") { try await testSingleFileExtraction() }
  33 |         await runTest("多文件合并") { try await testMultipleFilesExtraction() }
  34 |         await runTest("排除 node_modules") { try await testExcludesNodeModules() }
  35 |         await runTest("排除锁文件") { try await testExcludesLockFiles() }
  36 |         await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
  37 |         await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
  38 |         await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
  39 |         await runTest("添加行号") { try await testAddsLineNumbers() }
  40 |         await runTest("目录结构输出") { try await testDirectoryStructure() }
  41 |         await runTest("ZIP 提取") { try await testZIPExtraction() }
  42 |     }
  43 |     
  44 |     // MARK: - Test Runner
  45 |     
  46 |     static func runTest(_ name: String, _ test: () async throws -> Void) async {
  47 |         print("\n📝 测试: \(name)")
  48 |         do {
  49 |             try await test()
  50 |             print("   ✅ 通过")
  51 |             passCount += 1
  52 |         } catch {
  53 |             print("   ❌ 失败: \(error)")
  54 |             failCount += 1
  55 |         }
  56 |     }
  57 |     
  58 |     // MARK: - Helpers
  59 |     
  60 |     static func createFile(name: String, content: String) throws -> URL {
  61 |         let fileURL = tempDirectory.appendingPathComponent(name)
  62 |         let dir = fileURL.deletingLastPathComponent()
  63 |         try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  64 |         try content.write(to: fileURL, atomically: true, encoding: .utf8)
  65 |         return fileURL
  66 |     }
  67 |     
  68 |     static func createDirectory(name: String) throws -> URL {
  69 |         let dirURL = tempDirectory.appendingPathComponent(name)
  70 |         try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
  71 |         return dirURL
  72 |     }
  73 |     
  74 |     // MARK: - Test Cases
  75 |     
  76 |     static func testCodeExtensions() async throws {
  77 |         // 创建各种代码文件
  78 |         _ = try createFile(name: "test.swift", content: "let x = 1")
  79 |         _ = try createFile(name: "app.js", content: "const x = 1")
  80 |         _ = try createFile(name: "main.py", content: "x = 1")
  81 |         _ = try createFile(name: "README.md", content: "# Title")
  82 |         
  83 |         let result = await extractFromFolder(tempDirectory)
  84 |         guard case .success(let bundle) = result else {
  85 |             throw TestError("提取失败")
  86 |         }
  87 |         
  88 |         guard bundle.fileCount == 4 else {
  89 |             throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
  90 |         }
  91 |     }
  92 |     
  93 |     static func testSingleFileExtraction() async throws {
  94 |         // 清理并创建新目录
  95 |         try FileManager.default.removeItem(at: tempDirectory)
  96 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  97 |         
  98 |         _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
  99 |         
 100 |         let result = await extractFromFolder(tempDirectory)
 101 |         guard case .success(let bundle) = result else {
 102 |             throw TestError("提取失败")
 103 |         }
 104 |         
 105 |         guard bundle.fileCount == 1 else {
 106 |             throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
 107 |         }
 108 |         guard bundle.content.contains("print(\"Hello\")") else {
 109 |             throw TestError("内容不包含预期文本")
 110 |         }
 111 |     }
 112 |     
 113 |     static func testMultipleFilesExtraction() async throws {
 114 |         try FileManager.default.removeItem(at: tempDirectory)
 115 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 116 |         
 117 |         _ = try createFile(name: "a.swift", content: "let a = 1")
 118 |         _ = try createFile(name: "b.swift", content: "let b = 2")
 119 |         _ = try createFile(name: "c.js", content: "const c = 3")
 120 |         
 121 |         let result = await extractFromFolder(tempDirectory)
 122 |         guard case .success(let bundle) = result else {
 123 |             throw TestError("提取失败")
 124 |         }
 125 |         
 126 |         guard bundle.fileCount == 3 else {
 127 |             throw TestError("文件数量错误")
 128 |         }
 129 |         guard bundle.content.contains("let a = 1") &&
 130 |               bundle.content.contains("let b = 2") &&
 131 |               bundle.content.contains("const c = 3") else {
 132 |             throw TestError("内容缺失")
 133 |         }
 134 |     }
 135 |     
 136 |     static func testExcludesNodeModules() async throws {
 137 |         try FileManager.default.removeItem(at: tempDirectory)
 138 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 139 |         
 140 |         let nodeModules = try createDirectory(name: "node_modules")
 141 |         try "const secret = 'password'".write(
 142 |             to: nodeModules.appendingPathComponent("secret.js"),
 143 |             atomically: true, encoding: .utf8
 144 |         )
 145 |         _ = try createFile(name: "app.js", content: "const app = 1")
 146 |         
 147 |         let result = await extractFromFolder(tempDirectory)
 148 |         guard case .success(let bundle) = result else {
 149 |             throw TestError("提取失败")
 150 |         }
 151 |         
 152 |         guard bundle.fileCount == 1 else {
 153 |             throw TestError("应该只包含 app.js")
 154 |         }
 155 |         guard !bundle.content.contains("secret") else {
 156 |             throw TestError("不应包含 node_modules 内容")
 157 |         }
 158 |     }
 159 |     
 160 |     static func testExcludesLockFiles() async throws {
 161 |         try FileManager.default.removeItem(at: tempDirectory)
 162 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 163 |         
 164 |         _ = try createFile(name: "package-lock.json", content: "{}")
 165 |         _ = try createFile(name: "yarn.lock", content: "")
 166 |         _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
 167 |         
 168 |         let result = await extractFromFolder(tempDirectory)
 169 |         guard case .success(let bundle) = result else {
 170 |             throw TestError("提取失败")
 171 |         }
 172 |         
 173 |         guard bundle.fileCount == 1 else {
 174 |             throw TestError("应该只包含 package.json")
 175 |         }
 176 |     }
 177 |     
 178 |     static func testNestedDirectories() async throws {
 179 |         try FileManager.default.removeItem(at: tempDirectory)
 180 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 181 |         
 182 |         _ = try createFile(name: "root.swift", content: "let root = 1")
 183 |         _ = try createFile(name: "src/app.swift", content: "let src = 2")
 184 |         _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
 185 |         
 186 |         let result = await extractFromFolder(tempDirectory)
 187 |         guard case .success(let bundle) = result else {
 188 |             throw TestError("提取失败")
 189 |         }
 190 |         
 191 |         guard bundle.fileCount == 3 else {
 192 |             throw TestError("应该包含 3 个文件")
 193 |         }
 194 |         guard bundle.content.contains("let root = 1") &&
 195 |               bundle.content.contains("let src = 2") &&
 196 |               bundle.content.contains("let lib = 3") else {
 197 |             throw TestError("缺少嵌套目录内容")
 198 |         }
 199 |     }
 200 |     
 201 |     static func testEmptyFolderError() async throws {
 202 |         try FileManager.default.removeItem(at: tempDirectory)
 203 |         let emptyDir = try createDirectory(name: "empty")
 204 |         
 205 |         let result = await extractFromFolder(emptyDir)
 206 |         guard case .failure = result else {
 207 |             throw TestError("空文件夹应该返回错误")
 208 |         }
 209 |     }
 210 |     
 211 |     static func testIgnoresNonCodeFiles() async throws {
 212 |         try FileManager.default.removeItem(at: tempDirectory)
 213 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 214 |         
 215 |         _ = try createFile(name: "image.png", content: "fake")
 216 |         _ = try createFile(name: "video.mp4", content: "fake")
 217 |         _ = try createFile(name: "main.swift", content: "let x = 1")
 218 |         
 219 |         let result = await extractFromFolder(tempDirectory)
 220 |         guard case .success(let bundle) = result else {
 221 |             throw TestError("提取失败")
 222 |         }
 223 |         
 224 |         guard bundle.fileCount == 1 else {
 225 |             throw TestError("应该只包含 .swift 文件")
 226 |         }
 227 |     }
 228 |     
 229 |     static func testAddsLineNumbers() async throws {
 230 |         try FileManager.default.removeItem(at: tempDirectory)
 231 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 232 |         
 233 |         _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
 234 |         
 235 |         let result = await extractFromFolder(tempDirectory)
 236 |         guard case .success(let bundle) = result else {
 237 |             throw TestError("提取失败")
 238 |         }
 239 |         
 240 |         guard bundle.content.contains("1│") &&
 241 |               bundle.content.contains("2│") &&
 242 |               bundle.content.contains("3│") else {
 243 |             throw TestError("缺少行号")
 244 |         }
 245 |     }
 246 |     
 247 |     static func testDirectoryStructure() async throws {
 248 |         try FileManager.default.removeItem(at: tempDirectory)
 249 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 250 |         
 251 |         _ = try createFile(name: "main.swift", content: "entry")
 252 |         _ = try createFile(name: "src/app.swift", content: "code")
 253 |         
 254 |         let result = await extractFromFolder(tempDirectory)
 255 |         guard case .success(let bundle) = result else {
 256 |             throw TestError("提取失败")
 257 |         }
 258 |         
 259 |         guard bundle.content.contains("# 目录结构") else {
 260 |             throw TestError("缺少目录结构标题")
 261 |         }
 262 |     }
 263 |     
 264 |     static func testZIPExtraction() async throws {
 265 |         try FileManager.default.removeItem(at: tempDirectory)
 266 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 267 |         
 268 |         // 创建源文件
 269 |         let sourceDir = try createDirectory(name: "source")
 270 |         try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
 271 |         
 272 |         // 创建 ZIP
 273 |         let zipPath = tempDirectory.appendingPathComponent("test.zip")
 274 |         let process = Process()
 275 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
 276 |         process.currentDirectoryURL = tempDirectory
 277 |         process.arguments = ["-r", zipPath.path, "source"]
 278 |         process.standardOutput = FileHandle.nullDevice
 279 |         process.standardError = FileHandle.nullDevice
 280 |         try process.run()
 281 |         process.waitUntilExit()
 282 |         
 283 |         guard process.terminationStatus == 0 else {
 284 |             throw TestError("创建 ZIP 失败")
 285 |         }
 286 |         
 287 |         let result = await extractFromZIP(zipPath)
 288 |         guard case .success(let bundle) = result else {
 289 |             throw TestError("ZIP 提取失败")
 290 |         }
 291 |         
 292 |         guard bundle.fileCount == 1 else {
 293 |             throw TestError("ZIP 文件数量错误")
 294 |         }
 295 |         guard bundle.content.contains("let x = 1") else {
 296 |             throw TestError("ZIP 内容缺失")
 297 |         }
 298 |     }
 299 | }
 300 | 
 301 | // MARK: - TextExtractionService (简化版，用于测试)
 302 | 
 303 | struct TextBundle {
 304 |     let content: String
 305 |     let fileCount: Int
 306 |     let sourcePath: String
 307 |     let files: [String]
 308 | }
 309 | 
 310 | enum TextExtractionError: Error, Equatable {
 311 |     case folderNotFound
 312 |     case zipExtractionFailed(String)
 313 |     case noTextFilesFound
 314 |     case accessDenied
 315 | }
 316 | 
 317 | func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
 318 |     let codeExtensions: Set<String> = [
 319 |         "js", "jsx", "ts", "tsx", "mjs", "cjs",
 320 |         "html", "htm", "css", "scss", "less", "vue", "svelte",
 321 |         "py", "pyw", "pyi",
 322 |         "java", "kt", "kts", "scala",
 323 |         "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
 324 |         "rs", "go", "rb", "erb", "php", "swift",
 325 |         "sh", "bash", "zsh", "fish",
 326 |         "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
 327 |         "md", "mdx", "txt", "rst", "asciidoc",
 328 |         "sql", "graphql", "proto", "dockerfile"
 329 |     ]
 330 |     
 331 |     let excludedDirs: Set<String> = [
 332 |         "node_modules", ".git", ".svn", ".hg",
 333 |         "dist", "build", "target", ".next", ".nuxt",
 334 |         "__pycache__", ".pytest_cache", ".tox",
 335 |         "venv", "env", ".env", ".venv",
 336 |         "vendor", "Pods", "Carthage",
 337 |         ".idea", ".vscode", ".vs"
 338 |     ]
 339 |     
 340 |     let excludedFiles: Set<String> = [
 341 |         ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
 342 |         "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
 343 |         "Podfile.lock", "Gemfile.lock", "Cargo.lock"
 344 |     ]
 345 |     
 346 |     // 递归收集文件
 347 |     func collectFiles(in directory: URL) -> [URL] {
 348 |         var result: [URL] = []
 349 |         let fm = FileManager.default
 350 |         
 351 |         guard let contents = try? fm.contentsOfDirectory(
 352 |             at: directory,
 353 |             includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
 354 |             options: [.skipsHiddenFiles]
 355 |         ) else { return [] }
 356 |         
 357 |         for url in contents {
 358 |             let fileName = url.lastPathComponent
 359 |             if excludedFiles.contains(fileName) { continue }
 360 |             
 361 |             let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
 362 |             
 363 |             if values?.isDirectory == true {
 364 |                 if !excludedDirs.contains(fileName) {
 365 |                     result.append(contentsOf: collectFiles(in: url))
 366 |                 }
 367 |             } else if values?.isRegularFile == true {
 368 |                 let ext = url.pathExtension.lowercased()
 369 |                 if codeExtensions.contains(ext) {
 370 |                     result.append(url)
 371 |                 }
 372 |             }
 373 |         }
 374 |         return result.sorted { $0.path < $1.path }
 375 |     }
 376 |     
 377 |     let files = collectFiles(in: folderURL)
 378 |     guard !files.isEmpty else {
 379 |         return .failure(.noTextFilesFound)
 380 |     }
 381 |     
 382 |     // 合并内容
 383 |     var parts: [String] = ["# 目录结构\n```"]
 384 |     for file in files {
 385 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 386 |         parts.append(rel)
 387 |     }
 388 |     parts.append("```\n\n# 文件内容\n")
 389 |     
 390 |     for file in files {
 391 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 392 |         let ext = file.pathExtension
 393 |         if let content = try? String(contentsOf: file, encoding: .utf8) {
 394 |             let numbered = content.components(separatedBy: .newlines).enumerated()
 395 |                 .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
 396 |             parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
 397 |         }
 398 |     }
 399 |     
 400 |     return .success(TextBundle(
 401 |         content: parts.joined(separator: "\n"),
 402 |         fileCount: files.count,
 403 |         sourcePath: folderURL.path,
 404 |         files: files.map { $0.path }
 405 |     ))
 406 | }
 407 | 
 408 | func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
 409 |     let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
 410 |     try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
 411 |     defer { try? FileManager.default.removeItem(at: tempDir) }
 412 |     
 413 |     let process = Process()
 414 |     process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
 415 |     process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
 416 |     process.standardOutput = FileHandle.nullDevice
 417 |     process.standardError = FileHandle.nullDevice
 418 |     
 419 |     do {
 420 |         try process.run()
 421 |         process.waitUntilExit()
 422 |         
 423 |         guard process.terminationStatus == 0 else {
 424 |             return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
 425 |         }
 426 |         
 427 |         return await extractFromFolder(tempDir)
 428 |     } catch {
 429 |         return .failure(.zipExtractionFailed(error.localizedDescription))
 430 |     }
 431 | }
 432 | 
 433 | // MARK: - Helpers
 434 | 
 435 | struct TestError: Error, CustomStringConvertible {
 436 |     let message: String
 437 |     init(_ message: String) { self.message = message }
 438 |     var description: String { message }
 439 | }
 440 | 
 441 | extension String {
 442 |     static func * (string: String, count: Int) -> String {
 443 |         String(repeating: string, count: count)
 444 |     }
 445 | }

```

`spoke/Tests/test_edge_tts.swift`:

```swift
   1 | #!/usr/bin/env swift
   2 | 
   3 | import Foundation
   4 | import CryptoKit
   5 | import AVFoundation
   6 | 
   7 | // MARK: - Edge TTS 测试脚本
   8 | 
   9 | print("🧪 Edge TTS 测试")
  10 | print(String(repeating: "=", count: 50))
  11 | 
  12 | // 配置
  13 | let text = "你好，这是语音合成测试。Hello, this is a test."
  14 | let voice = "zh-CN-XiaoxiaoNeural"
  15 | let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
  16 | let chromiumVersion = "130.0.2849.68"
  17 | let windowsFileTimeEpoch: Int64 = 11_644_473_600
  18 | 
  19 | // 生成 DRM Token
  20 | func generateSecMsGecToken() -> String {
  21 |     let currentTime = Int64(Date().timeIntervalSince1970)
  22 |     let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
  23 |     let roundedTicks = ticks - (ticks % 3_000_000_000)
  24 |     let strToHash = "\(roundedTicks)\(trustedClientToken)"
  25 |     let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
  26 |     return hash.map { String(format: "%02X", $0) }.joined()
  27 | }
  28 | 
  29 | // WebSocket Delegate
  30 | class WSDelegate: NSObject, URLSessionWebSocketDelegate {
  31 |     var onOpen: (() -> Void)?
  32 |     
  33 |     func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
  34 |         print("   ✅ WebSocket 已连接")
  35 |         onOpen?()
  36 |     }
  37 | }
  38 | 
  39 | // 主测试
  40 | func runTest() async {
  41 |     print("\n📝 测试文本: \(text)")
  42 |     print("🎤 语音: \(voice)")
  43 |     
  44 |     // 构建 URL
  45 |     let secMsGec = generateSecMsGecToken()
  46 |     let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
  47 |     
  48 |     guard let url = URL(string: urlString) else {
  49 |         print("❌ URL 无效")
  50 |         return
  51 |     }
  52 |     
  53 |     // 创建 WebSocket
  54 |     print("\n🔗 正在连接...")
  55 |     var request = URLRequest(url: url)
  56 |     request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
  57 |     request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
  58 |     
  59 |     let delegate = WSDelegate()
  60 |     let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
  61 |     let ws = session.webSocketTask(with: request)
  62 |     
  63 |     // 等待连接
  64 |     await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
  65 |         delegate.onOpen = { cont.resume() }
  66 |         ws.resume()
  67 |     }
  68 |     
  69 |     // 发送配置
  70 |     print("📤 发送配置...")
  71 |     let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
  72 |     do {
  73 |         try await ws.send(.string(configMessage))
  74 |         print("   ✅ 配置已发送")
  75 |     } catch {
  76 |         print("   ❌ 发送配置失败: \(error)")
  77 |         return
  78 |     }
  79 |     
  80 |     // 发送 SSML
  81 |     print("📤 发送 SSML...")
  82 |     let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
  83 |     let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
  84 |     do {
  85 |         try await ws.send(.string(ssmlMessage))
  86 |         print("   ✅ SSML 已发送")
  87 |     } catch {
  88 |         print("   ❌ 发送 SSML 失败: \(error)")
  89 |         return
  90 |     }
  91 |     
  92 |     // 接收音频
  93 |     print("\n📥 接收音频数据...")
  94 |     var audioData = Data()
  95 |     var messageCount = 0
  96 |     
  97 |     while true {
  98 |         do {
  99 |             let message = try await ws.receive()
 100 |             messageCount += 1
 101 |             
 102 |             switch message {
 103 |             case .data(let data):
 104 |                 // 尝试解析为字符串查看内容
 105 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 106 |                     // 找到音频分隔符后的数据
 107 |                     if let range = str.range(of: "Path:audio\r\n") {
 108 |                         let offset = range.upperBound.utf16Offset(in: str)
 109 |                         let audioChunk = data.suffix(from: offset)
 110 |                         audioData.append(audioChunk)
 111 |                         print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
 112 |                     }
 113 |                 } else {
 114 |                     // 纯二进制音频
 115 |                     audioData.append(data)
 116 |                     print("   收到音频块 #\(messageCount): \(data.count) bytes")
 117 |                 }
 118 |                 
 119 |             case .string(let str):
 120 |                 if str.contains("Path:turn.end") {
 121 |                     print("   ✅ 收到结束信号")
 122 |                     break
 123 |                 } else if str.contains("Path:audio.metadata") {
 124 |                     print("   收到元数据")
 125 |                 } else {
 126 |                     print("   收到文本: \(str.prefix(50))...")
 127 |                 }
 128 |                 continue
 129 |                 
 130 |             @unknown default:
 131 |                 continue
 132 |             }
 133 |             
 134 |             if messageCount > 100 { break } // 防止死循环
 135 |             
 136 |         } catch {
 137 |             print("   ⚠️ 接收错误: \(error)")
 138 |             break
 139 |         }
 140 |     }
 141 |     
 142 |     ws.cancel(with: .goingAway, reason: nil)
 143 |     
 144 |     print("\n📊 结果:")
 145 |     print("   总消息数: \(messageCount)")
 146 |     print("   音频大小: \(audioData.count) bytes")
 147 |     
 148 |     if audioData.isEmpty {
 149 |         print("   ❌ 没有收到音频数据")
 150 |         return
 151 |     }
 152 |     
 153 |     // 检查音频头
 154 |     let header = audioData.prefix(16)
 155 |     print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
 156 |     
 157 |     // MP3 文件应该以 FF FB 或 ID3 开头
 158 |     if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
 159 |         print("   ✅ 看起来是有效的 MP3 格式")
 160 |     } else {
 161 |         print("   ⚠️ 可能不是标准 MP3 格式")
 162 |     }
 163 |     
 164 |     // 保存到文件
 165 |     let tempPath = "/tmp/edge_tts_test.mp3"
 166 |     do {
 167 |         try audioData.write(to: URL(fileURLWithPath: tempPath))
 168 |         print("\n💾 已保存到: \(tempPath)")
 169 |     } catch {
 170 |         print("   ❌ 保存失败: \(error)")
 171 |         return
 172 |     }
 173 |     
 174 |     // 播放测试
 175 |     print("\n🔊 播放测试...")
 176 |     do {
 177 |         let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
 178 |         player.prepareToPlay()
 179 |         
 180 |         if player.play() {
 181 |             print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
 182 |             
 183 |             // 等待播放完成
 184 |             while player.isPlaying {
 185 |                 try await Task.sleep(nanoseconds: 100_000_000)
 186 |             }
 187 |             print("   ✅ 播放完成!")
 188 |         } else {
 189 |             print("   ❌ 播放启动失败")
 190 |         }
 191 |     } catch {
 192 |         print("   ❌ 播放错误: \(error)")
 193 |         
 194 |         // 尝试用 afplay 播放
 195 |         print("\n🔧 尝试用 afplay 播放...")
 196 |         let process = Process()
 197 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
 198 |         process.arguments = [tempPath]
 199 |         try? process.run()
 200 |         process.waitUntilExit()
 201 |         
 202 |         if process.terminationStatus == 0 {
 203 |             print("   ✅ afplay 播放成功!")
 204 |         } else {
 205 |             print("   ❌ afplay 也失败了")
 206 |         }
 207 |     }
 208 | }
 209 | 
 210 | // 运行测试
 211 | Task {
 212 |     await runTest()
 213 |     exit(0)
 214 | }
 215 | 
 216 | // 保持运行
 217 | RunLoop.main.run()

```
```
```

`spoke/docs/code2prompt-output/lucid-full.md`:

```md
Project Path: spoke

Source Tree:

```txt
spoke
├── App
│   ├── AppDelegate.swift
│   └── SpokenlyApp.swift
├── Core
│   ├── Attachment
│   │   ├── Attachment.swift
│   │   ├── AttachmentManager.swift
│   │   ├── ScreenCaptureService.swift
│   │   └── TextExtractionService.swift
│   ├── Audio
│   │   └── AudioRecorderService.swift
│   ├── DataModels.swift
│   ├── LLM
│   │   ├── KeychainService.swift
│   │   ├── LLMPipeline.swift
│   │   ├── LLMProvider.swift
│   │   ├── LLMSettings.swift
│   │   └── OpenAICompatibleProvider.swift
│   ├── MessagePanel
│   │   └── MessagePanelState.swift
│   ├── QuickAsk
│   │   └── QuickAskState.swift
│   ├── RecordingState.swift
│   └── Transcription
│       ├── Providers
│       │   ├── SFSpeechProvider.swift
│       │   └── SpeechAnalyzerProvider.swift
│       ├── TranscriptionManager.swift
│       └── TranscriptionProvider.swift
├── Package.swift
├── Resources
│   └── LocalModels
├── Services
│   ├── AppSettings.swift
│   ├── AudioDeviceManager.swift
│   ├── AudioPlayerService.swift
│   ├── ClipboardHistoryService.swift
│   ├── ContextService.swift
│   ├── DoubaoTTSService.swift
│   ├── EdgeTTSService.swift
│   ├── FloatingHUDManager.swift
│   ├── HistoryManager.swift
│   ├── HotKeyService.swift
│   ├── InputService.swift
│   ├── MessagePanelManager.swift
│   ├── QuickAskService.swift
│   ├── RecordingController.swift
│   └── TTSSettings.swift
├── Tests
│   ├── AttachmentTests.swift
│   ├── EdgeTTSTests.swift
│   ├── TextExtractionTests.swift
│   ├── run-tests.sh
│   └── test_edge_tts.swift
├── UI
│   ├── Components
│   │   ├── AttachmentDropOverlay.swift
│   │   ├── AttachmentPickerMenu.swift
│   │   └── AttachmentThumbnailView.swift
│   ├── HUD
│   │   ├── FloatingCapsuleView.swift
│   │   ├── FloatingPanel.swift
│   │   ├── HUDTheme.swift
│   │   ├── QuickAskCapsuleView.swift
│   │   └── QuickAskInputView.swift
│   ├── MessagePanel
│   │   └── MessagePanelView.swift
│   ├── QuickAsk
│   │   ├── AnswerPanelView.swift
│   │   └── MarkdownWebView.swift
│   └── Settings
│       └── SettingsView.swift
└── docs
    └── code2prompt-output
        ├── lucid-config.md
        ├── lucid-docs.md
        ├── lucid-full.md
        ├── lucid-source.json
        └── lucid-source.md

```

`spoke/Tests/AttachmentTests.swift`:

```swift
   1 | import Foundation
   2 | import AppKit
   3 | 
   4 | // MARK: - Attachment Tests
   5 | 
   6 | /// Attachment 类型单元测试
   7 | /// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
   8 | @main
   9 | struct AttachmentTests {
  10 |     
  11 |     static var passCount = 0
  12 |     static var failCount = 0
  13 |     
  14 |     static func main() async {
  15 |         print("🧪 Attachment 类型单元测试")
  16 |         print("=" * 50)
  17 |         
  18 |         // 运行测试
  19 |         runTest("Image 类型属性") { try testImageAttachment() }
  20 |         runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
  21 |         runTest("File 类型属性") { try testFileAttachment() }
  22 |         runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
  23 |         runTest("视频文件检测") { try testVideoDetection() }
  24 |         runTest("ID 相等性判断") { try testEqualityById() }
  25 |         runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
  26 |         runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
  27 |         runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
  28 |         runTest("缩略图处理空图") { try testThumbnailZeroSize() }
  29 |         
  30 |         print("\n" + "=" * 50)
  31 |         print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  32 |     }
  33 |     
  34 |     // MARK: - Test Runner
  35 |     
  36 |     static func runTest(_ name: String, _ test: () throws -> Void) {
  37 |         print("\n📝 测试: \(name)")
  38 |         do {
  39 |             try test()
  40 |             print("   ✅ 通过")
  41 |             passCount += 1
  42 |         } catch {
  43 |             print("   ❌ 失败: \(error)")
  44 |             failCount += 1
  45 |         }
  46 |     }
  47 |     
  48 |     // MARK: - Test Cases: Attachment Types
  49 |     
  50 |     static func testImageAttachment() throws {
  51 |         let image = NSImage(size: NSSize(width: 100, height: 100))
  52 |         let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
  53 |         let id = UUID()
  54 |         
  55 |         let attachment = Attachment.image(image, thumbnail, id)
  56 |         
  57 |         try assertEqual(attachment.id, id, "ID")
  58 |         try assertEqual(attachment.displayTitle, "图片", "displayTitle")
  59 |         try assertNotNil(attachment.thumbnail, "thumbnail")
  60 |         try assertNotNil(attachment.originalImage, "originalImage")
  61 |         try assertFalse(attachment.isVideo, "isVideo")
  62 |         try assertFalse(attachment.isTextBundle, "isTextBundle")
  63 |         try assertNil(attachment.textContent, "textContent")
  64 |     }
  65 |     
  66 |     static func testScreenshotAttachment() throws {
  67 |         let image = NSImage(size: NSSize(width: 1920, height: 1080))
  68 |         let id = UUID()
  69 |         
  70 |         let attachment = Attachment.screenshot(image, nil, id)
  71 |         
  72 |         try assertEqual(attachment.id, id, "ID")
  73 |         try assertEqual(attachment.displayTitle, "截图", "displayTitle")
  74 |         try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
  75 |         try assertNotNil(attachment.originalImage, "originalImage")
  76 |     }
  77 |     
  78 |     static func testFileAttachment() throws {
  79 |         let url = URL(fileURLWithPath: "/tmp/test.pdf")
  80 |         let id = UUID()
  81 |         
  82 |         let attachment = Attachment.file(url, id)
  83 |         
  84 |         try assertEqual(attachment.id, id, "ID")
  85 |         try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
  86 |         try assertEqual(attachment.fileName, "test.pdf", "fileName")
  87 |         try assertNil(attachment.thumbnail, "thumbnail")
  88 |         try assertNil(attachment.originalImage, "originalImage")
  89 |     }
  90 |     
  91 |     static func testTextBundleAttachment() throws {
  92 |         let content = "# Code content\nlet x = 1"
  93 |         let source = "my-project"
  94 |         let count = 42
  95 |         let id = UUID()
  96 |         
  97 |         let attachment = Attachment.textBundle(content, source, count, id)
  98 |         
  99 |         try assertEqual(attachment.id, id, "ID")
 100 |         try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
 101 |         try assertEqual(attachment.fileName, source, "fileName")
 102 |         try assertTrue(attachment.isTextBundle, "isTextBundle")
 103 |         try assertEqual(attachment.textContent, content, "textContent")
 104 |     }
 105 |     
 106 |     static func testVideoDetection() throws {
 107 |         let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
 108 |         let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
 109 |         let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
 110 |         
 111 |         try assertTrue(mp4.isVideo, "mp4 should be video")
 112 |         try assertTrue(mov.isVideo, "mov should be video")
 113 |         try assertFalse(txt.isVideo, "txt should not be video")
 114 |     }
 115 |     
 116 |     static func testEqualityById() throws {
 117 |         let id = UUID()
 118 |         let image1 = NSImage(size: NSSize(width: 100, height: 100))
 119 |         let image2 = NSImage(size: NSSize(width: 200, height: 200))
 120 |         
 121 |         let att1 = Attachment.image(image1, nil, id)
 122 |         let att2 = Attachment.image(image2, nil, id)
 123 |         let att3 = Attachment.image(image1, nil, UUID())
 124 |         
 125 |         try assertTrue(att1 == att2, "Same ID should be equal")
 126 |         try assertFalse(att1 == att3, "Different ID should not be equal")
 127 |     }
 128 |     
 129 |     // MARK: - Test Cases: Thumbnail Generation
 130 |     
 131 |     static func testThumbnailResizesLarge() throws {
 132 |         let large = createTestImage(width: 2000, height: 1000)
 133 |         let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
 134 |         
 135 |         try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
 136 |         try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
 137 |     }
 138 |     
 139 |     static func testThumbnailPreservesRatio() throws {
 140 |         let image = createTestImage(width: 2000, height: 1000)
 141 |         let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
 142 |         
 143 |         let ratio = thumb.size.width / thumb.size.height
 144 |         try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
 145 |     }
 146 |     
 147 |     static func testThumbnailNoUpscale() throws {
 148 |         let small = createTestImage(width: 50, height: 50)
 149 |         let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
 150 |         
 151 |         try assertEqual(thumb.size.width, 50, "Width")
 152 |         try assertEqual(thumb.size.height, 50, "Height")
 153 |     }
 154 |     
 155 |     static func testThumbnailZeroSize() throws {
 156 |         let zero = NSImage(size: NSSize(width: 0, height: 0))
 157 |         let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
 158 |         
 159 |         try assertEqual(thumb.size.width, 0, "Width")
 160 |     }
 161 |     
 162 |     // MARK: - Helpers
 163 |     
 164 |     static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
 165 |         let image = NSImage(size: NSSize(width: width, height: height))
 166 |         image.lockFocus()
 167 |         NSColor.red.setFill()
 168 |         NSRect(x: 0, y: 0, width: width, height: height).fill()
 169 |         image.unlockFocus()
 170 |         return image
 171 |     }
 172 | }
 173 | 
 174 | // MARK: - Attachment Type (简化版，用于测试)
 175 | 
 176 | import UniformTypeIdentifiers
 177 | 
 178 | enum Attachment: Identifiable, Equatable {
 179 |     case image(NSImage, NSImage?, UUID)
 180 |     case screenshot(NSImage, NSImage?, UUID)
 181 |     case file(URL, UUID)
 182 |     case textBundle(String, String, Int, UUID)
 183 |     
 184 |     var id: UUID {
 185 |         switch self {
 186 |         case .image(_, _, let id), .screenshot(_, _, let id),
 187 |              .file(_, let id), .textBundle(_, _, _, let id):
 188 |             return id
 189 |         }
 190 |     }
 191 |     
 192 |     var thumbnail: NSImage? {
 193 |         switch self {
 194 |         case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
 195 |         default: return nil
 196 |         }
 197 |     }
 198 |     
 199 |     var originalImage: NSImage? {
 200 |         switch self {
 201 |         case .image(let img, _, _), .screenshot(let img, _, _): return img
 202 |         default: return nil
 203 |         }
 204 |     }
 205 |     
 206 |     var fileName: String? {
 207 |         switch self {
 208 |         case .file(let url, _): return url.lastPathComponent
 209 |         case .textBundle(_, let source, _, _): return source
 210 |         default: return nil
 211 |         }
 212 |     }
 213 |     
 214 |     var displayTitle: String {
 215 |         switch self {
 216 |         case .image: return "图片"
 217 |         case .screenshot: return "截图"
 218 |         case .file(let url, _): return url.lastPathComponent
 219 |         case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
 220 |         }
 221 |     }
 222 |     
 223 |     var isVideo: Bool {
 224 |         if case .file(let url, _) = self,
 225 |            let uti = UTType(filenameExtension: url.pathExtension) {
 226 |             return uti.conforms(to: .movie) || uti.conforms(to: .video)
 227 |         }
 228 |         return false
 229 |     }
 230 |     
 231 |     var isTextBundle: Bool {
 232 |         if case .textBundle = self { return true }
 233 |         return false
 234 |     }
 235 |     
 236 |     var textContent: String? {
 237 |         if case .textBundle(let content, _, _, _) = self { return content }
 238 |         return nil
 239 |     }
 240 |     
 241 |     static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
 242 |     
 243 |     static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
 244 |         let size = image.size
 245 |         guard size.width > 0 && size.height > 0 else { return image }
 246 |         
 247 |         let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
 248 |         let newSize = NSSize(width: size.width * scale, height: size.height * scale)
 249 |         
 250 |         let thumbnail = NSImage(size: newSize)
 251 |         thumbnail.lockFocus()
 252 |         image.draw(in: NSRect(origin: .zero, size: newSize),
 253 |                    from: NSRect(origin: .zero, size: size),
 254 |                    operation: .copy, fraction: 1.0)
 255 |         thumbnail.unlockFocus()
 256 |         return thumbnail
 257 |     }
 258 | }
 259 | 
 260 | // MARK: - Assertion Helpers
 261 | 
 262 | struct TestError: Error, CustomStringConvertible {
 263 |     let message: String
 264 |     init(_ message: String) { self.message = message }
 265 |     var description: String { message }
 266 | }
 267 | 
 268 | func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
 269 |     if actual != expected {
 270 |         throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
 271 |     }
 272 | }
 273 | 
 274 | func assertTrue(_ condition: Bool, _ message: String) throws {
 275 |     if !condition { throw TestError(message) }
 276 | }
 277 | 
 278 | func assertFalse(_ condition: Bool, _ message: String) throws {
 279 |     if condition { throw TestError(message) }
 280 | }
 281 | 
 282 | func assertNil<T>(_ value: T?, _ message: String) throws {
 283 |     if value != nil { throw TestError("\(message) 应该是 nil") }
 284 | }
 285 | 
 286 | func assertNotNil<T>(_ value: T?, _ message: String) throws {
 287 |     if value == nil { throw TestError("\(message) 不应该是 nil") }
 288 | }
 289 | 
 290 | extension String {
 291 |     static func * (string: String, count: Int) -> String {
 292 |         String(repeating: string, count: count)
 293 |     }
 294 | }

```

`spoke/Tests/EdgeTTSTests.swift`:

```swift
   1 | import Foundation
   2 | import AVFoundation
   3 | 
   4 | // MARK: - Edge TTS 单元测试
   5 | 
   6 | @main
   7 | struct EdgeTTSTests {
   8 |     static func main() async {
   9 |         print("🧪 Edge TTS 单元测试")
  10 |         print("=" * 50)
  11 |         
  12 |         await testSynthesizeAndPlay()
  13 |     }
  14 |     
  15 |     /// 测试合成并播放
  16 |     static func testSynthesizeAndPlay() async {
  17 |         print("\n📝 测试: 合成并播放")
  18 |         
  19 |         let text = "你好，这是语音合成测试。"
  20 |         let voice = "zh-CN-XiaoxiaoNeural"
  21 |         
  22 |         do {
  23 |             // 1. 合成音频
  24 |             print("   正在合成...")
  25 |             let audioData = try await synthesize(text: text, voice: voice)
  26 |             print("   ✅ 合成完成: \(audioData.count) bytes")
  27 |             
  28 |             // 2. 检查音频头
  29 |             print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
  30 |             
  31 |             // 3. 保存到文件测试
  32 |             let tempPath = "/tmp/edge_tts_test.mp3"
  33 |             try audioData.write(to: URL(fileURLWithPath: tempPath))
  34 |             print("   ✅ 已保存到: \(tempPath)")
  35 |             
  36 |             // 4. 用 AVAudioPlayer 播放
  37 |             print("   正在播放...")
  38 |             let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
  39 |             player.prepareToPlay()
  40 |             player.play()
  41 |             
  42 |             // 等待播放完成
  43 |             while player.isPlaying {
  44 |                 try await Task.sleep(nanoseconds: 100_000_000)
  45 |             }
  46 |             print("   ✅ 播放完成!")
  47 |             
  48 |         } catch {
  49 |             print("   ❌ 错误: \(error)")
  50 |         }
  51 |     }
  52 |     
  53 |     /// 合成音频
  54 |     static func synthesize(text: String, voice: String) async throws -> Data {
  55 |         // DRM Token
  56 |         let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
  57 |         let chromiumVersion = "130.0.2849.68"
  58 |         let windowsFileTimeEpoch: Int64 = 11_644_473_600
  59 |         
  60 |         let currentTime = Int64(Date().timeIntervalSince1970)
  61 |         let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
  62 |         let roundedTicks = ticks - (ticks % 3_000_000_000)
  63 |         let strToHash = "\(roundedTicks)\(trustedClientToken)"
  64 |         
  65 |         // SHA256
  66 |         import CryptoKit
  67 |         let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
  68 |         let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
  69 |         
  70 |         // URL
  71 |         let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
  72 |         let url = URL(string: urlString)!
  73 |         
  74 |         // WebSocket
  75 |         var request = URLRequest(url: url)
  76 |         request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
  77 |         request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
  78 |         
  79 |         let session = URLSession.shared
  80 |         let ws = session.webSocketTask(with: request)
  81 |         ws.resume()
  82 |         
  83 |         // 等待连接
  84 |         try await Task.sleep(nanoseconds: 500_000_000)
  85 |         
  86 |         // 发送配置
  87 |         let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
  88 |         try await ws.send(.string(configMessage))
  89 |         
  90 |         // 发送 SSML
  91 |         let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
  92 |         let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
  93 |         try await ws.send(.string(ssmlMessage))
  94 |         
  95 |         // 接收音频
  96 |         var audioData = Data()
  97 |         
  98 |         while true {
  99 |             let message = try await ws.receive()
 100 |             
 101 |             switch message {
 102 |             case .data(let data):
 103 |                 // 检查是否包含 Path:audio
 104 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 105 |                     if let range = str.range(of: "Path:audio\r\n") {
 106 |                         let offset = range.upperBound.utf16Offset(in: str)
 107 |                         audioData.append(data[offset...])
 108 |                     }
 109 |                 } else {
 110 |                     audioData.append(data)
 111 |                 }
 112 |                 
 113 |             case .string(let str):
 114 |                 if str.contains("Path:turn.end") {
 115 |                     ws.cancel(with: .goingAway, reason: nil)
 116 |                     return audioData
 117 |                 }
 118 |                 
 119 |             @unknown default:
 120 |                 break
 121 |             }
 122 |         }
 123 |     }
 124 | }
 125 | 
 126 | extension String {
 127 |     static func * (string: String, count: Int) -> String {
 128 |         String(repeating: string, count: count)
 129 |     }
 130 | }

```

`spoke/Tests/TextExtractionTests.swift`:

```swift
   1 | import Foundation
   2 | 
   3 | // MARK: - Text Extraction Service Tests
   4 | 
   5 | /// 独立运行的测试脚本
   6 | /// 用法: swift Tests/TextExtractionTests.swift
   7 | @main
   8 | struct TextExtractionTests {
   9 |     
  10 |     static var tempDirectory: URL!
  11 |     static var passCount = 0
  12 |     static var failCount = 0
  13 |     
  14 |     static func main() async {
  15 |         print("🧪 TextExtractionService 单元测试")
  16 |         print("=" * 50)
  17 |         
  18 |         // 创建临时目录
  19 |         tempDirectory = FileManager.default.temporaryDirectory
  20 |             .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
  21 |         try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  22 |         
  23 |         defer {
  24 |             // 清理
  25 |             try? FileManager.default.removeItem(at: tempDirectory)
  26 |             print("\n" + "=" * 50)
  27 |             print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  28 |         }
  29 |         
  30 |         // 运行测试
  31 |         await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
  32 |         await runTest("单文件提取") { try await testSingleFileExtraction() }
  33 |         await runTest("多文件合并") { try await testMultipleFilesExtraction() }
  34 |         await runTest("排除 node_modules") { try await testExcludesNodeModules() }
  35 |         await runTest("排除锁文件") { try await testExcludesLockFiles() }
  36 |         await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
  37 |         await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
  38 |         await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
  39 |         await runTest("添加行号") { try await testAddsLineNumbers() }
  40 |         await runTest("目录结构输出") { try await testDirectoryStructure() }
  41 |         await runTest("ZIP 提取") { try await testZIPExtraction() }
  42 |     }
  43 |     
  44 |     // MARK: - Test Runner
  45 |     
  46 |     static func runTest(_ name: String, _ test: () async throws -> Void) async {
  47 |         print("\n📝 测试: \(name)")
  48 |         do {
  49 |             try await test()
  50 |             print("   ✅ 通过")
  51 |             passCount += 1
  52 |         } catch {
  53 |             print("   ❌ 失败: \(error)")
  54 |             failCount += 1
  55 |         }
  56 |     }
  57 |     
  58 |     // MARK: - Helpers
  59 |     
  60 |     static func createFile(name: String, content: String) throws -> URL {
  61 |         let fileURL = tempDirectory.appendingPathComponent(name)
  62 |         let dir = fileURL.deletingLastPathComponent()
  63 |         try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  64 |         try content.write(to: fileURL, atomically: true, encoding: .utf8)
  65 |         return fileURL
  66 |     }
  67 |     
  68 |     static func createDirectory(name: String) throws -> URL {
  69 |         let dirURL = tempDirectory.appendingPathComponent(name)
  70 |         try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
  71 |         return dirURL
  72 |     }
  73 |     
  74 |     // MARK: - Test Cases
  75 |     
  76 |     static func testCodeExtensions() async throws {
  77 |         // 创建各种代码文件
  78 |         _ = try createFile(name: "test.swift", content: "let x = 1")
  79 |         _ = try createFile(name: "app.js", content: "const x = 1")
  80 |         _ = try createFile(name: "main.py", content: "x = 1")
  81 |         _ = try createFile(name: "README.md", content: "# Title")
  82 |         
  83 |         let result = await extractFromFolder(tempDirectory)
  84 |         guard case .success(let bundle) = result else {
  85 |             throw TestError("提取失败")
  86 |         }
  87 |         
  88 |         guard bundle.fileCount == 4 else {
  89 |             throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
  90 |         }
  91 |     }
  92 |     
  93 |     static func testSingleFileExtraction() async throws {
  94 |         // 清理并创建新目录
  95 |         try FileManager.default.removeItem(at: tempDirectory)
  96 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  97 |         
  98 |         _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
  99 |         
 100 |         let result = await extractFromFolder(tempDirectory)
 101 |         guard case .success(let bundle) = result else {
 102 |             throw TestError("提取失败")
 103 |         }
 104 |         
 105 |         guard bundle.fileCount == 1 else {
 106 |             throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
 107 |         }
 108 |         guard bundle.content.contains("print(\"Hello\")") else {
 109 |             throw TestError("内容不包含预期文本")
 110 |         }
 111 |     }
 112 |     
 113 |     static func testMultipleFilesExtraction() async throws {
 114 |         try FileManager.default.removeItem(at: tempDirectory)
 115 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 116 |         
 117 |         _ = try createFile(name: "a.swift", content: "let a = 1")
 118 |         _ = try createFile(name: "b.swift", content: "let b = 2")
 119 |         _ = try createFile(name: "c.js", content: "const c = 3")
 120 |         
 121 |         let result = await extractFromFolder(tempDirectory)
 122 |         guard case .success(let bundle) = result else {
 123 |             throw TestError("提取失败")
 124 |         }
 125 |         
 126 |         guard bundle.fileCount == 3 else {
 127 |             throw TestError("文件数量错误")
 128 |         }
 129 |         guard bundle.content.contains("let a = 1") &&
 130 |               bundle.content.contains("let b = 2") &&
 131 |               bundle.content.contains("const c = 3") else {
 132 |             throw TestError("内容缺失")
 133 |         }
 134 |     }
 135 |     
 136 |     static func testExcludesNodeModules() async throws {
 137 |         try FileManager.default.removeItem(at: tempDirectory)
 138 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 139 |         
 140 |         let nodeModules = try createDirectory(name: "node_modules")
 141 |         try "const secret = 'password'".write(
 142 |             to: nodeModules.appendingPathComponent("secret.js"),
 143 |             atomically: true, encoding: .utf8
 144 |         )
 145 |         _ = try createFile(name: "app.js", content: "const app = 1")
 146 |         
 147 |         let result = await extractFromFolder(tempDirectory)
 148 |         guard case .success(let bundle) = result else {
 149 |             throw TestError("提取失败")
 150 |         }
 151 |         
 152 |         guard bundle.fileCount == 1 else {
 153 |             throw TestError("应该只包含 app.js")
 154 |         }
 155 |         guard !bundle.content.contains("secret") else {
 156 |             throw TestError("不应包含 node_modules 内容")
 157 |         }
 158 |     }
 159 |     
 160 |     static func testExcludesLockFiles() async throws {
 161 |         try FileManager.default.removeItem(at: tempDirectory)
 162 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 163 |         
 164 |         _ = try createFile(name: "package-lock.json", content: "{}")
 165 |         _ = try createFile(name: "yarn.lock", content: "")
 166 |         _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
 167 |         
 168 |         let result = await extractFromFolder(tempDirectory)
 169 |         guard case .success(let bundle) = result else {
 170 |             throw TestError("提取失败")
 171 |         }
 172 |         
 173 |         guard bundle.fileCount == 1 else {
 174 |             throw TestError("应该只包含 package.json")
 175 |         }
 176 |     }
 177 |     
 178 |     static func testNestedDirectories() async throws {
 179 |         try FileManager.default.removeItem(at: tempDirectory)
 180 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 181 |         
 182 |         _ = try createFile(name: "root.swift", content: "let root = 1")
 183 |         _ = try createFile(name: "src/app.swift", content: "let src = 2")
 184 |         _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
 185 |         
 186 |         let result = await extractFromFolder(tempDirectory)
 187 |         guard case .success(let bundle) = result else {
 188 |             throw TestError("提取失败")
 189 |         }
 190 |         
 191 |         guard bundle.fileCount == 3 else {
 192 |             throw TestError("应该包含 3 个文件")
 193 |         }
 194 |         guard bundle.content.contains("let root = 1") &&
 195 |               bundle.content.contains("let src = 2") &&
 196 |               bundle.content.contains("let lib = 3") else {
 197 |             throw TestError("缺少嵌套目录内容")
 198 |         }
 199 |     }
 200 |     
 201 |     static func testEmptyFolderError() async throws {
 202 |         try FileManager.default.removeItem(at: tempDirectory)
 203 |         let emptyDir = try createDirectory(name: "empty")
 204 |         
 205 |         let result = await extractFromFolder(emptyDir)
 206 |         guard case .failure = result else {
 207 |             throw TestError("空文件夹应该返回错误")
 208 |         }
 209 |     }
 210 |     
 211 |     static func testIgnoresNonCodeFiles() async throws {
 212 |         try FileManager.default.removeItem(at: tempDirectory)
 213 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 214 |         
 215 |         _ = try createFile(name: "image.png", content: "fake")
 216 |         _ = try createFile(name: "video.mp4", content: "fake")
 217 |         _ = try createFile(name: "main.swift", content: "let x = 1")
 218 |         
 219 |         let result = await extractFromFolder(tempDirectory)
 220 |         guard case .success(let bundle) = result else {
 221 |             throw TestError("提取失败")
 222 |         }
 223 |         
 224 |         guard bundle.fileCount == 1 else {
 225 |             throw TestError("应该只包含 .swift 文件")
 226 |         }
 227 |     }
 228 |     
 229 |     static func testAddsLineNumbers() async throws {
 230 |         try FileManager.default.removeItem(at: tempDirectory)
 231 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 232 |         
 233 |         _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
 234 |         
 235 |         let result = await extractFromFolder(tempDirectory)
 236 |         guard case .success(let bundle) = result else {
 237 |             throw TestError("提取失败")
 238 |         }
 239 |         
 240 |         guard bundle.content.contains("1│") &&
 241 |               bundle.content.contains("2│") &&
 242 |               bundle.content.contains("3│") else {
 243 |             throw TestError("缺少行号")
 244 |         }
 245 |     }
 246 |     
 247 |     static func testDirectoryStructure() async throws {
 248 |         try FileManager.default.removeItem(at: tempDirectory)
 249 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 250 |         
 251 |         _ = try createFile(name: "main.swift", content: "entry")
 252 |         _ = try createFile(name: "src/app.swift", content: "code")
 253 |         
 254 |         let result = await extractFromFolder(tempDirectory)
 255 |         guard case .success(let bundle) = result else {
 256 |             throw TestError("提取失败")
 257 |         }
 258 |         
 259 |         guard bundle.content.contains("# 目录结构") else {
 260 |             throw TestError("缺少目录结构标题")
 261 |         }
 262 |     }
 263 |     
 264 |     static func testZIPExtraction() async throws {
 265 |         try FileManager.default.removeItem(at: tempDirectory)
 266 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 267 |         
 268 |         // 创建源文件
 269 |         let sourceDir = try createDirectory(name: "source")
 270 |         try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
 271 |         
 272 |         // 创建 ZIP
 273 |         let zipPath = tempDirectory.appendingPathComponent("test.zip")
 274 |         let process = Process()
 275 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
 276 |         process.currentDirectoryURL = tempDirectory
 277 |         process.arguments = ["-r", zipPath.path, "source"]
 278 |         process.standardOutput = FileHandle.nullDevice
 279 |         process.standardError = FileHandle.nullDevice
 280 |         try process.run()
 281 |         process.waitUntilExit()
 282 |         
 283 |         guard process.terminationStatus == 0 else {
 284 |             throw TestError("创建 ZIP 失败")
 285 |         }
 286 |         
 287 |         let result = await extractFromZIP(zipPath)
 288 |         guard case .success(let bundle) = result else {
 289 |             throw TestError("ZIP 提取失败")
 290 |         }
 291 |         
 292 |         guard bundle.fileCount == 1 else {
 293 |             throw TestError("ZIP 文件数量错误")
 294 |         }
 295 |         guard bundle.content.contains("let x = 1") else {
 296 |             throw TestError("ZIP 内容缺失")
 297 |         }
 298 |     }
 299 | }
 300 | 
 301 | // MARK: - TextExtractionService (简化版，用于测试)
 302 | 
 303 | struct TextBundle {
 304 |     let content: String
 305 |     let fileCount: Int
 306 |     let sourcePath: String
 307 |     let files: [String]
 308 | }
 309 | 
 310 | enum TextExtractionError: Error, Equatable {
 311 |     case folderNotFound
 312 |     case zipExtractionFailed(String)
 313 |     case noTextFilesFound
 314 |     case accessDenied
 315 | }
 316 | 
 317 | func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
 318 |     let codeExtensions: Set<String> = [
 319 |         "js", "jsx", "ts", "tsx", "mjs", "cjs",
 320 |         "html", "htm", "css", "scss", "less", "vue", "svelte",
 321 |         "py", "pyw", "pyi",
 322 |         "java", "kt", "kts", "scala",
 323 |         "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
 324 |         "rs", "go", "rb", "erb", "php", "swift",
 325 |         "sh", "bash", "zsh", "fish",
 326 |         "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
 327 |         "md", "mdx", "txt", "rst", "asciidoc",
 328 |         "sql", "graphql", "proto", "dockerfile"
 329 |     ]
 330 |     
 331 |     let excludedDirs: Set<String> = [
 332 |         "node_modules", ".git", ".svn", ".hg",
 333 |         "dist", "build", "target", ".next", ".nuxt",
 334 |         "__pycache__", ".pytest_cache", ".tox",
 335 |         "venv", "env", ".env", ".venv",
 336 |         "vendor", "Pods", "Carthage",
 337 |         ".idea", ".vscode", ".vs"
 338 |     ]
 339 |     
 340 |     let excludedFiles: Set<String> = [
 341 |         ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
 342 |         "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
 343 |         "Podfile.lock", "Gemfile.lock", "Cargo.lock"
 344 |     ]
 345 |     
 346 |     // 递归收集文件
 347 |     func collectFiles(in directory: URL) -> [URL] {
 348 |         var result: [URL] = []
 349 |         let fm = FileManager.default
 350 |         
 351 |         guard let contents = try? fm.contentsOfDirectory(
 352 |             at: directory,
 353 |             includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
 354 |             options: [.skipsHiddenFiles]
 355 |         ) else { return [] }
 356 |         
 357 |         for url in contents {
 358 |             let fileName = url.lastPathComponent
 359 |             if excludedFiles.contains(fileName) { continue }
 360 |             
 361 |             let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
 362 |             
 363 |             if values?.isDirectory == true {
 364 |                 if !excludedDirs.contains(fileName) {
 365 |                     result.append(contentsOf: collectFiles(in: url))
 366 |                 }
 367 |             } else if values?.isRegularFile == true {
 368 |                 let ext = url.pathExtension.lowercased()
 369 |                 if codeExtensions.contains(ext) {
 370 |                     result.append(url)
 371 |                 }
 372 |             }
 373 |         }
 374 |         return result.sorted { $0.path < $1.path }
 375 |     }
 376 |     
 377 |     let files = collectFiles(in: folderURL)
 378 |     guard !files.isEmpty else {
 379 |         return .failure(.noTextFilesFound)
 380 |     }
 381 |     
 382 |     // 合并内容
 383 |     var parts: [String] = ["# 目录结构\n```"]
 384 |     for file in files {
 385 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 386 |         parts.append(rel)
 387 |     }
 388 |     parts.append("```\n\n# 文件内容\n")
 389 |     
 390 |     for file in files {
 391 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 392 |         let ext = file.pathExtension
 393 |         if let content = try? String(contentsOf: file, encoding: .utf8) {
 394 |             let numbered = content.components(separatedBy: .newlines).enumerated()
 395 |                 .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
 396 |             parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
 397 |         }
 398 |     }
 399 |     
 400 |     return .success(TextBundle(
 401 |         content: parts.joined(separator: "\n"),
 402 |         fileCount: files.count,
 403 |         sourcePath: folderURL.path,
 404 |         files: files.map { $0.path }
 405 |     ))
 406 | }
 407 | 
 408 | func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
 409 |     let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
 410 |     try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
 411 |     defer { try? FileManager.default.removeItem(at: tempDir) }
 412 |     
 413 |     let process = Process()
 414 |     process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
 415 |     process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
 416 |     process.standardOutput = FileHandle.nullDevice
 417 |     process.standardError = FileHandle.nullDevice
 418 |     
 419 |     do {
 420 |         try process.run()
 421 |         process.waitUntilExit()
 422 |         
 423 |         guard process.terminationStatus == 0 else {
 424 |             return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
 425 |         }
 426 |         
 427 |         return await extractFromFolder(tempDir)
 428 |     } catch {
 429 |         return .failure(.zipExtractionFailed(error.localizedDescription))
 430 |     }
 431 | }
 432 | 
 433 | // MARK: - Helpers
 434 | 
 435 | struct TestError: Error, CustomStringConvertible {
 436 |     let message: String
 437 |     init(_ message: String) { self.message = message }
 438 |     var description: String { message }
 439 | }
 440 | 
 441 | extension String {
 442 |     static func * (string: String, count: Int) -> String {
 443 |         String(repeating: string, count: count)
 444 |     }
 445 | }

```

`spoke/Tests/run-tests.sh`:

```sh
   1 | #!/bin/bash
   2 | # 运行所有单元测试
   3 | # 用法: ./Tests/run-tests.sh
   4 | 
   5 | set -e
   6 | 
   7 | cd "$(dirname "$0")/.."
   8 | 
   9 | echo "🧪 运行所有单元测试"
  10 | echo "=================================="
  11 | 
  12 | # 编译并运行 TextExtractionTests
  13 | echo ""
  14 | echo "📦 编译 TextExtractionTests..."
  15 | swiftc -parse-as-library -o /tmp/text_extraction_tests Tests/TextExtractionTests.swift
  16 | echo "🚀 运行测试..."
  17 | /tmp/text_extraction_tests
  18 | 
  19 | echo ""
  20 | echo "=================================="
  21 | 
  22 | # 编译并运行 AttachmentTests
  23 | echo ""
  24 | echo "📦 编译 AttachmentTests..."
  25 | swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift
  26 | echo "🚀 运行测试..."
  27 | /tmp/attachment_tests
  28 | 
  29 | echo ""
  30 | echo "=================================="
  31 | echo "🎉 所有测试完成!"

```

`spoke/Tests/test_edge_tts.swift`:

```swift
   1 | #!/usr/bin/env swift
   2 | 
   3 | import Foundation
   4 | import CryptoKit
   5 | import AVFoundation
   6 | 
   7 | // MARK: - Edge TTS 测试脚本
   8 | 
   9 | print("🧪 Edge TTS 测试")
  10 | print(String(repeating: "=", count: 50))
  11 | 
  12 | // 配置
  13 | let text = "你好，这是语音合成测试。Hello, this is a test."
  14 | let voice = "zh-CN-XiaoxiaoNeural"
  15 | let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
  16 | let chromiumVersion = "130.0.2849.68"
  17 | let windowsFileTimeEpoch: Int64 = 11_644_473_600
  18 | 
  19 | // 生成 DRM Token
  20 | func generateSecMsGecToken() -> String {
  21 |     let currentTime = Int64(Date().timeIntervalSince1970)
  22 |     let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
  23 |     let roundedTicks = ticks - (ticks % 3_000_000_000)
  24 |     let strToHash = "\(roundedTicks)\(trustedClientToken)"
  25 |     let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
  26 |     return hash.map { String(format: "%02X", $0) }.joined()
  27 | }
  28 | 
  29 | // WebSocket Delegate
  30 | class WSDelegate: NSObject, URLSessionWebSocketDelegate {
  31 |     var onOpen: (() -> Void)?
  32 |     
  33 |     func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
  34 |         print("   ✅ WebSocket 已连接")
  35 |         onOpen?()
  36 |     }
  37 | }
  38 | 
  39 | // 主测试
  40 | func runTest() async {
  41 |     print("\n📝 测试文本: \(text)")
  42 |     print("🎤 语音: \(voice)")
  43 |     
  44 |     // 构建 URL
  45 |     let secMsGec = generateSecMsGecToken()
  46 |     let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
  47 |     
  48 |     guard let url = URL(string: urlString) else {
  49 |         print("❌ URL 无效")
  50 |         return
  51 |     }
  52 |     
  53 |     // 创建 WebSocket
  54 |     print("\n🔗 正在连接...")
  55 |     var request = URLRequest(url: url)
  56 |     request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
  57 |     request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
  58 |     
  59 |     let delegate = WSDelegate()
  60 |     let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
  61 |     let ws = session.webSocketTask(with: request)
  62 |     
  63 |     // 等待连接
  64 |     await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
  65 |         delegate.onOpen = { cont.resume() }
  66 |         ws.resume()
  67 |     }
  68 |     
  69 |     // 发送配置
  70 |     print("📤 发送配置...")
  71 |     let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
  72 |     do {
  73 |         try await ws.send(.string(configMessage))
  74 |         print("   ✅ 配置已发送")
  75 |     } catch {
  76 |         print("   ❌ 发送配置失败: \(error)")
  77 |         return
  78 |     }
  79 |     
  80 |     // 发送 SSML
  81 |     print("📤 发送 SSML...")
  82 |     let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
  83 |     let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
  84 |     do {
  85 |         try await ws.send(.string(ssmlMessage))
  86 |         print("   ✅ SSML 已发送")
  87 |     } catch {
  88 |         print("   ❌ 发送 SSML 失败: \(error)")
  89 |         return
  90 |     }
  91 |     
  92 |     // 接收音频
  93 |     print("\n📥 接收音频数据...")
  94 |     var audioData = Data()
  95 |     var messageCount = 0
  96 |     
  97 |     while true {
  98 |         do {
  99 |             let message = try await ws.receive()
 100 |             messageCount += 1
 101 |             
 102 |             switch message {
 103 |             case .data(let data):
 104 |                 // 尝试解析为字符串查看内容
 105 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 106 |                     // 找到音频分隔符后的数据
 107 |                     if let range = str.range(of: "Path:audio\r\n") {
 108 |                         let offset = range.upperBound.utf16Offset(in: str)
 109 |                         let audioChunk = data.suffix(from: offset)
 110 |                         audioData.append(audioChunk)
 111 |                         print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
 112 |                     }
 113 |                 } else {
 114 |                     // 纯二进制音频
 115 |                     audioData.append(data)
 116 |                     print("   收到音频块 #\(messageCount): \(data.count) bytes")
 117 |                 }
 118 |                 
 119 |             case .string(let str):
 120 |                 if str.contains("Path:turn.end") {
 121 |                     print("   ✅ 收到结束信号")
 122 |                     break
 123 |                 } else if str.contains("Path:audio.metadata") {
 124 |                     print("   收到元数据")
 125 |                 } else {
 126 |                     print("   收到文本: \(str.prefix(50))...")
 127 |                 }
 128 |                 continue
 129 |                 
 130 |             @unknown default:
 131 |                 continue
 132 |             }
 133 |             
 134 |             if messageCount > 100 { break } // 防止死循环
 135 |             
 136 |         } catch {
 137 |             print("   ⚠️ 接收错误: \(error)")
 138 |             break
 139 |         }
 140 |     }
 141 |     
 142 |     ws.cancel(with: .goingAway, reason: nil)
 143 |     
 144 |     print("\n📊 结果:")
 145 |     print("   总消息数: \(messageCount)")
 146 |     print("   音频大小: \(audioData.count) bytes")
 147 |     
 148 |     if audioData.isEmpty {
 149 |         print("   ❌ 没有收到音频数据")
 150 |         return
 151 |     }
 152 |     
 153 |     // 检查音频头
 154 |     let header = audioData.prefix(16)
 155 |     print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
 156 |     
 157 |     // MP3 文件应该以 FF FB 或 ID3 开头
 158 |     if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
 159 |         print("   ✅ 看起来是有效的 MP3 格式")
 160 |     } else {
 161 |         print("   ⚠️ 可能不是标准 MP3 格式")
 162 |     }
 163 |     
 164 |     // 保存到文件
 165 |     let tempPath = "/tmp/edge_tts_test.mp3"
 166 |     do {
 167 |         try audioData.write(to: URL(fileURLWithPath: tempPath))
 168 |         print("\n💾 已保存到: \(tempPath)")
 169 |     } catch {
 170 |         print("   ❌ 保存失败: \(error)")
 171 |         return
 172 |     }
 173 |     
 174 |     // 播放测试
 175 |     print("\n🔊 播放测试...")
 176 |     do {
 177 |         let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
 178 |         player.prepareToPlay()
 179 |         
 180 |         if player.play() {
 181 |             print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
 182 |             
 183 |             // 等待播放完成
 184 |             while player.isPlaying {
 185 |                 try await Task.sleep(nanoseconds: 100_000_000)
 186 |             }
 187 |             print("   ✅ 播放完成!")
 188 |         } else {
 189 |             print("   ❌ 播放启动失败")
 190 |         }
 191 |     } catch {
 192 |         print("   ❌ 播放错误: \(error)")
 193 |         
 194 |         // 尝试用 afplay 播放
 195 |         print("\n🔧 尝试用 afplay 播放...")
 196 |         let process = Process()
 197 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
 198 |         process.arguments = [tempPath]
 199 |         try? process.run()
 200 |         process.waitUntilExit()
 201 |         
 202 |         if process.terminationStatus == 0 {
 203 |             print("   ✅ afplay 播放成功!")
 204 |         } else {
 205 |             print("   ❌ afplay 也失败了")
 206 |         }
 207 |     }
 208 | }
 209 | 
 210 | // 运行测试
 211 | Task {
 212 |     await runTest()
 213 |     exit(0)
 214 | }
 215 | 
 216 | // 保持运行
 217 | RunLoop.main.run()

```

`spoke/docs/code2prompt-output/lucid-config.md`:

```md
   1 | Project Path: spoke
   2 | 
   3 | Source Tree:
   4 | 
   5 | ```txt
   6 | spoke
   7 | └── Package.swift
   8 | 
   9 | ```
  10 | 
  11 | `spoke/Package.swift`:
  12 | 
  13 | ```swift
  14 |    1 | // swift-tools-version: 5.9
  15 |    2 | import PackageDescription
  16 |    3 | 
  17 |    4 | let package = Package(
  18 |    5 |     name: "SpokenAnyWhere",
  19 |    6 |     platforms: [
  20 |    7 |         .macOS(.v14)
  21 |    8 |     ],
  22 |    9 |     products: [
  23 |   10 |         .executable(name: "SpokenAnyWhere", targets: ["SpokenAnyWhere"])
  24 |   11 |     ],
  25 |   12 |     dependencies: [],
  26 |   13 |     targets: [
  27 |   14 |         .executableTarget(
  28 |   15 |             name: "SpokenAnyWhere",
  29 |   16 |             dependencies: [],
  30 |   17 |             path: ".",
  31 |   18 |             exclude: ["Package.swift", "Resources/LocalModels", "Tests"],
  32 |   19 |             sources: ["App", "Core", "Services", "UI"]
  33 |   20 |         )
  34 |   21 |     ]
  35 |   22 | )
  36 | 
  37 | ```

```

`spoke/docs/code2prompt-output/lucid-docs.md`:

```md
   1 | Project Path: spoke
   2 | 
   3 | Source Tree:
   4 | 
   5 | ```txt
   6 | spoke
   7 | └── docs
   8 |     └── code2prompt-output
   9 |         ├── lucid-config.md
  10 |         ├── lucid-full.md
  11 |         └── lucid-source.md
  12 | 
  13 | ```
  14 | 
  15 | `spoke/docs/code2prompt-output/lucid-config.md`:
  16 | 
  17 | ```md
  18 | Project Path: spoke
  19 | 
  20 | Source Tree:
  21 | 
  22 | ```txt
  23 | spoke
  24 | └── Package.swift
  25 | 
  26 | ```
  27 | 
  28 | `spoke/Package.swift`:
  29 | 
  30 | ```swift
  31 |    1 | // swift-tools-version: 5.9
  32 |    2 | import PackageDescription
  33 |    3 | 
  34 |    4 | let package = Package(
  35 |    5 |     name: "SpokenAnyWhere",
  36 |    6 |     platforms: [
  37 |    7 |         .macOS(.v14)
  38 |    8 |     ],
  39 |    9 |     products: [
  40 |   10 |         .executable(name: "SpokenAnyWhere", targets: ["SpokenAnyWhere"])
  41 |   11 |     ],
  42 |   12 |     dependencies: [],
  43 |   13 |     targets: [
  44 |   14 |         .executableTarget(
  45 |   15 |             name: "SpokenAnyWhere",
  46 |   16 |             dependencies: [],
  47 |   17 |             path: ".",
  48 |   18 |             exclude: ["Package.swift", "Resources/LocalModels", "Tests"],
  49 |   19 |             sources: ["App", "Core", "Services", "UI"]
  50 |   20 |         )
  51 |   21 |     ]
  52 |   22 | )
  53 | 
  54 | ```
  55 | ```
  56 | 
  57 | `spoke/docs/code2prompt-output/lucid-full.md`:
  58 | 
  59 | ```md
  60 | Project Path: spoke
  61 | 
  62 | Source Tree:
  63 | 
  64 | ```txt
  65 | spoke
  66 | ├── App
  67 | │   ├── AppDelegate.swift
  68 | │   └── SpokenlyApp.swift
  69 | ├── Core
  70 | │   ├── Attachment
  71 | │   │   ├── Attachment.swift
  72 | │   │   ├── AttachmentManager.swift
  73 | │   │   ├── ScreenCaptureService.swift
  74 | │   │   └── TextExtractionService.swift
  75 | │   ├── Audio
  76 | │   │   └── AudioRecorderService.swift
  77 | │   ├── DataModels.swift
  78 | │   ├── LLM
  79 | │   │   ├── KeychainService.swift
  80 | │   │   ├── LLMPipeline.swift
  81 | │   │   ├── LLMProvider.swift
  82 | │   │   ├── LLMSettings.swift
  83 | │   │   └── OpenAICompatibleProvider.swift
  84 | │   ├── MessagePanel
  85 | │   │   └── MessagePanelState.swift
  86 | │   ├── QuickAsk
  87 | │   │   └── QuickAskState.swift
  88 | │   ├── RecordingState.swift
  89 | │   └── Transcription
  90 | │       ├── Providers
  91 | │       │   ├── SFSpeechProvider.swift
  92 | │       │   └── SpeechAnalyzerProvider.swift
  93 | │       ├── TranscriptionManager.swift
  94 | │       └── TranscriptionProvider.swift
  95 | ├── Package.swift
  96 | ├── Resources
  97 | │   └── LocalModels
  98 | ├── Services
  99 | │   ├── AppSettings.swift
 100 | │   ├── AudioDeviceManager.swift
 101 | │   ├── AudioPlayerService.swift
 102 | │   ├── ClipboardHistoryService.swift
 103 | │   ├── ContextService.swift
 104 | │   ├── DoubaoTTSService.swift
 105 | │   ├── EdgeTTSService.swift
 106 | │   ├── FloatingHUDManager.swift
 107 | │   ├── HistoryManager.swift
 108 | │   ├── HotKeyService.swift
 109 | │   ├── InputService.swift
 110 | │   ├── MessagePanelManager.swift
 111 | │   ├── QuickAskService.swift
 112 | │   ├── RecordingController.swift
 113 | │   └── TTSSettings.swift
 114 | ├── Tests
 115 | │   ├── AttachmentTests.swift
 116 | │   ├── EdgeTTSTests.swift
 117 | │   ├── TextExtractionTests.swift
 118 | │   ├── run-tests.sh
 119 | │   └── test_edge_tts.swift
 120 | ├── UI
 121 | │   ├── Components
 122 | │   │   ├── AttachmentDropOverlay.swift
 123 | │   │   ├── AttachmentPickerMenu.swift
 124 | │   │   └── AttachmentThumbnailView.swift
 125 | │   ├── HUD
 126 | │   │   ├── FloatingCapsuleView.swift
 127 | │   │   ├── FloatingPanel.swift
 128 | │   │   ├── HUDTheme.swift
 129 | │   │   ├── QuickAskCapsuleView.swift
 130 | │   │   └── QuickAskInputView.swift
 131 | │   ├── MessagePanel
 132 | │   │   └── MessagePanelView.swift
 133 | │   ├── QuickAsk
 134 | │   │   ├── AnswerPanelView.swift
 135 | │   │   └── MarkdownWebView.swift
 136 | │   └── Settings
 137 | │       └── SettingsView.swift
 138 | └── docs
 139 |     └── code2prompt-output
 140 | 
 141 | ```
 142 | 
 143 | `spoke/Tests/AttachmentTests.swift`:
 144 | 
 145 | ```swift
 146 |    1 | import Foundation
 147 |    2 | import AppKit
 148 |    3 | 
 149 |    4 | // MARK: - Attachment Tests
 150 |    5 | 
 151 |    6 | /// Attachment 类型单元测试
 152 |    7 | /// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
 153 |    8 | @main
 154 |    9 | struct AttachmentTests {
 155 |   10 |     
 156 |   11 |     static var passCount = 0
 157 |   12 |     static var failCount = 0
 158 |   13 |     
 159 |   14 |     static func main() async {
 160 |   15 |         print("🧪 Attachment 类型单元测试")
 161 |   16 |         print("=" * 50)
 162 |   17 |         
 163 |   18 |         // 运行测试
 164 |   19 |         runTest("Image 类型属性") { try testImageAttachment() }
 165 |   20 |         runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
 166 |   21 |         runTest("File 类型属性") { try testFileAttachment() }
 167 |   22 |         runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
 168 |   23 |         runTest("视频文件检测") { try testVideoDetection() }
 169 |   24 |         runTest("ID 相等性判断") { try testEqualityById() }
 170 |   25 |         runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
 171 |   26 |         runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
 172 |   27 |         runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
 173 |   28 |         runTest("缩略图处理空图") { try testThumbnailZeroSize() }
 174 |   29 |         
 175 |   30 |         print("\n" + "=" * 50)
 176 |   31 |         print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
 177 |   32 |     }
 178 |   33 |     
 179 |   34 |     // MARK: - Test Runner
 180 |   35 |     
 181 |   36 |     static func runTest(_ name: String, _ test: () throws -> Void) {
 182 |   37 |         print("\n📝 测试: \(name)")
 183 |   38 |         do {
 184 |   39 |             try test()
 185 |   40 |             print("   ✅ 通过")
 186 |   41 |             passCount += 1
 187 |   42 |         } catch {
 188 |   43 |             print("   ❌ 失败: \(error)")
 189 |   44 |             failCount += 1
 190 |   45 |         }
 191 |   46 |     }
 192 |   47 |     
 193 |   48 |     // MARK: - Test Cases: Attachment Types
 194 |   49 |     
 195 |   50 |     static func testImageAttachment() throws {
 196 |   51 |         let image = NSImage(size: NSSize(width: 100, height: 100))
 197 |   52 |         let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
 198 |   53 |         let id = UUID()
 199 |   54 |         
 200 |   55 |         let attachment = Attachment.image(image, thumbnail, id)
 201 |   56 |         
 202 |   57 |         try assertEqual(attachment.id, id, "ID")
 203 |   58 |         try assertEqual(attachment.displayTitle, "图片", "displayTitle")
 204 |   59 |         try assertNotNil(attachment.thumbnail, "thumbnail")
 205 |   60 |         try assertNotNil(attachment.originalImage, "originalImage")
 206 |   61 |         try assertFalse(attachment.isVideo, "isVideo")
 207 |   62 |         try assertFalse(attachment.isTextBundle, "isTextBundle")
 208 |   63 |         try assertNil(attachment.textContent, "textContent")
 209 |   64 |     }
 210 |   65 |     
 211 |   66 |     static func testScreenshotAttachment() throws {
 212 |   67 |         let image = NSImage(size: NSSize(width: 1920, height: 1080))
 213 |   68 |         let id = UUID()
 214 |   69 |         
 215 |   70 |         let attachment = Attachment.screenshot(image, nil, id)
 216 |   71 |         
 217 |   72 |         try assertEqual(attachment.id, id, "ID")
 218 |   73 |         try assertEqual(attachment.displayTitle, "截图", "displayTitle")
 219 |   74 |         try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
 220 |   75 |         try assertNotNil(attachment.originalImage, "originalImage")
 221 |   76 |     }
 222 |   77 |     
 223 |   78 |     static func testFileAttachment() throws {
 224 |   79 |         let url = URL(fileURLWithPath: "/tmp/test.pdf")
 225 |   80 |         let id = UUID()
 226 |   81 |         
 227 |   82 |         let attachment = Attachment.file(url, id)
 228 |   83 |         
 229 |   84 |         try assertEqual(attachment.id, id, "ID")
 230 |   85 |         try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
 231 |   86 |         try assertEqual(attachment.fileName, "test.pdf", "fileName")
 232 |   87 |         try assertNil(attachment.thumbnail, "thumbnail")
 233 |   88 |         try assertNil(attachment.originalImage, "originalImage")
 234 |   89 |     }
 235 |   90 |     
 236 |   91 |     static func testTextBundleAttachment() throws {
 237 |   92 |         let content = "# Code content\nlet x = 1"
 238 |   93 |         let source = "my-project"
 239 |   94 |         let count = 42
 240 |   95 |         let id = UUID()
 241 |   96 |         
 242 |   97 |         let attachment = Attachment.textBundle(content, source, count, id)
 243 |   98 |         
 244 |   99 |         try assertEqual(attachment.id, id, "ID")
 245 |  100 |         try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
 246 |  101 |         try assertEqual(attachment.fileName, source, "fileName")
 247 |  102 |         try assertTrue(attachment.isTextBundle, "isTextBundle")
 248 |  103 |         try assertEqual(attachment.textContent, content, "textContent")
 249 |  104 |     }
 250 |  105 |     
 251 |  106 |     static func testVideoDetection() throws {
 252 |  107 |         let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
 253 |  108 |         let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
 254 |  109 |         let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
 255 |  110 |         
 256 |  111 |         try assertTrue(mp4.isVideo, "mp4 should be video")
 257 |  112 |         try assertTrue(mov.isVideo, "mov should be video")
 258 |  113 |         try assertFalse(txt.isVideo, "txt should not be video")
 259 |  114 |     }
 260 |  115 |     
 261 |  116 |     static func testEqualityById() throws {
 262 |  117 |         let id = UUID()
 263 |  118 |         let image1 = NSImage(size: NSSize(width: 100, height: 100))
 264 |  119 |         let image2 = NSImage(size: NSSize(width: 200, height: 200))
 265 |  120 |         
 266 |  121 |         let att1 = Attachment.image(image1, nil, id)
 267 |  122 |         let att2 = Attachment.image(image2, nil, id)
 268 |  123 |         let att3 = Attachment.image(image1, nil, UUID())
 269 |  124 |         
 270 |  125 |         try assertTrue(att1 == att2, "Same ID should be equal")
 271 |  126 |         try assertFalse(att1 == att3, "Different ID should not be equal")
 272 |  127 |     }
 273 |  128 |     
 274 |  129 |     // MARK: - Test Cases: Thumbnail Generation
 275 |  130 |     
 276 |  131 |     static func testThumbnailResizesLarge() throws {
 277 |  132 |         let large = createTestImage(width: 2000, height: 1000)
 278 |  133 |         let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
 279 |  134 |         
 280 |  135 |         try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
 281 |  136 |         try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
 282 |  137 |     }
 283 |  138 |     
 284 |  139 |     static func testThumbnailPreservesRatio() throws {
 285 |  140 |         let image = createTestImage(width: 2000, height: 1000)
 286 |  141 |         let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
 287 |  142 |         
 288 |  143 |         let ratio = thumb.size.width / thumb.size.height
 289 |  144 |         try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
 290 |  145 |     }
 291 |  146 |     
 292 |  147 |     static func testThumbnailNoUpscale() throws {
 293 |  148 |         let small = createTestImage(width: 50, height: 50)
 294 |  149 |         let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
 295 |  150 |         
 296 |  151 |         try assertEqual(thumb.size.width, 50, "Width")
 297 |  152 |         try assertEqual(thumb.size.height, 50, "Height")
 298 |  153 |     }
 299 |  154 |     
 300 |  155 |     static func testThumbnailZeroSize() throws {
 301 |  156 |         let zero = NSImage(size: NSSize(width: 0, height: 0))
 302 |  157 |         let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
 303 |  158 |         
 304 |  159 |         try assertEqual(thumb.size.width, 0, "Width")
 305 |  160 |     }
 306 |  161 |     
 307 |  162 |     // MARK: - Helpers
 308 |  163 |     
 309 |  164 |     static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
 310 |  165 |         let image = NSImage(size: NSSize(width: width, height: height))
 311 |  166 |         image.lockFocus()
 312 |  167 |         NSColor.red.setFill()
 313 |  168 |         NSRect(x: 0, y: 0, width: width, height: height).fill()
 314 |  169 |         image.unlockFocus()
 315 |  170 |         return image
 316 |  171 |     }
 317 |  172 | }
 318 |  173 | 
 319 |  174 | // MARK: - Attachment Type (简化版，用于测试)
 320 |  175 | 
 321 |  176 | import UniformTypeIdentifiers
 322 |  177 | 
 323 |  178 | enum Attachment: Identifiable, Equatable {
 324 |  179 |     case image(NSImage, NSImage?, UUID)
 325 |  180 |     case screenshot(NSImage, NSImage?, UUID)
 326 |  181 |     case file(URL, UUID)
 327 |  182 |     case textBundle(String, String, Int, UUID)
 328 |  183 |     
 329 |  184 |     var id: UUID {
 330 |  185 |         switch self {
 331 |  186 |         case .image(_, _, let id), .screenshot(_, _, let id),
 332 |  187 |              .file(_, let id), .textBundle(_, _, _, let id):
 333 |  188 |             return id
 334 |  189 |         }
 335 |  190 |     }
 336 |  191 |     
 337 |  192 |     var thumbnail: NSImage? {
 338 |  193 |         switch self {
 339 |  194 |         case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
 340 |  195 |         default: return nil
 341 |  196 |         }
 342 |  197 |     }
 343 |  198 |     
 344 |  199 |     var originalImage: NSImage? {
 345 |  200 |         switch self {
 346 |  201 |         case .image(let img, _, _), .screenshot(let img, _, _): return img
 347 |  202 |         default: return nil
 348 |  203 |         }
 349 |  204 |     }
 350 |  205 |     
 351 |  206 |     var fileName: String? {
 352 |  207 |         switch self {
 353 |  208 |         case .file(let url, _): return url.lastPathComponent
 354 |  209 |         case .textBundle(_, let source, _, _): return source
 355 |  210 |         default: return nil
 356 |  211 |         }
 357 |  212 |     }
 358 |  213 |     
 359 |  214 |     var displayTitle: String {
 360 |  215 |         switch self {
 361 |  216 |         case .image: return "图片"
 362 |  217 |         case .screenshot: return "截图"
 363 |  218 |         case .file(let url, _): return url.lastPathComponent
 364 |  219 |         case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
 365 |  220 |         }
 366 |  221 |     }
 367 |  222 |     
 368 |  223 |     var isVideo: Bool {
 369 |  224 |         if case .file(let url, _) = self,
 370 |  225 |            let uti = UTType(filenameExtension: url.pathExtension) {
 371 |  226 |             return uti.conforms(to: .movie) || uti.conforms(to: .video)
 372 |  227 |         }
 373 |  228 |         return false
 374 |  229 |     }
 375 |  230 |     
 376 |  231 |     var isTextBundle: Bool {
 377 |  232 |         if case .textBundle = self { return true }
 378 |  233 |         return false
 379 |  234 |     }
 380 |  235 |     
 381 |  236 |     var textContent: String? {
 382 |  237 |         if case .textBundle(let content, _, _, _) = self { return content }
 383 |  238 |         return nil
 384 |  239 |     }
 385 |  240 |     
 386 |  241 |     static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
 387 |  242 |     
 388 |  243 |     static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
 389 |  244 |         let size = image.size
 390 |  245 |         guard size.width > 0 && size.height > 0 else { return image }
 391 |  246 |         
 392 |  247 |         let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
 393 |  248 |         let newSize = NSSize(width: size.width * scale, height: size.height * scale)
 394 |  249 |         
 395 |  250 |         let thumbnail = NSImage(size: newSize)
 396 |  251 |         thumbnail.lockFocus()
 397 |  252 |         image.draw(in: NSRect(origin: .zero, size: newSize),
 398 |  253 |                    from: NSRect(origin: .zero, size: size),
 399 |  254 |                    operation: .copy, fraction: 1.0)
 400 |  255 |         thumbnail.unlockFocus()
 401 |  256 |         return thumbnail
 402 |  257 |     }
 403 |  258 | }
 404 |  259 | 
 405 |  260 | // MARK: - Assertion Helpers
 406 |  261 | 
 407 |  262 | struct TestError: Error, CustomStringConvertible {
 408 |  263 |     let message: String
 409 |  264 |     init(_ message: String) { self.message = message }
 410 |  265 |     var description: String { message }
 411 |  266 | }
 412 |  267 | 
 413 |  268 | func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
 414 |  269 |     if actual != expected {
 415 |  270 |         throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
 416 |  271 |     }
 417 |  272 | }
 418 |  273 | 
 419 |  274 | func assertTrue(_ condition: Bool, _ message: String) throws {
 420 |  275 |     if !condition { throw TestError(message) }
 421 |  276 | }
 422 |  277 | 
 423 |  278 | func assertFalse(_ condition: Bool, _ message: String) throws {
 424 |  279 |     if condition { throw TestError(message) }
 425 |  280 | }
 426 |  281 | 
 427 |  282 | func assertNil<T>(_ value: T?, _ message: String) throws {
 428 |  283 |     if value != nil { throw TestError("\(message) 应该是 nil") }
 429 |  284 | }
 430 |  285 | 
 431 |  286 | func assertNotNil<T>(_ value: T?, _ message: String) throws {
 432 |  287 |     if value == nil { throw TestError("\(message) 不应该是 nil") }
 433 |  288 | }
 434 |  289 | 
 435 |  290 | extension String {
 436 |  291 |     static func * (string: String, count: Int) -> String {
 437 |  292 |         String(repeating: string, count: count)
 438 |  293 |     }
 439 |  294 | }
 440 | 
 441 | ```
 442 | 
 443 | `spoke/Tests/EdgeTTSTests.swift`:
 444 | 
 445 | ```swift
 446 |    1 | import Foundation
 447 |    2 | import AVFoundation
 448 |    3 | 
 449 |    4 | // MARK: - Edge TTS 单元测试
 450 |    5 | 
 451 |    6 | @main
 452 |    7 | struct EdgeTTSTests {
 453 |    8 |     static func main() async {
 454 |    9 |         print("🧪 Edge TTS 单元测试")
 455 |   10 |         print("=" * 50)
 456 |   11 |         
 457 |   12 |         await testSynthesizeAndPlay()
 458 |   13 |     }
 459 |   14 |     
 460 |   15 |     /// 测试合成并播放
 461 |   16 |     static func testSynthesizeAndPlay() async {
 462 |   17 |         print("\n📝 测试: 合成并播放")
 463 |   18 |         
 464 |   19 |         let text = "你好，这是语音合成测试。"
 465 |   20 |         let voice = "zh-CN-XiaoxiaoNeural"
 466 |   21 |         
 467 |   22 |         do {
 468 |   23 |             // 1. 合成音频
 469 |   24 |             print("   正在合成...")
 470 |   25 |             let audioData = try await synthesize(text: text, voice: voice)
 471 |   26 |             print("   ✅ 合成完成: \(audioData.count) bytes")
 472 |   27 |             
 473 |   28 |             // 2. 检查音频头
 474 |   29 |             print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
 475 |   30 |             
 476 |   31 |             // 3. 保存到文件测试
 477 |   32 |             let tempPath = "/tmp/edge_tts_test.mp3"
 478 |   33 |             try audioData.write(to: URL(fileURLWithPath: tempPath))
 479 |   34 |             print("   ✅ 已保存到: \(tempPath)")
 480 |   35 |             
 481 |   36 |             // 4. 用 AVAudioPlayer 播放
 482 |   37 |             print("   正在播放...")
 483 |   38 |             let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
 484 |   39 |             player.prepareToPlay()
 485 |   40 |             player.play()
 486 |   41 |             
 487 |   42 |             // 等待播放完成
 488 |   43 |             while player.isPlaying {
 489 |   44 |                 try await Task.sleep(nanoseconds: 100_000_000)
 490 |   45 |             }
 491 |   46 |             print("   ✅ 播放完成!")
 492 |   47 |             
 493 |   48 |         } catch {
 494 |   49 |             print("   ❌ 错误: \(error)")
 495 |   50 |         }
 496 |   51 |     }
 497 |   52 |     
 498 |   53 |     /// 合成音频
 499 |   54 |     static func synthesize(text: String, voice: String) async throws -> Data {
 500 |   55 |         // DRM Token
 501 |   56 |         let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
 502 |   57 |         let chromiumVersion = "130.0.2849.68"
 503 |   58 |         let windowsFileTimeEpoch: Int64 = 11_644_473_600
 504 |   59 |         
 505 |   60 |         let currentTime = Int64(Date().timeIntervalSince1970)
 506 |   61 |         let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
 507 |   62 |         let roundedTicks = ticks - (ticks % 3_000_000_000)
 508 |   63 |         let strToHash = "\(roundedTicks)\(trustedClientToken)"
 509 |   64 |         
 510 |   65 |         // SHA256
 511 |   66 |         import CryptoKit
 512 |   67 |         let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
 513 |   68 |         let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
 514 |   69 |         
 515 |   70 |         // URL
 516 |   71 |         let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
 517 |   72 |         let url = URL(string: urlString)!
 518 |   73 |         
 519 |   74 |         // WebSocket
 520 |   75 |         var request = URLRequest(url: url)
 521 |   76 |         request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
 522 |   77 |         request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
 523 |   78 |         
 524 |   79 |         let session = URLSession.shared
 525 |   80 |         let ws = session.webSocketTask(with: request)
 526 |   81 |         ws.resume()
 527 |   82 |         
 528 |   83 |         // 等待连接
 529 |   84 |         try await Task.sleep(nanoseconds: 500_000_000)
 530 |   85 |         
 531 |   86 |         // 发送配置
 532 |   87 |         let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
 533 |   88 |         try await ws.send(.string(configMessage))
 534 |   89 |         
 535 |   90 |         // 发送 SSML
 536 |   91 |         let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
 537 |   92 |         let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
 538 |   93 |         try await ws.send(.string(ssmlMessage))
 539 |   94 |         
 540 |   95 |         // 接收音频
 541 |   96 |         var audioData = Data()
 542 |   97 |         
 543 |   98 |         while true {
 544 |   99 |             let message = try await ws.receive()
 545 |  100 |             
 546 |  101 |             switch message {
 547 |  102 |             case .data(let data):
 548 |  103 |                 // 检查是否包含 Path:audio
 549 |  104 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 550 |  105 |                     if let range = str.range(of: "Path:audio\r\n") {
 551 |  106 |                         let offset = range.upperBound.utf16Offset(in: str)
 552 |  107 |                         audioData.append(data[offset...])
 553 |  108 |                     }
 554 |  109 |                 } else {
 555 |  110 |                     audioData.append(data)
 556 |  111 |                 }
 557 |  112 |                 
 558 |  113 |             case .string(let str):
 559 |  114 |                 if str.contains("Path:turn.end") {
 560 |  115 |                     ws.cancel(with: .goingAway, reason: nil)
 561 |  116 |                     return audioData
 562 |  117 |                 }
 563 |  118 |                 
 564 |  119 |             @unknown default:
 565 |  120 |                 break
 566 |  121 |             }
 567 |  122 |         }
 568 |  123 |     }
 569 |  124 | }
 570 |  125 | 
 571 |  126 | extension String {
 572 |  127 |     static func * (string: String, count: Int) -> String {
 573 |  128 |         String(repeating: string, count: count)
 574 |  129 |     }
 575 |  130 | }
 576 | 
 577 | ```
 578 | 
 579 | `spoke/Tests/TextExtractionTests.swift`:
 580 | 
 581 | ```swift
 582 |    1 | import Foundation
 583 |    2 | 
 584 |    3 | // MARK: - Text Extraction Service Tests
 585 |    4 | 
 586 |    5 | /// 独立运行的测试脚本
 587 |    6 | /// 用法: swift Tests/TextExtractionTests.swift
 588 |    7 | @main
 589 |    8 | struct TextExtractionTests {
 590 |    9 |     
 591 |   10 |     static var tempDirectory: URL!
 592 |   11 |     static var passCount = 0
 593 |   12 |     static var failCount = 0
 594 |   13 |     
 595 |   14 |     static func main() async {
 596 |   15 |         print("🧪 TextExtractionService 单元测试")
 597 |   16 |         print("=" * 50)
 598 |   17 |         
 599 |   18 |         // 创建临时目录
 600 |   19 |         tempDirectory = FileManager.default.temporaryDirectory
 601 |   20 |             .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
 602 |   21 |         try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 603 |   22 |         
 604 |   23 |         defer {
 605 |   24 |             // 清理
 606 |   25 |             try? FileManager.default.removeItem(at: tempDirectory)
 607 |   26 |             print("\n" + "=" * 50)
 608 |   27 |             print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
 609 |   28 |         }
 610 |   29 |         
 611 |   30 |         // 运行测试
 612 |   31 |         await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
 613 |   32 |         await runTest("单文件提取") { try await testSingleFileExtraction() }
 614 |   33 |         await runTest("多文件合并") { try await testMultipleFilesExtraction() }
 615 |   34 |         await runTest("排除 node_modules") { try await testExcludesNodeModules() }
 616 |   35 |         await runTest("排除锁文件") { try await testExcludesLockFiles() }
 617 |   36 |         await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
 618 |   37 |         await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
 619 |   38 |         await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
 620 |   39 |         await runTest("添加行号") { try await testAddsLineNumbers() }
 621 |   40 |         await runTest("目录结构输出") { try await testDirectoryStructure() }
 622 |   41 |         await runTest("ZIP 提取") { try await testZIPExtraction() }
 623 |   42 |     }
 624 |   43 |     
 625 |   44 |     // MARK: - Test Runner
 626 |   45 |     
 627 |   46 |     static func runTest(_ name: String, _ test: () async throws -> Void) async {
 628 |   47 |         print("\n📝 测试: \(name)")
 629 |   48 |         do {
 630 |   49 |             try await test()
 631 |   50 |             print("   ✅ 通过")
 632 |   51 |             passCount += 1
 633 |   52 |         } catch {
 634 |   53 |             print("   ❌ 失败: \(error)")
 635 |   54 |             failCount += 1
 636 |   55 |         }
 637 |   56 |     }
 638 |   57 |     
 639 |   58 |     // MARK: - Helpers
 640 |   59 |     
 641 |   60 |     static func createFile(name: String, content: String) throws -> URL {
 642 |   61 |         let fileURL = tempDirectory.appendingPathComponent(name)
 643 |   62 |         let dir = fileURL.deletingLastPathComponent()
 644 |   63 |         try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
 645 |   64 |         try content.write(to: fileURL, atomically: true, encoding: .utf8)
 646 |   65 |         return fileURL
 647 |   66 |     }
 648 |   67 |     
 649 |   68 |     static func createDirectory(name: String) throws -> URL {
 650 |   69 |         let dirURL = tempDirectory.appendingPathComponent(name)
 651 |   70 |         try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
 652 |   71 |         return dirURL
 653 |   72 |     }
 654 |   73 |     
 655 |   74 |     // MARK: - Test Cases
 656 |   75 |     
 657 |   76 |     static func testCodeExtensions() async throws {
 658 |   77 |         // 创建各种代码文件
 659 |   78 |         _ = try createFile(name: "test.swift", content: "let x = 1")
 660 |   79 |         _ = try createFile(name: "app.js", content: "const x = 1")
 661 |   80 |         _ = try createFile(name: "main.py", content: "x = 1")
 662 |   81 |         _ = try createFile(name: "README.md", content: "# Title")
 663 |   82 |         
 664 |   83 |         let result = await extractFromFolder(tempDirectory)
 665 |   84 |         guard case .success(let bundle) = result else {
 666 |   85 |             throw TestError("提取失败")
 667 |   86 |         }
 668 |   87 |         
 669 |   88 |         guard bundle.fileCount == 4 else {
 670 |   89 |             throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
 671 |   90 |         }
 672 |   91 |     }
 673 |   92 |     
 674 |   93 |     static func testSingleFileExtraction() async throws {
 675 |   94 |         // 清理并创建新目录
 676 |   95 |         try FileManager.default.removeItem(at: tempDirectory)
 677 |   96 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 678 |   97 |         
 679 |   98 |         _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
 680 |   99 |         
 681 |  100 |         let result = await extractFromFolder(tempDirectory)
 682 |  101 |         guard case .success(let bundle) = result else {
 683 |  102 |             throw TestError("提取失败")
 684 |  103 |         }
 685 |  104 |         
 686 |  105 |         guard bundle.fileCount == 1 else {
 687 |  106 |             throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
 688 |  107 |         }
 689 |  108 |         guard bundle.content.contains("print(\"Hello\")") else {
 690 |  109 |             throw TestError("内容不包含预期文本")
 691 |  110 |         }
 692 |  111 |     }
 693 |  112 |     
 694 |  113 |     static func testMultipleFilesExtraction() async throws {
 695 |  114 |         try FileManager.default.removeItem(at: tempDirectory)
 696 |  115 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 697 |  116 |         
 698 |  117 |         _ = try createFile(name: "a.swift", content: "let a = 1")
 699 |  118 |         _ = try createFile(name: "b.swift", content: "let b = 2")
 700 |  119 |         _ = try createFile(name: "c.js", content: "const c = 3")
 701 |  120 |         
 702 |  121 |         let result = await extractFromFolder(tempDirectory)
 703 |  122 |         guard case .success(let bundle) = result else {
 704 |  123 |             throw TestError("提取失败")
 705 |  124 |         }
 706 |  125 |         
 707 |  126 |         guard bundle.fileCount == 3 else {
 708 |  127 |             throw TestError("文件数量错误")
 709 |  128 |         }
 710 |  129 |         guard bundle.content.contains("let a = 1") &&
 711 |  130 |               bundle.content.contains("let b = 2") &&
 712 |  131 |               bundle.content.contains("const c = 3") else {
 713 |  132 |             throw TestError("内容缺失")
 714 |  133 |         }
 715 |  134 |     }
 716 |  135 |     
 717 |  136 |     static func testExcludesNodeModules() async throws {
 718 |  137 |         try FileManager.default.removeItem(at: tempDirectory)
 719 |  138 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 720 |  139 |         
 721 |  140 |         let nodeModules = try createDirectory(name: "node_modules")
 722 |  141 |         try "const secret = 'password'".write(
 723 |  142 |             to: nodeModules.appendingPathComponent("secret.js"),
 724 |  143 |             atomically: true, encoding: .utf8
 725 |  144 |         )
 726 |  145 |         _ = try createFile(name: "app.js", content: "const app = 1")
 727 |  146 |         
 728 |  147 |         let result = await extractFromFolder(tempDirectory)
 729 |  148 |         guard case .success(let bundle) = result else {
 730 |  149 |             throw TestError("提取失败")
 731 |  150 |         }
 732 |  151 |         
 733 |  152 |         guard bundle.fileCount == 1 else {
 734 |  153 |             throw TestError("应该只包含 app.js")
 735 |  154 |         }
 736 |  155 |         guard !bundle.content.contains("secret") else {
 737 |  156 |             throw TestError("不应包含 node_modules 内容")
 738 |  157 |         }
 739 |  158 |     }
 740 |  159 |     
 741 |  160 |     static func testExcludesLockFiles() async throws {
 742 |  161 |         try FileManager.default.removeItem(at: tempDirectory)
 743 |  162 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 744 |  163 |         
 745 |  164 |         _ = try createFile(name: "package-lock.json", content: "{}")
 746 |  165 |         _ = try createFile(name: "yarn.lock", content: "")
 747 |  166 |         _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
 748 |  167 |         
 749 |  168 |         let result = await extractFromFolder(tempDirectory)
 750 |  169 |         guard case .success(let bundle) = result else {
 751 |  170 |             throw TestError("提取失败")
 752 |  171 |         }
 753 |  172 |         
 754 |  173 |         guard bundle.fileCount == 1 else {
 755 |  174 |             throw TestError("应该只包含 package.json")
 756 |  175 |         }
 757 |  176 |     }
 758 |  177 |     
 759 |  178 |     static func testNestedDirectories() async throws {
 760 |  179 |         try FileManager.default.removeItem(at: tempDirectory)
 761 |  180 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 762 |  181 |         
 763 |  182 |         _ = try createFile(name: "root.swift", content: "let root = 1")
 764 |  183 |         _ = try createFile(name: "src/app.swift", content: "let src = 2")
 765 |  184 |         _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
 766 |  185 |         
 767 |  186 |         let result = await extractFromFolder(tempDirectory)
 768 |  187 |         guard case .success(let bundle) = result else {
 769 |  188 |             throw TestError("提取失败")
 770 |  189 |         }
 771 |  190 |         
 772 |  191 |         guard bundle.fileCount == 3 else {
 773 |  192 |             throw TestError("应该包含 3 个文件")
 774 |  193 |         }
 775 |  194 |         guard bundle.content.contains("let root = 1") &&
 776 |  195 |               bundle.content.contains("let src = 2") &&
 777 |  196 |               bundle.content.contains("let lib = 3") else {
 778 |  197 |             throw TestError("缺少嵌套目录内容")
 779 |  198 |         }
 780 |  199 |     }
 781 |  200 |     
 782 |  201 |     static func testEmptyFolderError() async throws {
 783 |  202 |         try FileManager.default.removeItem(at: tempDirectory)
 784 |  203 |         let emptyDir = try createDirectory(name: "empty")
 785 |  204 |         
 786 |  205 |         let result = await extractFromFolder(emptyDir)
 787 |  206 |         guard case .failure = result else {
 788 |  207 |             throw TestError("空文件夹应该返回错误")
 789 |  208 |         }
 790 |  209 |     }
 791 |  210 |     
 792 |  211 |     static func testIgnoresNonCodeFiles() async throws {
 793 |  212 |         try FileManager.default.removeItem(at: tempDirectory)
 794 |  213 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 795 |  214 |         
 796 |  215 |         _ = try createFile(name: "image.png", content: "fake")
 797 |  216 |         _ = try createFile(name: "video.mp4", content: "fake")
 798 |  217 |         _ = try createFile(name: "main.swift", content: "let x = 1")
 799 |  218 |         
 800 |  219 |         let result = await extractFromFolder(tempDirectory)
 801 |  220 |         guard case .success(let bundle) = result else {
 802 |  221 |             throw TestError("提取失败")
 803 |  222 |         }
 804 |  223 |         
 805 |  224 |         guard bundle.fileCount == 1 else {
 806 |  225 |             throw TestError("应该只包含 .swift 文件")
 807 |  226 |         }
 808 |  227 |     }
 809 |  228 |     
 810 |  229 |     static func testAddsLineNumbers() async throws {
 811 |  230 |         try FileManager.default.removeItem(at: tempDirectory)
 812 |  231 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 813 |  232 |         
 814 |  233 |         _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
 815 |  234 |         
 816 |  235 |         let result = await extractFromFolder(tempDirectory)
 817 |  236 |         guard case .success(let bundle) = result else {
 818 |  237 |             throw TestError("提取失败")
 819 |  238 |         }
 820 |  239 |         
 821 |  240 |         guard bundle.content.contains("1│") &&
 822 |  241 |               bundle.content.contains("2│") &&
 823 |  242 |               bundle.content.contains("3│") else {
 824 |  243 |             throw TestError("缺少行号")
 825 |  244 |         }
 826 |  245 |     }
 827 |  246 |     
 828 |  247 |     static func testDirectoryStructure() async throws {
 829 |  248 |         try FileManager.default.removeItem(at: tempDirectory)
 830 |  249 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 831 |  250 |         
 832 |  251 |         _ = try createFile(name: "main.swift", content: "entry")
 833 |  252 |         _ = try createFile(name: "src/app.swift", content: "code")
 834 |  253 |         
 835 |  254 |         let result = await extractFromFolder(tempDirectory)
 836 |  255 |         guard case .success(let bundle) = result else {
 837 |  256 |             throw TestError("提取失败")
 838 |  257 |         }
 839 |  258 |         
 840 |  259 |         guard bundle.content.contains("# 目录结构") else {
 841 |  260 |             throw TestError("缺少目录结构标题")
 842 |  261 |         }
 843 |  262 |     }
 844 |  263 |     
 845 |  264 |     static func testZIPExtraction() async throws {
 846 |  265 |         try FileManager.default.removeItem(at: tempDirectory)
 847 |  266 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 848 |  267 |         
 849 |  268 |         // 创建源文件
 850 |  269 |         let sourceDir = try createDirectory(name: "source")
 851 |  270 |         try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
 852 |  271 |         
 853 |  272 |         // 创建 ZIP
 854 |  273 |         let zipPath = tempDirectory.appendingPathComponent("test.zip")
 855 |  274 |         let process = Process()
 856 |  275 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
 857 |  276 |         process.currentDirectoryURL = tempDirectory
 858 |  277 |         process.arguments = ["-r", zipPath.path, "source"]
 859 |  278 |         process.standardOutput = FileHandle.nullDevice
 860 |  279 |         process.standardError = FileHandle.nullDevice
 861 |  280 |         try process.run()
 862 |  281 |         process.waitUntilExit()
 863 |  282 |         
 864 |  283 |         guard process.terminationStatus == 0 else {
 865 |  284 |             throw TestError("创建 ZIP 失败")
 866 |  285 |         }
 867 |  286 |         
 868 |  287 |         let result = await extractFromZIP(zipPath)
 869 |  288 |         guard case .success(let bundle) = result else {
 870 |  289 |             throw TestError("ZIP 提取失败")
 871 |  290 |         }
 872 |  291 |         
 873 |  292 |         guard bundle.fileCount == 1 else {
 874 |  293 |             throw TestError("ZIP 文件数量错误")
 875 |  294 |         }
 876 |  295 |         guard bundle.content.contains("let x = 1") else {
 877 |  296 |             throw TestError("ZIP 内容缺失")
 878 |  297 |         }
 879 |  298 |     }
 880 |  299 | }
 881 |  300 | 
 882 |  301 | // MARK: - TextExtractionService (简化版，用于测试)
 883 |  302 | 
 884 |  303 | struct TextBundle {
 885 |  304 |     let content: String
 886 |  305 |     let fileCount: Int
 887 |  306 |     let sourcePath: String
 888 |  307 |     let files: [String]
 889 |  308 | }
 890 |  309 | 
 891 |  310 | enum TextExtractionError: Error, Equatable {
 892 |  311 |     case folderNotFound
 893 |  312 |     case zipExtractionFailed(String)
 894 |  313 |     case noTextFilesFound
 895 |  314 |     case accessDenied
 896 |  315 | }
 897 |  316 | 
 898 |  317 | func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
 899 |  318 |     let codeExtensions: Set<String> = [
 900 |  319 |         "js", "jsx", "ts", "tsx", "mjs", "cjs",
 901 |  320 |         "html", "htm", "css", "scss", "less", "vue", "svelte",
 902 |  321 |         "py", "pyw", "pyi",
 903 |  322 |         "java", "kt", "kts", "scala",
 904 |  323 |         "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
 905 |  324 |         "rs", "go", "rb", "erb", "php", "swift",
 906 |  325 |         "sh", "bash", "zsh", "fish",
 907 |  326 |         "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
 908 |  327 |         "md", "mdx", "txt", "rst", "asciidoc",
 909 |  328 |         "sql", "graphql", "proto", "dockerfile"
 910 |  329 |     ]
 911 |  330 |     
 912 |  331 |     let excludedDirs: Set<String> = [
 913 |  332 |         "node_modules", ".git", ".svn", ".hg",
 914 |  333 |         "dist", "build", "target", ".next", ".nuxt",
 915 |  334 |         "__pycache__", ".pytest_cache", ".tox",
 916 |  335 |         "venv", "env", ".env", ".venv",
 917 |  336 |         "vendor", "Pods", "Carthage",
 918 |  337 |         ".idea", ".vscode", ".vs"
 919 |  338 |     ]
 920 |  339 |     
 921 |  340 |     let excludedFiles: Set<String> = [
 922 |  341 |         ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
 923 |  342 |         "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
 924 |  343 |         "Podfile.lock", "Gemfile.lock", "Cargo.lock"
 925 |  344 |     ]
 926 |  345 |     
 927 |  346 |     // 递归收集文件
 928 |  347 |     func collectFiles(in directory: URL) -> [URL] {
 929 |  348 |         var result: [URL] = []
 930 |  349 |         let fm = FileManager.default
 931 |  350 |         
 932 |  351 |         guard let contents = try? fm.contentsOfDirectory(
 933 |  352 |             at: directory,
 934 |  353 |             includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
 935 |  354 |             options: [.skipsHiddenFiles]
 936 |  355 |         ) else { return [] }
 937 |  356 |         
 938 |  357 |         for url in contents {
 939 |  358 |             let fileName = url.lastPathComponent
 940 |  359 |             if excludedFiles.contains(fileName) { continue }
 941 |  360 |             
 942 |  361 |             let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
 943 |  362 |             
 944 |  363 |             if values?.isDirectory == true {
 945 |  364 |                 if !excludedDirs.contains(fileName) {
 946 |  365 |                     result.append(contentsOf: collectFiles(in: url))
 947 |  366 |                 }
 948 |  367 |             } else if values?.isRegularFile == true {
 949 |  368 |                 let ext = url.pathExtension.lowercased()
 950 |  369 |                 if codeExtensions.contains(ext) {
 951 |  370 |                     result.append(url)
 952 |  371 |                 }
 953 |  372 |             }
 954 |  373 |         }
 955 |  374 |         return result.sorted { $0.path < $1.path }
 956 |  375 |     }
 957 |  376 |     
 958 |  377 |     let files = collectFiles(in: folderURL)
 959 |  378 |     guard !files.isEmpty else {
 960 |  379 |         return .failure(.noTextFilesFound)
 961 |  380 |     }
 962 |  381 |     
 963 |  382 |     // 合并内容
 964 |  383 |     var parts: [String] = ["# 目录结构\n```"]
 965 |  384 |     for file in files {
 966 |  385 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 967 |  386 |         parts.append(rel)
 968 |  387 |     }
 969 |  388 |     parts.append("```\n\n# 文件内容\n")
 970 |  389 |     
 971 |  390 |     for file in files {
 972 |  391 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 973 |  392 |         let ext = file.pathExtension
 974 |  393 |         if let content = try? String(contentsOf: file, encoding: .utf8) {
 975 |  394 |             let numbered = content.components(separatedBy: .newlines).enumerated()
 976 |  395 |                 .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
 977 |  396 |             parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
 978 |  397 |         }
 979 |  398 |     }
 980 |  399 |     
 981 |  400 |     return .success(TextBundle(
 982 |  401 |         content: parts.joined(separator: "\n"),
 983 |  402 |         fileCount: files.count,
 984 |  403 |         sourcePath: folderURL.path,
 985 |  404 |         files: files.map { $0.path }
 986 |  405 |     ))
 987 |  406 | }
 988 |  407 | 
 989 |  408 | func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
 990 |  409 |     let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
 991 |  410 |     try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
 992 |  411 |     defer { try? FileManager.default.removeItem(at: tempDir) }
 993 |  412 |     
 994 |  413 |     let process = Process()
 995 |  414 |     process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
 996 |  415 |     process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
 997 |  416 |     process.standardOutput = FileHandle.nullDevice
 998 |  417 |     process.standardError = FileHandle.nullDevice
 999 |  418 |     
1000 |  419 |     do {
1001 |  420 |         try process.run()
1002 |  421 |         process.waitUntilExit()
1003 |  422 |         
1004 |  423 |         guard process.terminationStatus == 0 else {
1005 |  424 |             return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
1006 |  425 |         }
1007 |  426 |         
1008 |  427 |         return await extractFromFolder(tempDir)
1009 |  428 |     } catch {
1010 |  429 |         return .failure(.zipExtractionFailed(error.localizedDescription))
1011 |  430 |     }
1012 |  431 | }
1013 |  432 | 
1014 |  433 | // MARK: - Helpers
1015 |  434 | 
1016 |  435 | struct TestError: Error, CustomStringConvertible {
1017 |  436 |     let message: String
1018 |  437 |     init(_ message: String) { self.message = message }
1019 |  438 |     var description: String { message }
1020 |  439 | }
1021 |  440 | 
1022 |  441 | extension String {
1023 |  442 |     static func * (string: String, count: Int) -> String {
1024 |  443 |         String(repeating: string, count: count)
1025 |  444 |     }
1026 |  445 | }
1027 | 
1028 | ```
1029 | 
1030 | `spoke/Tests/run-tests.sh`:
1031 | 
1032 | ```sh
1033 |    1 | #!/bin/bash
1034 |    2 | # 运行所有单元测试
1035 |    3 | # 用法: ./Tests/run-tests.sh
1036 |    4 | 
1037 |    5 | set -e
1038 |    6 | 
1039 |    7 | cd "$(dirname "$0")/.."
1040 |    8 | 
1041 |    9 | echo "🧪 运行所有单元测试"
1042 |   10 | echo "=================================="
1043 |   11 | 
1044 |   12 | # 编译并运行 TextExtractionTests
1045 |   13 | echo ""
1046 |   14 | echo "📦 编译 TextExtractionTests..."
1047 |   15 | swiftc -parse-as-library -o /tmp/text_extraction_tests Tests/TextExtractionTests.swift
1048 |   16 | echo "🚀 运行测试..."
1049 |   17 | /tmp/text_extraction_tests
1050 |   18 | 
1051 |   19 | echo ""
1052 |   20 | echo "=================================="
1053 |   21 | 
1054 |   22 | # 编译并运行 AttachmentTests
1055 |   23 | echo ""
1056 |   24 | echo "📦 编译 AttachmentTests..."
1057 |   25 | swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift
1058 |   26 | echo "🚀 运行测试..."
1059 |   27 | /tmp/attachment_tests
1060 |   28 | 
1061 |   29 | echo ""
1062 |   30 | echo "=================================="
1063 |   31 | echo "🎉 所有测试完成!"
1064 | 
1065 | ```
1066 | 
1067 | `spoke/Tests/test_edge_tts.swift`:
1068 | 
1069 | ```swift
1070 |    1 | #!/usr/bin/env swift
1071 |    2 | 
1072 |    3 | import Foundation
1073 |    4 | import CryptoKit
1074 |    5 | import AVFoundation
1075 |    6 | 
1076 |    7 | // MARK: - Edge TTS 测试脚本
1077 |    8 | 
1078 |    9 | print("🧪 Edge TTS 测试")
1079 |   10 | print(String(repeating: "=", count: 50))
1080 |   11 | 
1081 |   12 | // 配置
1082 |   13 | let text = "你好，这是语音合成测试。Hello, this is a test."
1083 |   14 | let voice = "zh-CN-XiaoxiaoNeural"
1084 |   15 | let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
1085 |   16 | let chromiumVersion = "130.0.2849.68"
1086 |   17 | let windowsFileTimeEpoch: Int64 = 11_644_473_600
1087 |   18 | 
1088 |   19 | // 生成 DRM Token
1089 |   20 | func generateSecMsGecToken() -> String {
1090 |   21 |     let currentTime = Int64(Date().timeIntervalSince1970)
1091 |   22 |     let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
1092 |   23 |     let roundedTicks = ticks - (ticks % 3_000_000_000)
1093 |   24 |     let strToHash = "\(roundedTicks)\(trustedClientToken)"
1094 |   25 |     let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
1095 |   26 |     return hash.map { String(format: "%02X", $0) }.joined()
1096 |   27 | }
1097 |   28 | 
1098 |   29 | // WebSocket Delegate
1099 |   30 | class WSDelegate: NSObject, URLSessionWebSocketDelegate {
1100 |   31 |     var onOpen: (() -> Void)?
1101 |   32 |     
1102 |   33 |     func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
1103 |   34 |         print("   ✅ WebSocket 已连接")
1104 |   35 |         onOpen?()
1105 |   36 |     }
1106 |   37 | }
1107 |   38 | 
1108 |   39 | // 主测试
1109 |   40 | func runTest() async {
1110 |   41 |     print("\n📝 测试文本: \(text)")
1111 |   42 |     print("🎤 语音: \(voice)")
1112 |   43 |     
1113 |   44 |     // 构建 URL
1114 |   45 |     let secMsGec = generateSecMsGecToken()
1115 |   46 |     let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
1116 |   47 |     
1117 |   48 |     guard let url = URL(string: urlString) else {
1118 |   49 |         print("❌ URL 无效")
1119 |   50 |         return
1120 |   51 |     }
1121 |   52 |     
1122 |   53 |     // 创建 WebSocket
1123 |   54 |     print("\n🔗 正在连接...")
1124 |   55 |     var request = URLRequest(url: url)
1125 |   56 |     request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
1126 |   57 |     request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
1127 |   58 |     
1128 |   59 |     let delegate = WSDelegate()
1129 |   60 |     let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
1130 |   61 |     let ws = session.webSocketTask(with: request)
1131 |   62 |     
1132 |   63 |     // 等待连接
1133 |   64 |     await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
1134 |   65 |         delegate.onOpen = { cont.resume() }
1135 |   66 |         ws.resume()
1136 |   67 |     }
1137 |   68 |     
1138 |   69 |     // 发送配置
1139 |   70 |     print("📤 发送配置...")
1140 |   71 |     let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
1141 |   72 |     do {
1142 |   73 |         try await ws.send(.string(configMessage))
1143 |   74 |         print("   ✅ 配置已发送")
1144 |   75 |     } catch {
1145 |   76 |         print("   ❌ 发送配置失败: \(error)")
1146 |   77 |         return
1147 |   78 |     }
1148 |   79 |     
1149 |   80 |     // 发送 SSML
1150 |   81 |     print("📤 发送 SSML...")
1151 |   82 |     let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
1152 |   83 |     let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
1153 |   84 |     do {
1154 |   85 |         try await ws.send(.string(ssmlMessage))
1155 |   86 |         print("   ✅ SSML 已发送")
1156 |   87 |     } catch {
1157 |   88 |         print("   ❌ 发送 SSML 失败: \(error)")
1158 |   89 |         return
1159 |   90 |     }
1160 |   91 |     
1161 |   92 |     // 接收音频
1162 |   93 |     print("\n📥 接收音频数据...")
1163 |   94 |     var audioData = Data()
1164 |   95 |     var messageCount = 0
1165 |   96 |     
1166 |   97 |     while true {
1167 |   98 |         do {
1168 |   99 |             let message = try await ws.receive()
1169 |  100 |             messageCount += 1
1170 |  101 |             
1171 |  102 |             switch message {
1172 |  103 |             case .data(let data):
1173 |  104 |                 // 尝试解析为字符串查看内容
1174 |  105 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
1175 |  106 |                     // 找到音频分隔符后的数据
1176 |  107 |                     if let range = str.range(of: "Path:audio\r\n") {
1177 |  108 |                         let offset = range.upperBound.utf16Offset(in: str)
1178 |  109 |                         let audioChunk = data.suffix(from: offset)
1179 |  110 |                         audioData.append(audioChunk)
1180 |  111 |                         print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
1181 |  112 |                     }
1182 |  113 |                 } else {
1183 |  114 |                     // 纯二进制音频
1184 |  115 |                     audioData.append(data)
1185 |  116 |                     print("   收到音频块 #\(messageCount): \(data.count) bytes")
1186 |  117 |                 }
1187 |  118 |                 
1188 |  119 |             case .string(let str):
1189 |  120 |                 if str.contains("Path:turn.end") {
1190 |  121 |                     print("   ✅ 收到结束信号")
1191 |  122 |                     break
1192 |  123 |                 } else if str.contains("Path:audio.metadata") {
1193 |  124 |                     print("   收到元数据")
1194 |  125 |                 } else {
1195 |  126 |                     print("   收到文本: \(str.prefix(50))...")
1196 |  127 |                 }
1197 |  128 |                 continue
1198 |  129 |                 
1199 |  130 |             @unknown default:
1200 |  131 |                 continue
1201 |  132 |             }
1202 |  133 |             
1203 |  134 |             if messageCount > 100 { break } // 防止死循环
1204 |  135 |             
1205 |  136 |         } catch {
1206 |  137 |             print("   ⚠️ 接收错误: \(error)")
1207 |  138 |             break
1208 |  139 |         }
1209 |  140 |     }
1210 |  141 |     
1211 |  142 |     ws.cancel(with: .goingAway, reason: nil)
1212 |  143 |     
1213 |  144 |     print("\n📊 结果:")
1214 |  145 |     print("   总消息数: \(messageCount)")
1215 |  146 |     print("   音频大小: \(audioData.count) bytes")
1216 |  147 |     
1217 |  148 |     if audioData.isEmpty {
1218 |  149 |         print("   ❌ 没有收到音频数据")
1219 |  150 |         return
1220 |  151 |     }
1221 |  152 |     
1222 |  153 |     // 检查音频头
1223 |  154 |     let header = audioData.prefix(16)
1224 |  155 |     print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
1225 |  156 |     
1226 |  157 |     // MP3 文件应该以 FF FB 或 ID3 开头
1227 |  158 |     if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
1228 |  159 |         print("   ✅ 看起来是有效的 MP3 格式")
1229 |  160 |     } else {
1230 |  161 |         print("   ⚠️ 可能不是标准 MP3 格式")
1231 |  162 |     }
1232 |  163 |     
1233 |  164 |     // 保存到文件
1234 |  165 |     let tempPath = "/tmp/edge_tts_test.mp3"
1235 |  166 |     do {
1236 |  167 |         try audioData.write(to: URL(fileURLWithPath: tempPath))
1237 |  168 |         print("\n💾 已保存到: \(tempPath)")
1238 |  169 |     } catch {
1239 |  170 |         print("   ❌ 保存失败: \(error)")
1240 |  171 |         return
1241 |  172 |     }
1242 |  173 |     
1243 |  174 |     // 播放测试
1244 |  175 |     print("\n🔊 播放测试...")
1245 |  176 |     do {
1246 |  177 |         let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
1247 |  178 |         player.prepareToPlay()
1248 |  179 |         
1249 |  180 |         if player.play() {
1250 |  181 |             print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
1251 |  182 |             
1252 |  183 |             // 等待播放完成
1253 |  184 |             while player.isPlaying {
1254 |  185 |                 try await Task.sleep(nanoseconds: 100_000_000)
1255 |  186 |             }
1256 |  187 |             print("   ✅ 播放完成!")
1257 |  188 |         } else {
1258 |  189 |             print("   ❌ 播放启动失败")
1259 |  190 |         }
1260 |  191 |     } catch {
1261 |  192 |         print("   ❌ 播放错误: \(error)")
1262 |  193 |         
1263 |  194 |         // 尝试用 afplay 播放
1264 |  195 |         print("\n🔧 尝试用 afplay 播放...")
1265 |  196 |         let process = Process()
1266 |  197 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
1267 |  198 |         process.arguments = [tempPath]
1268 |  199 |         try? process.run()
1269 |  200 |         process.waitUntilExit()
1270 |  201 |         
1271 |  202 |         if process.terminationStatus == 0 {
1272 |  203 |             print("   ✅ afplay 播放成功!")
1273 |  204 |         } else {
1274 |  205 |             print("   ❌ afplay 也失败了")
1275 |  206 |         }
1276 |  207 |     }
1277 |  208 | }
1278 |  209 | 
1279 |  210 | // 运行测试
1280 |  211 | Task {
1281 |  212 |     await runTest()
1282 |  213 |     exit(0)
1283 |  214 | }
1284 |  215 | 
1285 |  216 | // 保持运行
1286 |  217 | RunLoop.main.run()
1287 | 
1288 | ```
1289 | ```
1290 | 
1291 | `spoke/docs/code2prompt-output/lucid-source.md`:
1292 | 
1293 | ```md
1294 | Project Path: spoke
1295 | 
1296 | Source Tree:
1297 | 
1298 | ```txt
1299 | spoke
1300 | └── Tests
1301 |     ├── AttachmentTests.swift
1302 |     ├── EdgeTTSTests.swift
1303 |     ├── TextExtractionTests.swift
1304 |     └── test_edge_tts.swift
1305 | 
1306 | ```
1307 | 
1308 | `spoke/Tests/AttachmentTests.swift`:
1309 | 
1310 | ```swift
1311 |    1 | import Foundation
1312 |    2 | import AppKit
1313 |    3 | 
1314 |    4 | // MARK: - Attachment Tests
1315 |    5 | 
1316 |    6 | /// Attachment 类型单元测试
1317 |    7 | /// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
1318 |    8 | @main
1319 |    9 | struct AttachmentTests {
1320 |   10 |     
1321 |   11 |     static var passCount = 0
1322 |   12 |     static var failCount = 0
1323 |   13 |     
1324 |   14 |     static func main() async {
1325 |   15 |         print("🧪 Attachment 类型单元测试")
1326 |   16 |         print("=" * 50)
1327 |   17 |         
1328 |   18 |         // 运行测试
1329 |   19 |         runTest("Image 类型属性") { try testImageAttachment() }
1330 |   20 |         runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
1331 |   21 |         runTest("File 类型属性") { try testFileAttachment() }
1332 |   22 |         runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
1333 |   23 |         runTest("视频文件检测") { try testVideoDetection() }
1334 |   24 |         runTest("ID 相等性判断") { try testEqualityById() }
1335 |   25 |         runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
1336 |   26 |         runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
1337 |   27 |         runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
1338 |   28 |         runTest("缩略图处理空图") { try testThumbnailZeroSize() }
1339 |   29 |         
1340 |   30 |         print("\n" + "=" * 50)
1341 |   31 |         print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
1342 |   32 |     }
1343 |   33 |     
1344 |   34 |     // MARK: - Test Runner
1345 |   35 |     
1346 |   36 |     static func runTest(_ name: String, _ test: () throws -> Void) {
1347 |   37 |         print("\n📝 测试: \(name)")
1348 |   38 |         do {
1349 |   39 |             try test()
1350 |   40 |             print("   ✅ 通过")
1351 |   41 |             passCount += 1
1352 |   42 |         } catch {
1353 |   43 |             print("   ❌ 失败: \(error)")
1354 |   44 |             failCount += 1
1355 |   45 |         }
1356 |   46 |     }
1357 |   47 |     
1358 |   48 |     // MARK: - Test Cases: Attachment Types
1359 |   49 |     
1360 |   50 |     static func testImageAttachment() throws {
1361 |   51 |         let image = NSImage(size: NSSize(width: 100, height: 100))
1362 |   52 |         let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
1363 |   53 |         let id = UUID()
1364 |   54 |         
1365 |   55 |         let attachment = Attachment.image(image, thumbnail, id)
1366 |   56 |         
1367 |   57 |         try assertEqual(attachment.id, id, "ID")
1368 |   58 |         try assertEqual(attachment.displayTitle, "图片", "displayTitle")
1369 |   59 |         try assertNotNil(attachment.thumbnail, "thumbnail")
1370 |   60 |         try assertNotNil(attachment.originalImage, "originalImage")
1371 |   61 |         try assertFalse(attachment.isVideo, "isVideo")
1372 |   62 |         try assertFalse(attachment.isTextBundle, "isTextBundle")
1373 |   63 |         try assertNil(attachment.textContent, "textContent")
1374 |   64 |     }
1375 |   65 |     
1376 |   66 |     static func testScreenshotAttachment() throws {
1377 |   67 |         let image = NSImage(size: NSSize(width: 1920, height: 1080))
1378 |   68 |         let id = UUID()
1379 |   69 |         
1380 |   70 |         let attachment = Attachment.screenshot(image, nil, id)
1381 |   71 |         
1382 |   72 |         try assertEqual(attachment.id, id, "ID")
1383 |   73 |         try assertEqual(attachment.displayTitle, "截图", "displayTitle")
1384 |   74 |         try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
1385 |   75 |         try assertNotNil(attachment.originalImage, "originalImage")
1386 |   76 |     }
1387 |   77 |     
1388 |   78 |     static func testFileAttachment() throws {
1389 |   79 |         let url = URL(fileURLWithPath: "/tmp/test.pdf")
1390 |   80 |         let id = UUID()
1391 |   81 |         
1392 |   82 |         let attachment = Attachment.file(url, id)
1393 |   83 |         
1394 |   84 |         try assertEqual(attachment.id, id, "ID")
1395 |   85 |         try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
1396 |   86 |         try assertEqual(attachment.fileName, "test.pdf", "fileName")
1397 |   87 |         try assertNil(attachment.thumbnail, "thumbnail")
1398 |   88 |         try assertNil(attachment.originalImage, "originalImage")
1399 |   89 |     }
1400 |   90 |     
1401 |   91 |     static func testTextBundleAttachment() throws {
1402 |   92 |         let content = "# Code content\nlet x = 1"
1403 |   93 |         let source = "my-project"
1404 |   94 |         let count = 42
1405 |   95 |         let id = UUID()
1406 |   96 |         
1407 |   97 |         let attachment = Attachment.textBundle(content, source, count, id)
1408 |   98 |         
1409 |   99 |         try assertEqual(attachment.id, id, "ID")
1410 |  100 |         try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
1411 |  101 |         try assertEqual(attachment.fileName, source, "fileName")
1412 |  102 |         try assertTrue(attachment.isTextBundle, "isTextBundle")
1413 |  103 |         try assertEqual(attachment.textContent, content, "textContent")
1414 |  104 |     }
1415 |  105 |     
1416 |  106 |     static func testVideoDetection() throws {
1417 |  107 |         let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
1418 |  108 |         let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
1419 |  109 |         let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
1420 |  110 |         
1421 |  111 |         try assertTrue(mp4.isVideo, "mp4 should be video")
1422 |  112 |         try assertTrue(mov.isVideo, "mov should be video")
1423 |  113 |         try assertFalse(txt.isVideo, "txt should not be video")
1424 |  114 |     }
1425 |  115 |     
1426 |  116 |     static func testEqualityById() throws {
1427 |  117 |         let id = UUID()
1428 |  118 |         let image1 = NSImage(size: NSSize(width: 100, height: 100))
1429 |  119 |         let image2 = NSImage(size: NSSize(width: 200, height: 200))
1430 |  120 |         
1431 |  121 |         let att1 = Attachment.image(image1, nil, id)
1432 |  122 |         let att2 = Attachment.image(image2, nil, id)
1433 |  123 |         let att3 = Attachment.image(image1, nil, UUID())
1434 |  124 |         
1435 |  125 |         try assertTrue(att1 == att2, "Same ID should be equal")
1436 |  126 |         try assertFalse(att1 == att3, "Different ID should not be equal")
1437 |  127 |     }
1438 |  128 |     
1439 |  129 |     // MARK: - Test Cases: Thumbnail Generation
1440 |  130 |     
1441 |  131 |     static func testThumbnailResizesLarge() throws {
1442 |  132 |         let large = createTestImage(width: 2000, height: 1000)
1443 |  133 |         let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
1444 |  134 |         
1445 |  135 |         try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
1446 |  136 |         try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
1447 |  137 |     }
1448 |  138 |     
1449 |  139 |     static func testThumbnailPreservesRatio() throws {
1450 |  140 |         let image = createTestImage(width: 2000, height: 1000)
1451 |  141 |         let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
1452 |  142 |         
1453 |  143 |         let ratio = thumb.size.width / thumb.size.height
1454 |  144 |         try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
1455 |  145 |     }
1456 |  146 |     
1457 |  147 |     static func testThumbnailNoUpscale() throws {
1458 |  148 |         let small = createTestImage(width: 50, height: 50)
1459 |  149 |         let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
1460 |  150 |         
1461 |  151 |         try assertEqual(thumb.size.width, 50, "Width")
1462 |  152 |         try assertEqual(thumb.size.height, 50, "Height")
1463 |  153 |     }
1464 |  154 |     
1465 |  155 |     static func testThumbnailZeroSize() throws {
1466 |  156 |         let zero = NSImage(size: NSSize(width: 0, height: 0))
1467 |  157 |         let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
1468 |  158 |         
1469 |  159 |         try assertEqual(thumb.size.width, 0, "Width")
1470 |  160 |     }
1471 |  161 |     
1472 |  162 |     // MARK: - Helpers
1473 |  163 |     
1474 |  164 |     static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
1475 |  165 |         let image = NSImage(size: NSSize(width: width, height: height))
1476 |  166 |         image.lockFocus()
1477 |  167 |         NSColor.red.setFill()
1478 |  168 |         NSRect(x: 0, y: 0, width: width, height: height).fill()
1479 |  169 |         image.unlockFocus()
1480 |  170 |         return image
1481 |  171 |     }
1482 |  172 | }
1483 |  173 | 
1484 |  174 | // MARK: - Attachment Type (简化版，用于测试)
1485 |  175 | 
1486 |  176 | import UniformTypeIdentifiers
1487 |  177 | 
1488 |  178 | enum Attachment: Identifiable, Equatable {
1489 |  179 |     case image(NSImage, NSImage?, UUID)
1490 |  180 |     case screenshot(NSImage, NSImage?, UUID)
1491 |  181 |     case file(URL, UUID)
1492 |  182 |     case textBundle(String, String, Int, UUID)
1493 |  183 |     
1494 |  184 |     var id: UUID {
1495 |  185 |         switch self {
1496 |  186 |         case .image(_, _, let id), .screenshot(_, _, let id),
1497 |  187 |              .file(_, let id), .textBundle(_, _, _, let id):
1498 |  188 |             return id
1499 |  189 |         }
1500 |  190 |     }
1501 |  191 |     
1502 |  192 |     var thumbnail: NSImage? {
1503 |  193 |         switch self {
1504 |  194 |         case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
1505 |  195 |         default: return nil
1506 |  196 |         }
1507 |  197 |     }
1508 |  198 |     
1509 |  199 |     var originalImage: NSImage? {
1510 |  200 |         switch self {
1511 |  201 |         case .image(let img, _, _), .screenshot(let img, _, _): return img
1512 |  202 |         default: return nil
1513 |  203 |         }
1514 |  204 |     }
1515 |  205 |     
1516 |  206 |     var fileName: String? {
1517 |  207 |         switch self {
1518 |  208 |         case .file(let url, _): return url.lastPathComponent
1519 |  209 |         case .textBundle(_, let source, _, _): return source
1520 |  210 |         default: return nil
1521 |  211 |         }
1522 |  212 |     }
1523 |  213 |     
1524 |  214 |     var displayTitle: String {
1525 |  215 |         switch self {
1526 |  216 |         case .image: return "图片"
1527 |  217 |         case .screenshot: return "截图"
1528 |  218 |         case .file(let url, _): return url.lastPathComponent
1529 |  219 |         case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
1530 |  220 |         }
1531 |  221 |     }
1532 |  222 |     
1533 |  223 |     var isVideo: Bool {
1534 |  224 |         if case .file(let url, _) = self,
1535 |  225 |            let uti = UTType(filenameExtension: url.pathExtension) {
1536 |  226 |             return uti.conforms(to: .movie) || uti.conforms(to: .video)
1537 |  227 |         }
1538 |  228 |         return false
1539 |  229 |     }
1540 |  230 |     
1541 |  231 |     var isTextBundle: Bool {
1542 |  232 |         if case .textBundle = self { return true }
1543 |  233 |         return false
1544 |  234 |     }
1545 |  235 |     
1546 |  236 |     var textContent: String? {
1547 |  237 |         if case .textBundle(let content, _, _, _) = self { return content }
1548 |  238 |         return nil
1549 |  239 |     }
1550 |  240 |     
1551 |  241 |     static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
1552 |  242 |     
1553 |  243 |     static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
1554 |  244 |         let size = image.size
1555 |  245 |         guard size.width > 0 && size.height > 0 else { return image }
1556 |  246 |         
1557 |  247 |         let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
1558 |  248 |         let newSize = NSSize(width: size.width * scale, height: size.height * scale)
1559 |  249 |         
1560 |  250 |         let thumbnail = NSImage(size: newSize)
1561 |  251 |         thumbnail.lockFocus()
1562 |  252 |         image.draw(in: NSRect(origin: .zero, size: newSize),
1563 |  253 |                    from: NSRect(origin: .zero, size: size),
1564 |  254 |                    operation: .copy, fraction: 1.0)
1565 |  255 |         thumbnail.unlockFocus()
1566 |  256 |         return thumbnail
1567 |  257 |     }
1568 |  258 | }
1569 |  259 | 
1570 |  260 | // MARK: - Assertion Helpers
1571 |  261 | 
1572 |  262 | struct TestError: Error, CustomStringConvertible {
1573 |  263 |     let message: String
1574 |  264 |     init(_ message: String) { self.message = message }
1575 |  265 |     var description: String { message }
1576 |  266 | }
1577 |  267 | 
1578 |  268 | func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
1579 |  269 |     if actual != expected {
1580 |  270 |         throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
1581 |  271 |     }
1582 |  272 | }
1583 |  273 | 
1584 |  274 | func assertTrue(_ condition: Bool, _ message: String) throws {
1585 |  275 |     if !condition { throw TestError(message) }
1586 |  276 | }
1587 |  277 | 
1588 |  278 | func assertFalse(_ condition: Bool, _ message: String) throws {
1589 |  279 |     if condition { throw TestError(message) }
1590 |  280 | }
1591 |  281 | 
1592 |  282 | func assertNil<T>(_ value: T?, _ message: String) throws {
1593 |  283 |     if value != nil { throw TestError("\(message) 应该是 nil") }
1594 |  284 | }
1595 |  285 | 
1596 |  286 | func assertNotNil<T>(_ value: T?, _ message: String) throws {
1597 |  287 |     if value == nil { throw TestError("\(message) 不应该是 nil") }
1598 |  288 | }
1599 |  289 | 
1600 |  290 | extension String {
1601 |  291 |     static func * (string: String, count: Int) -> String {
1602 |  292 |         String(repeating: string, count: count)
1603 |  293 |     }
1604 |  294 | }
1605 | 
1606 | ```
1607 | 
1608 | `spoke/Tests/EdgeTTSTests.swift`:
1609 | 
1610 | ```swift
1611 |    1 | import Foundation
1612 |    2 | import AVFoundation
1613 |    3 | 
1614 |    4 | // MARK: - Edge TTS 单元测试
1615 |    5 | 
1616 |    6 | @main
1617 |    7 | struct EdgeTTSTests {
1618 |    8 |     static func main() async {
1619 |    9 |         print("🧪 Edge TTS 单元测试")
1620 |   10 |         print("=" * 50)
1621 |   11 |         
1622 |   12 |         await testSynthesizeAndPlay()
1623 |   13 |     }
1624 |   14 |     
1625 |   15 |     /// 测试合成并播放
1626 |   16 |     static func testSynthesizeAndPlay() async {
1627 |   17 |         print("\n📝 测试: 合成并播放")
1628 |   18 |         
1629 |   19 |         let text = "你好，这是语音合成测试。"
1630 |   20 |         let voice = "zh-CN-XiaoxiaoNeural"
1631 |   21 |         
1632 |   22 |         do {
1633 |   23 |             // 1. 合成音频
1634 |   24 |             print("   正在合成...")
1635 |   25 |             let audioData = try await synthesize(text: text, voice: voice)
1636 |   26 |             print("   ✅ 合成完成: \(audioData.count) bytes")
1637 |   27 |             
1638 |   28 |             // 2. 检查音频头
1639 |   29 |             print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
1640 |   30 |             
1641 |   31 |             // 3. 保存到文件测试
1642 |   32 |             let tempPath = "/tmp/edge_tts_test.mp3"
1643 |   33 |             try audioData.write(to: URL(fileURLWithPath: tempPath))
1644 |   34 |             print("   ✅ 已保存到: \(tempPath)")
1645 |   35 |             
1646 |   36 |             // 4. 用 AVAudioPlayer 播放
1647 |   37 |             print("   正在播放...")
1648 |   38 |             let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
1649 |   39 |             player.prepareToPlay()
1650 |   40 |             player.play()
1651 |   41 |             
1652 |   42 |             // 等待播放完成
1653 |   43 |             while player.isPlaying {
1654 |   44 |                 try await Task.sleep(nanoseconds: 100_000_000)
1655 |   45 |             }
1656 |   46 |             print("   ✅ 播放完成!")
1657 |   47 |             
1658 |   48 |         } catch {
1659 |   49 |             print("   ❌ 错误: \(error)")
1660 |   50 |         }
1661 |   51 |     }
1662 |   52 |     
1663 |   53 |     /// 合成音频
1664 |   54 |     static func synthesize(text: String, voice: String) async throws -> Data {
1665 |   55 |         // DRM Token
1666 |   56 |         let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
1667 |   57 |         let chromiumVersion = "130.0.2849.68"
1668 |   58 |         let windowsFileTimeEpoch: Int64 = 11_644_473_600
1669 |   59 |         
1670 |   60 |         let currentTime = Int64(Date().timeIntervalSince1970)
1671 |   61 |         let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
1672 |   62 |         let roundedTicks = ticks - (ticks % 3_000_000_000)
1673 |   63 |         let strToHash = "\(roundedTicks)\(trustedClientToken)"
1674 |   64 |         
1675 |   65 |         // SHA256
1676 |   66 |         import CryptoKit
1677 |   67 |         let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
1678 |   68 |         let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
1679 |   69 |         
1680 |   70 |         // URL
1681 |   71 |         let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
1682 |   72 |         let url = URL(string: urlString)!
1683 |   73 |         
1684 |   74 |         // WebSocket
1685 |   75 |         var request = URLRequest(url: url)
1686 |   76 |         request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
1687 |   77 |         request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
1688 |   78 |         
1689 |   79 |         let session = URLSession.shared
1690 |   80 |         let ws = session.webSocketTask(with: request)
1691 |   81 |         ws.resume()
1692 |   82 |         
1693 |   83 |         // 等待连接
1694 |   84 |         try await Task.sleep(nanoseconds: 500_000_000)
1695 |   85 |         
1696 |   86 |         // 发送配置
1697 |   87 |         let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
1698 |   88 |         try await ws.send(.string(configMessage))
1699 |   89 |         
1700 |   90 |         // 发送 SSML
1701 |   91 |         let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
1702 |   92 |         let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
1703 |   93 |         try await ws.send(.string(ssmlMessage))
1704 |   94 |         
1705 |   95 |         // 接收音频
1706 |   96 |         var audioData = Data()
1707 |   97 |         
1708 |   98 |         while true {
1709 |   99 |             let message = try await ws.receive()
1710 |  100 |             
1711 |  101 |             switch message {
1712 |  102 |             case .data(let data):
1713 |  103 |                 // 检查是否包含 Path:audio
1714 |  104 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
1715 |  105 |                     if let range = str.range(of: "Path:audio\r\n") {
1716 |  106 |                         let offset = range.upperBound.utf16Offset(in: str)
1717 |  107 |                         audioData.append(data[offset...])
1718 |  108 |                     }
1719 |  109 |                 } else {
1720 |  110 |                     audioData.append(data)
1721 |  111 |                 }
1722 |  112 |                 
1723 |  113 |             case .string(let str):
1724 |  114 |                 if str.contains("Path:turn.end") {
1725 |  115 |                     ws.cancel(with: .goingAway, reason: nil)
1726 |  116 |                     return audioData
1727 |  117 |                 }
1728 |  118 |                 
1729 |  119 |             @unknown default:
1730 |  120 |                 break
1731 |  121 |             }
1732 |  122 |         }
1733 |  123 |     }
1734 |  124 | }
1735 |  125 | 
1736 |  126 | extension String {
1737 |  127 |     static func * (string: String, count: Int) -> String {
1738 |  128 |         String(repeating: string, count: count)
1739 |  129 |     }
1740 |  130 | }
1741 | 
1742 | ```
1743 | 
1744 | `spoke/Tests/TextExtractionTests.swift`:
1745 | 
1746 | ```swift
1747 |    1 | import Foundation
1748 |    2 | 
1749 |    3 | // MARK: - Text Extraction Service Tests
1750 |    4 | 
1751 |    5 | /// 独立运行的测试脚本
1752 |    6 | /// 用法: swift Tests/TextExtractionTests.swift
1753 |    7 | @main
1754 |    8 | struct TextExtractionTests {
1755 |    9 |     
1756 |   10 |     static var tempDirectory: URL!
1757 |   11 |     static var passCount = 0
1758 |   12 |     static var failCount = 0
1759 |   13 |     
1760 |   14 |     static func main() async {
1761 |   15 |         print("🧪 TextExtractionService 单元测试")
1762 |   16 |         print("=" * 50)
1763 |   17 |         
1764 |   18 |         // 创建临时目录
1765 |   19 |         tempDirectory = FileManager.default.temporaryDirectory
1766 |   20 |             .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
1767 |   21 |         try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1768 |   22 |         
1769 |   23 |         defer {
1770 |   24 |             // 清理
1771 |   25 |             try? FileManager.default.removeItem(at: tempDirectory)
1772 |   26 |             print("\n" + "=" * 50)
1773 |   27 |             print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
1774 |   28 |         }
1775 |   29 |         
1776 |   30 |         // 运行测试
1777 |   31 |         await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
1778 |   32 |         await runTest("单文件提取") { try await testSingleFileExtraction() }
1779 |   33 |         await runTest("多文件合并") { try await testMultipleFilesExtraction() }
1780 |   34 |         await runTest("排除 node_modules") { try await testExcludesNodeModules() }
1781 |   35 |         await runTest("排除锁文件") { try await testExcludesLockFiles() }
1782 |   36 |         await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
1783 |   37 |         await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
1784 |   38 |         await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
1785 |   39 |         await runTest("添加行号") { try await testAddsLineNumbers() }
1786 |   40 |         await runTest("目录结构输出") { try await testDirectoryStructure() }
1787 |   41 |         await runTest("ZIP 提取") { try await testZIPExtraction() }
1788 |   42 |     }
1789 |   43 |     
1790 |   44 |     // MARK: - Test Runner
1791 |   45 |     
1792 |   46 |     static func runTest(_ name: String, _ test: () async throws -> Void) async {
1793 |   47 |         print("\n📝 测试: \(name)")
1794 |   48 |         do {
1795 |   49 |             try await test()
1796 |   50 |             print("   ✅ 通过")
1797 |   51 |             passCount += 1
1798 |   52 |         } catch {
1799 |   53 |             print("   ❌ 失败: \(error)")
1800 |   54 |             failCount += 1
1801 |   55 |         }
1802 |   56 |     }
1803 |   57 |     
1804 |   58 |     // MARK: - Helpers
1805 |   59 |     
1806 |   60 |     static func createFile(name: String, content: String) throws -> URL {
1807 |   61 |         let fileURL = tempDirectory.appendingPathComponent(name)
1808 |   62 |         let dir = fileURL.deletingLastPathComponent()
1809 |   63 |         try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
1810 |   64 |         try content.write(to: fileURL, atomically: true, encoding: .utf8)
1811 |   65 |         return fileURL
1812 |   66 |     }
1813 |   67 |     
1814 |   68 |     static func createDirectory(name: String) throws -> URL {
1815 |   69 |         let dirURL = tempDirectory.appendingPathComponent(name)
1816 |   70 |         try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
1817 |   71 |         return dirURL
1818 |   72 |     }
1819 |   73 |     
1820 |   74 |     // MARK: - Test Cases
1821 |   75 |     
1822 |   76 |     static func testCodeExtensions() async throws {
1823 |   77 |         // 创建各种代码文件
1824 |   78 |         _ = try createFile(name: "test.swift", content: "let x = 1")
1825 |   79 |         _ = try createFile(name: "app.js", content: "const x = 1")
1826 |   80 |         _ = try createFile(name: "main.py", content: "x = 1")
1827 |   81 |         _ = try createFile(name: "README.md", content: "# Title")
1828 |   82 |         
1829 |   83 |         let result = await extractFromFolder(tempDirectory)
1830 |   84 |         guard case .success(let bundle) = result else {
1831 |   85 |             throw TestError("提取失败")
1832 |   86 |         }
1833 |   87 |         
1834 |   88 |         guard bundle.fileCount == 4 else {
1835 |   89 |             throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
1836 |   90 |         }
1837 |   91 |     }
1838 |   92 |     
1839 |   93 |     static func testSingleFileExtraction() async throws {
1840 |   94 |         // 清理并创建新目录
1841 |   95 |         try FileManager.default.removeItem(at: tempDirectory)
1842 |   96 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1843 |   97 |         
1844 |   98 |         _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
1845 |   99 |         
1846 |  100 |         let result = await extractFromFolder(tempDirectory)
1847 |  101 |         guard case .success(let bundle) = result else {
1848 |  102 |             throw TestError("提取失败")
1849 |  103 |         }
1850 |  104 |         
1851 |  105 |         guard bundle.fileCount == 1 else {
1852 |  106 |             throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
1853 |  107 |         }
1854 |  108 |         guard bundle.content.contains("print(\"Hello\")") else {
1855 |  109 |             throw TestError("内容不包含预期文本")
1856 |  110 |         }
1857 |  111 |     }
1858 |  112 |     
1859 |  113 |     static func testMultipleFilesExtraction() async throws {
1860 |  114 |         try FileManager.default.removeItem(at: tempDirectory)
1861 |  115 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1862 |  116 |         
1863 |  117 |         _ = try createFile(name: "a.swift", content: "let a = 1")
1864 |  118 |         _ = try createFile(name: "b.swift", content: "let b = 2")
1865 |  119 |         _ = try createFile(name: "c.js", content: "const c = 3")
1866 |  120 |         
1867 |  121 |         let result = await extractFromFolder(tempDirectory)
1868 |  122 |         guard case .success(let bundle) = result else {
1869 |  123 |             throw TestError("提取失败")
1870 |  124 |         }
1871 |  125 |         
1872 |  126 |         guard bundle.fileCount == 3 else {
1873 |  127 |             throw TestError("文件数量错误")
1874 |  128 |         }
1875 |  129 |         guard bundle.content.contains("let a = 1") &&
1876 |  130 |               bundle.content.contains("let b = 2") &&
1877 |  131 |               bundle.content.contains("const c = 3") else {
1878 |  132 |             throw TestError("内容缺失")
1879 |  133 |         }
1880 |  134 |     }
1881 |  135 |     
1882 |  136 |     static func testExcludesNodeModules() async throws {
1883 |  137 |         try FileManager.default.removeItem(at: tempDirectory)
1884 |  138 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1885 |  139 |         
1886 |  140 |         let nodeModules = try createDirectory(name: "node_modules")
1887 |  141 |         try "const secret = 'password'".write(
1888 |  142 |             to: nodeModules.appendingPathComponent("secret.js"),
1889 |  143 |             atomically: true, encoding: .utf8
1890 |  144 |         )
1891 |  145 |         _ = try createFile(name: "app.js", content: "const app = 1")
1892 |  146 |         
1893 |  147 |         let result = await extractFromFolder(tempDirectory)
1894 |  148 |         guard case .success(let bundle) = result else {
1895 |  149 |             throw TestError("提取失败")
1896 |  150 |         }
1897 |  151 |         
1898 |  152 |         guard bundle.fileCount == 1 else {
1899 |  153 |             throw TestError("应该只包含 app.js")
1900 |  154 |         }
1901 |  155 |         guard !bundle.content.contains("secret") else {
1902 |  156 |             throw TestError("不应包含 node_modules 内容")
1903 |  157 |         }
1904 |  158 |     }
1905 |  159 |     
1906 |  160 |     static func testExcludesLockFiles() async throws {
1907 |  161 |         try FileManager.default.removeItem(at: tempDirectory)
1908 |  162 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1909 |  163 |         
1910 |  164 |         _ = try createFile(name: "package-lock.json", content: "{}")
1911 |  165 |         _ = try createFile(name: "yarn.lock", content: "")
1912 |  166 |         _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
1913 |  167 |         
1914 |  168 |         let result = await extractFromFolder(tempDirectory)
1915 |  169 |         guard case .success(let bundle) = result else {
1916 |  170 |             throw TestError("提取失败")
1917 |  171 |         }
1918 |  172 |         
1919 |  173 |         guard bundle.fileCount == 1 else {
1920 |  174 |             throw TestError("应该只包含 package.json")
1921 |  175 |         }
1922 |  176 |     }
1923 |  177 |     
1924 |  178 |     static func testNestedDirectories() async throws {
1925 |  179 |         try FileManager.default.removeItem(at: tempDirectory)
1926 |  180 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1927 |  181 |         
1928 |  182 |         _ = try createFile(name: "root.swift", content: "let root = 1")
1929 |  183 |         _ = try createFile(name: "src/app.swift", content: "let src = 2")
1930 |  184 |         _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
1931 |  185 |         
1932 |  186 |         let result = await extractFromFolder(tempDirectory)
1933 |  187 |         guard case .success(let bundle) = result else {
1934 |  188 |             throw TestError("提取失败")
1935 |  189 |         }
1936 |  190 |         
1937 |  191 |         guard bundle.fileCount == 3 else {
1938 |  192 |             throw TestError("应该包含 3 个文件")
1939 |  193 |         }
1940 |  194 |         guard bundle.content.contains("let root = 1") &&
1941 |  195 |               bundle.content.contains("let src = 2") &&
1942 |  196 |               bundle.content.contains("let lib = 3") else {
1943 |  197 |             throw TestError("缺少嵌套目录内容")
1944 |  198 |         }
1945 |  199 |     }
1946 |  200 |     
1947 |  201 |     static func testEmptyFolderError() async throws {
1948 |  202 |         try FileManager.default.removeItem(at: tempDirectory)
1949 |  203 |         let emptyDir = try createDirectory(name: "empty")
1950 |  204 |         
1951 |  205 |         let result = await extractFromFolder(emptyDir)
1952 |  206 |         guard case .failure = result else {
1953 |  207 |             throw TestError("空文件夹应该返回错误")
1954 |  208 |         }
1955 |  209 |     }
1956 |  210 |     
1957 |  211 |     static func testIgnoresNonCodeFiles() async throws {
1958 |  212 |         try FileManager.default.removeItem(at: tempDirectory)
1959 |  213 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1960 |  214 |         
1961 |  215 |         _ = try createFile(name: "image.png", content: "fake")
1962 |  216 |         _ = try createFile(name: "video.mp4", content: "fake")
1963 |  217 |         _ = try createFile(name: "main.swift", content: "let x = 1")
1964 |  218 |         
1965 |  219 |         let result = await extractFromFolder(tempDirectory)
1966 |  220 |         guard case .success(let bundle) = result else {
1967 |  221 |             throw TestError("提取失败")
1968 |  222 |         }
1969 |  223 |         
1970 |  224 |         guard bundle.fileCount == 1 else {
1971 |  225 |             throw TestError("应该只包含 .swift 文件")
1972 |  226 |         }
1973 |  227 |     }
1974 |  228 |     
1975 |  229 |     static func testAddsLineNumbers() async throws {
1976 |  230 |         try FileManager.default.removeItem(at: tempDirectory)
1977 |  231 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1978 |  232 |         
1979 |  233 |         _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
1980 |  234 |         
1981 |  235 |         let result = await extractFromFolder(tempDirectory)
1982 |  236 |         guard case .success(let bundle) = result else {
1983 |  237 |             throw TestError("提取失败")
1984 |  238 |         }
1985 |  239 |         
1986 |  240 |         guard bundle.content.contains("1│") &&
1987 |  241 |               bundle.content.contains("2│") &&
1988 |  242 |               bundle.content.contains("3│") else {
1989 |  243 |             throw TestError("缺少行号")
1990 |  244 |         }
1991 |  245 |     }
1992 |  246 |     
1993 |  247 |     static func testDirectoryStructure() async throws {
1994 |  248 |         try FileManager.default.removeItem(at: tempDirectory)
1995 |  249 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
1996 |  250 |         
1997 |  251 |         _ = try createFile(name: "main.swift", content: "entry")
1998 |  252 |         _ = try createFile(name: "src/app.swift", content: "code")
1999 |  253 |         
2000 |  254 |         let result = await extractFromFolder(tempDirectory)
2001 |  255 |         guard case .success(let bundle) = result else {
2002 |  256 |             throw TestError("提取失败")
2003 |  257 |         }
2004 |  258 |         
2005 |  259 |         guard bundle.content.contains("# 目录结构") else {
2006 |  260 |             throw TestError("缺少目录结构标题")
2007 |  261 |         }
2008 |  262 |     }
2009 |  263 |     
2010 |  264 |     static func testZIPExtraction() async throws {
2011 |  265 |         try FileManager.default.removeItem(at: tempDirectory)
2012 |  266 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
2013 |  267 |         
2014 |  268 |         // 创建源文件
2015 |  269 |         let sourceDir = try createDirectory(name: "source")
2016 |  270 |         try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
2017 |  271 |         
2018 |  272 |         // 创建 ZIP
2019 |  273 |         let zipPath = tempDirectory.appendingPathComponent("test.zip")
2020 |  274 |         let process = Process()
2021 |  275 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
2022 |  276 |         process.currentDirectoryURL = tempDirectory
2023 |  277 |         process.arguments = ["-r", zipPath.path, "source"]
2024 |  278 |         process.standardOutput = FileHandle.nullDevice
2025 |  279 |         process.standardError = FileHandle.nullDevice
2026 |  280 |         try process.run()
2027 |  281 |         process.waitUntilExit()
2028 |  282 |         
2029 |  283 |         guard process.terminationStatus == 0 else {
2030 |  284 |             throw TestError("创建 ZIP 失败")
2031 |  285 |         }
2032 |  286 |         
2033 |  287 |         let result = await extractFromZIP(zipPath)
2034 |  288 |         guard case .success(let bundle) = result else {
2035 |  289 |             throw TestError("ZIP 提取失败")
2036 |  290 |         }
2037 |  291 |         
2038 |  292 |         guard bundle.fileCount == 1 else {
2039 |  293 |             throw TestError("ZIP 文件数量错误")
2040 |  294 |         }
2041 |  295 |         guard bundle.content.contains("let x = 1") else {
2042 |  296 |             throw TestError("ZIP 内容缺失")
2043 |  297 |         }
2044 |  298 |     }
2045 |  299 | }
2046 |  300 | 
2047 |  301 | // MARK: - TextExtractionService (简化版，用于测试)
2048 |  302 | 
2049 |  303 | struct TextBundle {
2050 |  304 |     let content: String
2051 |  305 |     let fileCount: Int
2052 |  306 |     let sourcePath: String
2053 |  307 |     let files: [String]
2054 |  308 | }
2055 |  309 | 
2056 |  310 | enum TextExtractionError: Error, Equatable {
2057 |  311 |     case folderNotFound
2058 |  312 |     case zipExtractionFailed(String)
2059 |  313 |     case noTextFilesFound
2060 |  314 |     case accessDenied
2061 |  315 | }
2062 |  316 | 
2063 |  317 | func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
2064 |  318 |     let codeExtensions: Set<String> = [
2065 |  319 |         "js", "jsx", "ts", "tsx", "mjs", "cjs",
2066 |  320 |         "html", "htm", "css", "scss", "less", "vue", "svelte",
2067 |  321 |         "py", "pyw", "pyi",
2068 |  322 |         "java", "kt", "kts", "scala",
2069 |  323 |         "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
2070 |  324 |         "rs", "go", "rb", "erb", "php", "swift",
2071 |  325 |         "sh", "bash", "zsh", "fish",
2072 |  326 |         "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
2073 |  327 |         "md", "mdx", "txt", "rst", "asciidoc",
2074 |  328 |         "sql", "graphql", "proto", "dockerfile"
2075 |  329 |     ]
2076 |  330 |     
2077 |  331 |     let excludedDirs: Set<String> = [
2078 |  332 |         "node_modules", ".git", ".svn", ".hg",
2079 |  333 |         "dist", "build", "target", ".next", ".nuxt",
2080 |  334 |         "__pycache__", ".pytest_cache", ".tox",
2081 |  335 |         "venv", "env", ".env", ".venv",
2082 |  336 |         "vendor", "Pods", "Carthage",
2083 |  337 |         ".idea", ".vscode", ".vs"
2084 |  338 |     ]
2085 |  339 |     
2086 |  340 |     let excludedFiles: Set<String> = [
2087 |  341 |         ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
2088 |  342 |         "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
2089 |  343 |         "Podfile.lock", "Gemfile.lock", "Cargo.lock"
2090 |  344 |     ]
2091 |  345 |     
2092 |  346 |     // 递归收集文件
2093 |  347 |     func collectFiles(in directory: URL) -> [URL] {
2094 |  348 |         var result: [URL] = []
2095 |  349 |         let fm = FileManager.default
2096 |  350 |         
2097 |  351 |         guard let contents = try? fm.contentsOfDirectory(
2098 |  352 |             at: directory,
2099 |  353 |             includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
2100 |  354 |             options: [.skipsHiddenFiles]
2101 |  355 |         ) else { return [] }
2102 |  356 |         
2103 |  357 |         for url in contents {
2104 |  358 |             let fileName = url.lastPathComponent
2105 |  359 |             if excludedFiles.contains(fileName) { continue }
2106 |  360 |             
2107 |  361 |             let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
2108 |  362 |             
2109 |  363 |             if values?.isDirectory == true {
2110 |  364 |                 if !excludedDirs.contains(fileName) {
2111 |  365 |                     result.append(contentsOf: collectFiles(in: url))
2112 |  366 |                 }
2113 |  367 |             } else if values?.isRegularFile == true {
2114 |  368 |                 let ext = url.pathExtension.lowercased()
2115 |  369 |                 if codeExtensions.contains(ext) {
2116 |  370 |                     result.append(url)
2117 |  371 |                 }
2118 |  372 |             }
2119 |  373 |         }
2120 |  374 |         return result.sorted { $0.path < $1.path }
2121 |  375 |     }
2122 |  376 |     
2123 |  377 |     let files = collectFiles(in: folderURL)
2124 |  378 |     guard !files.isEmpty else {
2125 |  379 |         return .failure(.noTextFilesFound)
2126 |  380 |     }
2127 |  381 |     
2128 |  382 |     // 合并内容
2129 |  383 |     var parts: [String] = ["# 目录结构\n```"]
2130 |  384 |     for file in files {
2131 |  385 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
2132 |  386 |         parts.append(rel)
2133 |  387 |     }
2134 |  388 |     parts.append("```\n\n# 文件内容\n")
2135 |  389 |     
2136 |  390 |     for file in files {
2137 |  391 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
2138 |  392 |         let ext = file.pathExtension
2139 |  393 |         if let content = try? String(contentsOf: file, encoding: .utf8) {
2140 |  394 |             let numbered = content.components(separatedBy: .newlines).enumerated()
2141 |  395 |                 .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
2142 |  396 |             parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
2143 |  397 |         }
2144 |  398 |     }
2145 |  399 |     
2146 |  400 |     return .success(TextBundle(
2147 |  401 |         content: parts.joined(separator: "\n"),
2148 |  402 |         fileCount: files.count,
2149 |  403 |         sourcePath: folderURL.path,
2150 |  404 |         files: files.map { $0.path }
2151 |  405 |     ))
2152 |  406 | }
2153 |  407 | 
2154 |  408 | func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
2155 |  409 |     let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
2156 |  410 |     try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
2157 |  411 |     defer { try? FileManager.default.removeItem(at: tempDir) }
2158 |  412 |     
2159 |  413 |     let process = Process()
2160 |  414 |     process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
2161 |  415 |     process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
2162 |  416 |     process.standardOutput = FileHandle.nullDevice
2163 |  417 |     process.standardError = FileHandle.nullDevice
2164 |  418 |     
2165 |  419 |     do {
2166 |  420 |         try process.run()
2167 |  421 |         process.waitUntilExit()
2168 |  422 |         
2169 |  423 |         guard process.terminationStatus == 0 else {
2170 |  424 |             return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
2171 |  425 |         }
2172 |  426 |         
2173 |  427 |         return await extractFromFolder(tempDir)
2174 |  428 |     } catch {
2175 |  429 |         return .failure(.zipExtractionFailed(error.localizedDescription))
2176 |  430 |     }
2177 |  431 | }
2178 |  432 | 
2179 |  433 | // MARK: - Helpers
2180 |  434 | 
2181 |  435 | struct TestError: Error, CustomStringConvertible {
2182 |  436 |     let message: String
2183 |  437 |     init(_ message: String) { self.message = message }
2184 |  438 |     var description: String { message }
2185 |  439 | }
2186 |  440 | 
2187 |  441 | extension String {
2188 |  442 |     static func * (string: String, count: Int) -> String {
2189 |  443 |         String(repeating: string, count: count)
2190 |  444 |     }
2191 |  445 | }
2192 | 
2193 | ```
2194 | 
2195 | `spoke/Tests/test_edge_tts.swift`:
2196 | 
2197 | ```swift
2198 |    1 | #!/usr/bin/env swift
2199 |    2 | 
2200 |    3 | import Foundation
2201 |    4 | import CryptoKit
2202 |    5 | import AVFoundation
2203 |    6 | 
2204 |    7 | // MARK: - Edge TTS 测试脚本
2205 |    8 | 
2206 |    9 | print("🧪 Edge TTS 测试")
2207 |   10 | print(String(repeating: "=", count: 50))
2208 |   11 | 
2209 |   12 | // 配置
2210 |   13 | let text = "你好，这是语音合成测试。Hello, this is a test."
2211 |   14 | let voice = "zh-CN-XiaoxiaoNeural"
2212 |   15 | let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
2213 |   16 | let chromiumVersion = "130.0.2849.68"
2214 |   17 | let windowsFileTimeEpoch: Int64 = 11_644_473_600
2215 |   18 | 
2216 |   19 | // 生成 DRM Token
2217 |   20 | func generateSecMsGecToken() -> String {
2218 |   21 |     let currentTime = Int64(Date().timeIntervalSince1970)
2219 |   22 |     let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
2220 |   23 |     let roundedTicks = ticks - (ticks % 3_000_000_000)
2221 |   24 |     let strToHash = "\(roundedTicks)\(trustedClientToken)"
2222 |   25 |     let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
2223 |   26 |     return hash.map { String(format: "%02X", $0) }.joined()
2224 |   27 | }
2225 |   28 | 
2226 |   29 | // WebSocket Delegate
2227 |   30 | class WSDelegate: NSObject, URLSessionWebSocketDelegate {
2228 |   31 |     var onOpen: (() -> Void)?
2229 |   32 |     
2230 |   33 |     func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
2231 |   34 |         print("   ✅ WebSocket 已连接")
2232 |   35 |         onOpen?()
2233 |   36 |     }
2234 |   37 | }
2235 |   38 | 
2236 |   39 | // 主测试
2237 |   40 | func runTest() async {
2238 |   41 |     print("\n📝 测试文本: \(text)")
2239 |   42 |     print("🎤 语音: \(voice)")
2240 |   43 |     
2241 |   44 |     // 构建 URL
2242 |   45 |     let secMsGec = generateSecMsGecToken()
2243 |   46 |     let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
2244 |   47 |     
2245 |   48 |     guard let url = URL(string: urlString) else {
2246 |   49 |         print("❌ URL 无效")
2247 |   50 |         return
2248 |   51 |     }
2249 |   52 |     
2250 |   53 |     // 创建 WebSocket
2251 |   54 |     print("\n🔗 正在连接...")
2252 |   55 |     var request = URLRequest(url: url)
2253 |   56 |     request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
2254 |   57 |     request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
2255 |   58 |     
2256 |   59 |     let delegate = WSDelegate()
2257 |   60 |     let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
2258 |   61 |     let ws = session.webSocketTask(with: request)
2259 |   62 |     
2260 |   63 |     // 等待连接
2261 |   64 |     await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
2262 |   65 |         delegate.onOpen = { cont.resume() }
2263 |   66 |         ws.resume()
2264 |   67 |     }
2265 |   68 |     
2266 |   69 |     // 发送配置
2267 |   70 |     print("📤 发送配置...")
2268 |   71 |     let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
2269 |   72 |     do {
2270 |   73 |         try await ws.send(.string(configMessage))
2271 |   74 |         print("   ✅ 配置已发送")
2272 |   75 |     } catch {
2273 |   76 |         print("   ❌ 发送配置失败: \(error)")
2274 |   77 |         return
2275 |   78 |     }
2276 |   79 |     
2277 |   80 |     // 发送 SSML
2278 |   81 |     print("📤 发送 SSML...")
2279 |   82 |     let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
2280 |   83 |     let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
2281 |   84 |     do {
2282 |   85 |         try await ws.send(.string(ssmlMessage))
2283 |   86 |         print("   ✅ SSML 已发送")
2284 |   87 |     } catch {
2285 |   88 |         print("   ❌ 发送 SSML 失败: \(error)")
2286 |   89 |         return
2287 |   90 |     }
2288 |   91 |     
2289 |   92 |     // 接收音频
2290 |   93 |     print("\n📥 接收音频数据...")
2291 |   94 |     var audioData = Data()
2292 |   95 |     var messageCount = 0
2293 |   96 |     
2294 |   97 |     while true {
2295 |   98 |         do {
2296 |   99 |             let message = try await ws.receive()
2297 |  100 |             messageCount += 1
2298 |  101 |             
2299 |  102 |             switch message {
2300 |  103 |             case .data(let data):
2301 |  104 |                 // 尝试解析为字符串查看内容
2302 |  105 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
2303 |  106 |                     // 找到音频分隔符后的数据
2304 |  107 |                     if let range = str.range(of: "Path:audio\r\n") {
2305 |  108 |                         let offset = range.upperBound.utf16Offset(in: str)
2306 |  109 |                         let audioChunk = data.suffix(from: offset)
2307 |  110 |                         audioData.append(audioChunk)
2308 |  111 |                         print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
2309 |  112 |                     }
2310 |  113 |                 } else {
2311 |  114 |                     // 纯二进制音频
2312 |  115 |                     audioData.append(data)
2313 |  116 |                     print("   收到音频块 #\(messageCount): \(data.count) bytes")
2314 |  117 |                 }
2315 |  118 |                 
2316 |  119 |             case .string(let str):
2317 |  120 |                 if str.contains("Path:turn.end") {
2318 |  121 |                     print("   ✅ 收到结束信号")
2319 |  122 |                     break
2320 |  123 |                 } else if str.contains("Path:audio.metadata") {
2321 |  124 |                     print("   收到元数据")
2322 |  125 |                 } else {
2323 |  126 |                     print("   收到文本: \(str.prefix(50))...")
2324 |  127 |                 }
2325 |  128 |                 continue
2326 |  129 |                 
2327 |  130 |             @unknown default:
2328 |  131 |                 continue
2329 |  132 |             }
2330 |  133 |             
2331 |  134 |             if messageCount > 100 { break } // 防止死循环
2332 |  135 |             
2333 |  136 |         } catch {
2334 |  137 |             print("   ⚠️ 接收错误: \(error)")
2335 |  138 |             break
2336 |  139 |         }
2337 |  140 |     }
2338 |  141 |     
2339 |  142 |     ws.cancel(with: .goingAway, reason: nil)
2340 |  143 |     
2341 |  144 |     print("\n📊 结果:")
2342 |  145 |     print("   总消息数: \(messageCount)")
2343 |  146 |     print("   音频大小: \(audioData.count) bytes")
2344 |  147 |     
2345 |  148 |     if audioData.isEmpty {
2346 |  149 |         print("   ❌ 没有收到音频数据")
2347 |  150 |         return
2348 |  151 |     }
2349 |  152 |     
2350 |  153 |     // 检查音频头
2351 |  154 |     let header = audioData.prefix(16)
2352 |  155 |     print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
2353 |  156 |     
2354 |  157 |     // MP3 文件应该以 FF FB 或 ID3 开头
2355 |  158 |     if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
2356 |  159 |         print("   ✅ 看起来是有效的 MP3 格式")
2357 |  160 |     } else {
2358 |  161 |         print("   ⚠️ 可能不是标准 MP3 格式")
2359 |  162 |     }
2360 |  163 |     
2361 |  164 |     // 保存到文件
2362 |  165 |     let tempPath = "/tmp/edge_tts_test.mp3"
2363 |  166 |     do {
2364 |  167 |         try audioData.write(to: URL(fileURLWithPath: tempPath))
2365 |  168 |         print("\n💾 已保存到: \(tempPath)")
2366 |  169 |     } catch {
2367 |  170 |         print("   ❌ 保存失败: \(error)")
2368 |  171 |         return
2369 |  172 |     }
2370 |  173 |     
2371 |  174 |     // 播放测试
2372 |  175 |     print("\n🔊 播放测试...")
2373 |  176 |     do {
2374 |  177 |         let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
2375 |  178 |         player.prepareToPlay()
2376 |  179 |         
2377 |  180 |         if player.play() {
2378 |  181 |             print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
2379 |  182 |             
2380 |  183 |             // 等待播放完成
2381 |  184 |             while player.isPlaying {
2382 |  185 |                 try await Task.sleep(nanoseconds: 100_000_000)
2383 |  186 |             }
2384 |  187 |             print("   ✅ 播放完成!")
2385 |  188 |         } else {
2386 |  189 |             print("   ❌ 播放启动失败")
2387 |  190 |         }
2388 |  191 |     } catch {
2389 |  192 |         print("   ❌ 播放错误: \(error)")
2390 |  193 |         
2391 |  194 |         // 尝试用 afplay 播放
2392 |  195 |         print("\n🔧 尝试用 afplay 播放...")
2393 |  196 |         let process = Process()
2394 |  197 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
2395 |  198 |         process.arguments = [tempPath]
2396 |  199 |         try? process.run()
2397 |  200 |         process.waitUntilExit()
2398 |  201 |         
2399 |  202 |         if process.terminationStatus == 0 {
2400 |  203 |             print("   ✅ afplay 播放成功!")
2401 |  204 |         } else {
2402 |  205 |             print("   ❌ afplay 也失败了")
2403 |  206 |         }
2404 |  207 |     }
2405 |  208 | }
2406 |  209 | 
2407 |  210 | // 运行测试
2408 |  211 | Task {
2409 |  212 |     await runTest()
2410 |  213 |     exit(0)
2411 |  214 | }
2412 |  215 | 
2413 |  216 | // 保持运行
2414 |  217 | RunLoop.main.run()
2415 | 
2416 | ```
2417 | ```

```

`spoke/docs/code2prompt-output/lucid-full.md`:

```md
   1 | Project Path: spoke
   2 | 
   3 | Source Tree:
   4 | 
   5 | ```txt
   6 | spoke
   7 | ├── App
   8 | │   ├── AppDelegate.swift
   9 | │   └── SpokenlyApp.swift
  10 | ├── Core
  11 | │   ├── Attachment
  12 | │   │   ├── Attachment.swift
  13 | │   │   ├── AttachmentManager.swift
  14 | │   │   ├── ScreenCaptureService.swift
  15 | │   │   └── TextExtractionService.swift
  16 | │   ├── Audio
  17 | │   │   └── AudioRecorderService.swift
  18 | │   ├── DataModels.swift
  19 | │   ├── LLM
  20 | │   │   ├── KeychainService.swift
  21 | │   │   ├── LLMPipeline.swift
  22 | │   │   ├── LLMProvider.swift
  23 | │   │   ├── LLMSettings.swift
  24 | │   │   └── OpenAICompatibleProvider.swift
  25 | │   ├── MessagePanel
  26 | │   │   └── MessagePanelState.swift
  27 | │   ├── QuickAsk
  28 | │   │   └── QuickAskState.swift
  29 | │   ├── RecordingState.swift
  30 | │   └── Transcription
  31 | │       ├── Providers
  32 | │       │   ├── SFSpeechProvider.swift
  33 | │       │   └── SpeechAnalyzerProvider.swift
  34 | │       ├── TranscriptionManager.swift
  35 | │       └── TranscriptionProvider.swift
  36 | ├── Package.swift
  37 | ├── Resources
  38 | │   └── LocalModels
  39 | ├── Services
  40 | │   ├── AppSettings.swift
  41 | │   ├── AudioDeviceManager.swift
  42 | │   ├── AudioPlayerService.swift
  43 | │   ├── ClipboardHistoryService.swift
  44 | │   ├── ContextService.swift
  45 | │   ├── DoubaoTTSService.swift
  46 | │   ├── EdgeTTSService.swift
  47 | │   ├── FloatingHUDManager.swift
  48 | │   ├── HistoryManager.swift
  49 | │   ├── HotKeyService.swift
  50 | │   ├── InputService.swift
  51 | │   ├── MessagePanelManager.swift
  52 | │   ├── QuickAskService.swift
  53 | │   ├── RecordingController.swift
  54 | │   └── TTSSettings.swift
  55 | ├── Tests
  56 | │   ├── AttachmentTests.swift
  57 | │   ├── EdgeTTSTests.swift
  58 | │   ├── TextExtractionTests.swift
  59 | │   ├── run-tests.sh
  60 | │   └── test_edge_tts.swift
  61 | ├── UI
  62 | │   ├── Components
  63 | │   │   ├── AttachmentDropOverlay.swift
  64 | │   │   ├── AttachmentPickerMenu.swift
  65 | │   │   └── AttachmentThumbnailView.swift
  66 | │   ├── HUD
  67 | │   │   ├── FloatingCapsuleView.swift
  68 | │   │   ├── FloatingPanel.swift
  69 | │   │   ├── HUDTheme.swift
  70 | │   │   ├── QuickAskCapsuleView.swift
  71 | │   │   └── QuickAskInputView.swift
  72 | │   ├── MessagePanel
  73 | │   │   └── MessagePanelView.swift
  74 | │   ├── QuickAsk
  75 | │   │   ├── AnswerPanelView.swift
  76 | │   │   └── MarkdownWebView.swift
  77 | │   └── Settings
  78 | │       └── SettingsView.swift
  79 | └── docs
  80 |     └── code2prompt-output
  81 | 
  82 | ```
  83 | 
  84 | `spoke/Tests/AttachmentTests.swift`:
  85 | 
  86 | ```swift
  87 |    1 | import Foundation
  88 |    2 | import AppKit
  89 |    3 | 
  90 |    4 | // MARK: - Attachment Tests
  91 |    5 | 
  92 |    6 | /// Attachment 类型单元测试
  93 |    7 | /// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
  94 |    8 | @main
  95 |    9 | struct AttachmentTests {
  96 |   10 |     
  97 |   11 |     static var passCount = 0
  98 |   12 |     static var failCount = 0
  99 |   13 |     
 100 |   14 |     static func main() async {
 101 |   15 |         print("🧪 Attachment 类型单元测试")
 102 |   16 |         print("=" * 50)
 103 |   17 |         
 104 |   18 |         // 运行测试
 105 |   19 |         runTest("Image 类型属性") { try testImageAttachment() }
 106 |   20 |         runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
 107 |   21 |         runTest("File 类型属性") { try testFileAttachment() }
 108 |   22 |         runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
 109 |   23 |         runTest("视频文件检测") { try testVideoDetection() }
 110 |   24 |         runTest("ID 相等性判断") { try testEqualityById() }
 111 |   25 |         runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
 112 |   26 |         runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
 113 |   27 |         runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
 114 |   28 |         runTest("缩略图处理空图") { try testThumbnailZeroSize() }
 115 |   29 |         
 116 |   30 |         print("\n" + "=" * 50)
 117 |   31 |         print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
 118 |   32 |     }
 119 |   33 |     
 120 |   34 |     // MARK: - Test Runner
 121 |   35 |     
 122 |   36 |     static func runTest(_ name: String, _ test: () throws -> Void) {
 123 |   37 |         print("\n📝 测试: \(name)")
 124 |   38 |         do {
 125 |   39 |             try test()
 126 |   40 |             print("   ✅ 通过")
 127 |   41 |             passCount += 1
 128 |   42 |         } catch {
 129 |   43 |             print("   ❌ 失败: \(error)")
 130 |   44 |             failCount += 1
 131 |   45 |         }
 132 |   46 |     }
 133 |   47 |     
 134 |   48 |     // MARK: - Test Cases: Attachment Types
 135 |   49 |     
 136 |   50 |     static func testImageAttachment() throws {
 137 |   51 |         let image = NSImage(size: NSSize(width: 100, height: 100))
 138 |   52 |         let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
 139 |   53 |         let id = UUID()
 140 |   54 |         
 141 |   55 |         let attachment = Attachment.image(image, thumbnail, id)
 142 |   56 |         
 143 |   57 |         try assertEqual(attachment.id, id, "ID")
 144 |   58 |         try assertEqual(attachment.displayTitle, "图片", "displayTitle")
 145 |   59 |         try assertNotNil(attachment.thumbnail, "thumbnail")
 146 |   60 |         try assertNotNil(attachment.originalImage, "originalImage")
 147 |   61 |         try assertFalse(attachment.isVideo, "isVideo")
 148 |   62 |         try assertFalse(attachment.isTextBundle, "isTextBundle")
 149 |   63 |         try assertNil(attachment.textContent, "textContent")
 150 |   64 |     }
 151 |   65 |     
 152 |   66 |     static func testScreenshotAttachment() throws {
 153 |   67 |         let image = NSImage(size: NSSize(width: 1920, height: 1080))
 154 |   68 |         let id = UUID()
 155 |   69 |         
 156 |   70 |         let attachment = Attachment.screenshot(image, nil, id)
 157 |   71 |         
 158 |   72 |         try assertEqual(attachment.id, id, "ID")
 159 |   73 |         try assertEqual(attachment.displayTitle, "截图", "displayTitle")
 160 |   74 |         try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
 161 |   75 |         try assertNotNil(attachment.originalImage, "originalImage")
 162 |   76 |     }
 163 |   77 |     
 164 |   78 |     static func testFileAttachment() throws {
 165 |   79 |         let url = URL(fileURLWithPath: "/tmp/test.pdf")
 166 |   80 |         let id = UUID()
 167 |   81 |         
 168 |   82 |         let attachment = Attachment.file(url, id)
 169 |   83 |         
 170 |   84 |         try assertEqual(attachment.id, id, "ID")
 171 |   85 |         try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
 172 |   86 |         try assertEqual(attachment.fileName, "test.pdf", "fileName")
 173 |   87 |         try assertNil(attachment.thumbnail, "thumbnail")
 174 |   88 |         try assertNil(attachment.originalImage, "originalImage")
 175 |   89 |     }
 176 |   90 |     
 177 |   91 |     static func testTextBundleAttachment() throws {
 178 |   92 |         let content = "# Code content\nlet x = 1"
 179 |   93 |         let source = "my-project"
 180 |   94 |         let count = 42
 181 |   95 |         let id = UUID()
 182 |   96 |         
 183 |   97 |         let attachment = Attachment.textBundle(content, source, count, id)
 184 |   98 |         
 185 |   99 |         try assertEqual(attachment.id, id, "ID")
 186 |  100 |         try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
 187 |  101 |         try assertEqual(attachment.fileName, source, "fileName")
 188 |  102 |         try assertTrue(attachment.isTextBundle, "isTextBundle")
 189 |  103 |         try assertEqual(attachment.textContent, content, "textContent")
 190 |  104 |     }
 191 |  105 |     
 192 |  106 |     static func testVideoDetection() throws {
 193 |  107 |         let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
 194 |  108 |         let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
 195 |  109 |         let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
 196 |  110 |         
 197 |  111 |         try assertTrue(mp4.isVideo, "mp4 should be video")
 198 |  112 |         try assertTrue(mov.isVideo, "mov should be video")
 199 |  113 |         try assertFalse(txt.isVideo, "txt should not be video")
 200 |  114 |     }
 201 |  115 |     
 202 |  116 |     static func testEqualityById() throws {
 203 |  117 |         let id = UUID()
 204 |  118 |         let image1 = NSImage(size: NSSize(width: 100, height: 100))
 205 |  119 |         let image2 = NSImage(size: NSSize(width: 200, height: 200))
 206 |  120 |         
 207 |  121 |         let att1 = Attachment.image(image1, nil, id)
 208 |  122 |         let att2 = Attachment.image(image2, nil, id)
 209 |  123 |         let att3 = Attachment.image(image1, nil, UUID())
 210 |  124 |         
 211 |  125 |         try assertTrue(att1 == att2, "Same ID should be equal")
 212 |  126 |         try assertFalse(att1 == att3, "Different ID should not be equal")
 213 |  127 |     }
 214 |  128 |     
 215 |  129 |     // MARK: - Test Cases: Thumbnail Generation
 216 |  130 |     
 217 |  131 |     static func testThumbnailResizesLarge() throws {
 218 |  132 |         let large = createTestImage(width: 2000, height: 1000)
 219 |  133 |         let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
 220 |  134 |         
 221 |  135 |         try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
 222 |  136 |         try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
 223 |  137 |     }
 224 |  138 |     
 225 |  139 |     static func testThumbnailPreservesRatio() throws {
 226 |  140 |         let image = createTestImage(width: 2000, height: 1000)
 227 |  141 |         let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
 228 |  142 |         
 229 |  143 |         let ratio = thumb.size.width / thumb.size.height
 230 |  144 |         try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
 231 |  145 |     }
 232 |  146 |     
 233 |  147 |     static func testThumbnailNoUpscale() throws {
 234 |  148 |         let small = createTestImage(width: 50, height: 50)
 235 |  149 |         let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
 236 |  150 |         
 237 |  151 |         try assertEqual(thumb.size.width, 50, "Width")
 238 |  152 |         try assertEqual(thumb.size.height, 50, "Height")
 239 |  153 |     }
 240 |  154 |     
 241 |  155 |     static func testThumbnailZeroSize() throws {
 242 |  156 |         let zero = NSImage(size: NSSize(width: 0, height: 0))
 243 |  157 |         let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
 244 |  158 |         
 245 |  159 |         try assertEqual(thumb.size.width, 0, "Width")
 246 |  160 |     }
 247 |  161 |     
 248 |  162 |     // MARK: - Helpers
 249 |  163 |     
 250 |  164 |     static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
 251 |  165 |         let image = NSImage(size: NSSize(width: width, height: height))
 252 |  166 |         image.lockFocus()
 253 |  167 |         NSColor.red.setFill()
 254 |  168 |         NSRect(x: 0, y: 0, width: width, height: height).fill()
 255 |  169 |         image.unlockFocus()
 256 |  170 |         return image
 257 |  171 |     }
 258 |  172 | }
 259 |  173 | 
 260 |  174 | // MARK: - Attachment Type (简化版，用于测试)
 261 |  175 | 
 262 |  176 | import UniformTypeIdentifiers
 263 |  177 | 
 264 |  178 | enum Attachment: Identifiable, Equatable {
 265 |  179 |     case image(NSImage, NSImage?, UUID)
 266 |  180 |     case screenshot(NSImage, NSImage?, UUID)
 267 |  181 |     case file(URL, UUID)
 268 |  182 |     case textBundle(String, String, Int, UUID)
 269 |  183 |     
 270 |  184 |     var id: UUID {
 271 |  185 |         switch self {
 272 |  186 |         case .image(_, _, let id), .screenshot(_, _, let id),
 273 |  187 |              .file(_, let id), .textBundle(_, _, _, let id):
 274 |  188 |             return id
 275 |  189 |         }
 276 |  190 |     }
 277 |  191 |     
 278 |  192 |     var thumbnail: NSImage? {
 279 |  193 |         switch self {
 280 |  194 |         case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
 281 |  195 |         default: return nil
 282 |  196 |         }
 283 |  197 |     }
 284 |  198 |     
 285 |  199 |     var originalImage: NSImage? {
 286 |  200 |         switch self {
 287 |  201 |         case .image(let img, _, _), .screenshot(let img, _, _): return img
 288 |  202 |         default: return nil
 289 |  203 |         }
 290 |  204 |     }
 291 |  205 |     
 292 |  206 |     var fileName: String? {
 293 |  207 |         switch self {
 294 |  208 |         case .file(let url, _): return url.lastPathComponent
 295 |  209 |         case .textBundle(_, let source, _, _): return source
 296 |  210 |         default: return nil
 297 |  211 |         }
 298 |  212 |     }
 299 |  213 |     
 300 |  214 |     var displayTitle: String {
 301 |  215 |         switch self {
 302 |  216 |         case .image: return "图片"
 303 |  217 |         case .screenshot: return "截图"
 304 |  218 |         case .file(let url, _): return url.lastPathComponent
 305 |  219 |         case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
 306 |  220 |         }
 307 |  221 |     }
 308 |  222 |     
 309 |  223 |     var isVideo: Bool {
 310 |  224 |         if case .file(let url, _) = self,
 311 |  225 |            let uti = UTType(filenameExtension: url.pathExtension) {
 312 |  226 |             return uti.conforms(to: .movie) || uti.conforms(to: .video)
 313 |  227 |         }
 314 |  228 |         return false
 315 |  229 |     }
 316 |  230 |     
 317 |  231 |     var isTextBundle: Bool {
 318 |  232 |         if case .textBundle = self { return true }
 319 |  233 |         return false
 320 |  234 |     }
 321 |  235 |     
 322 |  236 |     var textContent: String? {
 323 |  237 |         if case .textBundle(let content, _, _, _) = self { return content }
 324 |  238 |         return nil
 325 |  239 |     }
 326 |  240 |     
 327 |  241 |     static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
 328 |  242 |     
 329 |  243 |     static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
 330 |  244 |         let size = image.size
 331 |  245 |         guard size.width > 0 && size.height > 0 else { return image }
 332 |  246 |         
 333 |  247 |         let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
 334 |  248 |         let newSize = NSSize(width: size.width * scale, height: size.height * scale)
 335 |  249 |         
 336 |  250 |         let thumbnail = NSImage(size: newSize)
 337 |  251 |         thumbnail.lockFocus()
 338 |  252 |         image.draw(in: NSRect(origin: .zero, size: newSize),
 339 |  253 |                    from: NSRect(origin: .zero, size: size),
 340 |  254 |                    operation: .copy, fraction: 1.0)
 341 |  255 |         thumbnail.unlockFocus()
 342 |  256 |         return thumbnail
 343 |  257 |     }
 344 |  258 | }
 345 |  259 | 
 346 |  260 | // MARK: - Assertion Helpers
 347 |  261 | 
 348 |  262 | struct TestError: Error, CustomStringConvertible {
 349 |  263 |     let message: String
 350 |  264 |     init(_ message: String) { self.message = message }
 351 |  265 |     var description: String { message }
 352 |  266 | }
 353 |  267 | 
 354 |  268 | func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
 355 |  269 |     if actual != expected {
 356 |  270 |         throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
 357 |  271 |     }
 358 |  272 | }
 359 |  273 | 
 360 |  274 | func assertTrue(_ condition: Bool, _ message: String) throws {
 361 |  275 |     if !condition { throw TestError(message) }
 362 |  276 | }
 363 |  277 | 
 364 |  278 | func assertFalse(_ condition: Bool, _ message: String) throws {
 365 |  279 |     if condition { throw TestError(message) }
 366 |  280 | }
 367 |  281 | 
 368 |  282 | func assertNil<T>(_ value: T?, _ message: String) throws {
 369 |  283 |     if value != nil { throw TestError("\(message) 应该是 nil") }
 370 |  284 | }
 371 |  285 | 
 372 |  286 | func assertNotNil<T>(_ value: T?, _ message: String) throws {
 373 |  287 |     if value == nil { throw TestError("\(message) 不应该是 nil") }
 374 |  288 | }
 375 |  289 | 
 376 |  290 | extension String {
 377 |  291 |     static func * (string: String, count: Int) -> String {
 378 |  292 |         String(repeating: string, count: count)
 379 |  293 |     }
 380 |  294 | }
 381 | 
 382 | ```
 383 | 
 384 | `spoke/Tests/EdgeTTSTests.swift`:
 385 | 
 386 | ```swift
 387 |    1 | import Foundation
 388 |    2 | import AVFoundation
 389 |    3 | 
 390 |    4 | // MARK: - Edge TTS 单元测试
 391 |    5 | 
 392 |    6 | @main
 393 |    7 | struct EdgeTTSTests {
 394 |    8 |     static func main() async {
 395 |    9 |         print("🧪 Edge TTS 单元测试")
 396 |   10 |         print("=" * 50)
 397 |   11 |         
 398 |   12 |         await testSynthesizeAndPlay()
 399 |   13 |     }
 400 |   14 |     
 401 |   15 |     /// 测试合成并播放
 402 |   16 |     static func testSynthesizeAndPlay() async {
 403 |   17 |         print("\n📝 测试: 合成并播放")
 404 |   18 |         
 405 |   19 |         let text = "你好，这是语音合成测试。"
 406 |   20 |         let voice = "zh-CN-XiaoxiaoNeural"
 407 |   21 |         
 408 |   22 |         do {
 409 |   23 |             // 1. 合成音频
 410 |   24 |             print("   正在合成...")
 411 |   25 |             let audioData = try await synthesize(text: text, voice: voice)
 412 |   26 |             print("   ✅ 合成完成: \(audioData.count) bytes")
 413 |   27 |             
 414 |   28 |             // 2. 检查音频头
 415 |   29 |             print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
 416 |   30 |             
 417 |   31 |             // 3. 保存到文件测试
 418 |   32 |             let tempPath = "/tmp/edge_tts_test.mp3"
 419 |   33 |             try audioData.write(to: URL(fileURLWithPath: tempPath))
 420 |   34 |             print("   ✅ 已保存到: \(tempPath)")
 421 |   35 |             
 422 |   36 |             // 4. 用 AVAudioPlayer 播放
 423 |   37 |             print("   正在播放...")
 424 |   38 |             let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
 425 |   39 |             player.prepareToPlay()
 426 |   40 |             player.play()
 427 |   41 |             
 428 |   42 |             // 等待播放完成
 429 |   43 |             while player.isPlaying {
 430 |   44 |                 try await Task.sleep(nanoseconds: 100_000_000)
 431 |   45 |             }
 432 |   46 |             print("   ✅ 播放完成!")
 433 |   47 |             
 434 |   48 |         } catch {
 435 |   49 |             print("   ❌ 错误: \(error)")
 436 |   50 |         }
 437 |   51 |     }
 438 |   52 |     
 439 |   53 |     /// 合成音频
 440 |   54 |     static func synthesize(text: String, voice: String) async throws -> Data {
 441 |   55 |         // DRM Token
 442 |   56 |         let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
 443 |   57 |         let chromiumVersion = "130.0.2849.68"
 444 |   58 |         let windowsFileTimeEpoch: Int64 = 11_644_473_600
 445 |   59 |         
 446 |   60 |         let currentTime = Int64(Date().timeIntervalSince1970)
 447 |   61 |         let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
 448 |   62 |         let roundedTicks = ticks - (ticks % 3_000_000_000)
 449 |   63 |         let strToHash = "\(roundedTicks)\(trustedClientToken)"
 450 |   64 |         
 451 |   65 |         // SHA256
 452 |   66 |         import CryptoKit
 453 |   67 |         let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
 454 |   68 |         let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
 455 |   69 |         
 456 |   70 |         // URL
 457 |   71 |         let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
 458 |   72 |         let url = URL(string: urlString)!
 459 |   73 |         
 460 |   74 |         // WebSocket
 461 |   75 |         var request = URLRequest(url: url)
 462 |   76 |         request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
 463 |   77 |         request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
 464 |   78 |         
 465 |   79 |         let session = URLSession.shared
 466 |   80 |         let ws = session.webSocketTask(with: request)
 467 |   81 |         ws.resume()
 468 |   82 |         
 469 |   83 |         // 等待连接
 470 |   84 |         try await Task.sleep(nanoseconds: 500_000_000)
 471 |   85 |         
 472 |   86 |         // 发送配置
 473 |   87 |         let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
 474 |   88 |         try await ws.send(.string(configMessage))
 475 |   89 |         
 476 |   90 |         // 发送 SSML
 477 |   91 |         let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
 478 |   92 |         let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
 479 |   93 |         try await ws.send(.string(ssmlMessage))
 480 |   94 |         
 481 |   95 |         // 接收音频
 482 |   96 |         var audioData = Data()
 483 |   97 |         
 484 |   98 |         while true {
 485 |   99 |             let message = try await ws.receive()
 486 |  100 |             
 487 |  101 |             switch message {
 488 |  102 |             case .data(let data):
 489 |  103 |                 // 检查是否包含 Path:audio
 490 |  104 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 491 |  105 |                     if let range = str.range(of: "Path:audio\r\n") {
 492 |  106 |                         let offset = range.upperBound.utf16Offset(in: str)
 493 |  107 |                         audioData.append(data[offset...])
 494 |  108 |                     }
 495 |  109 |                 } else {
 496 |  110 |                     audioData.append(data)
 497 |  111 |                 }
 498 |  112 |                 
 499 |  113 |             case .string(let str):
 500 |  114 |                 if str.contains("Path:turn.end") {
 501 |  115 |                     ws.cancel(with: .goingAway, reason: nil)
 502 |  116 |                     return audioData
 503 |  117 |                 }
 504 |  118 |                 
 505 |  119 |             @unknown default:
 506 |  120 |                 break
 507 |  121 |             }
 508 |  122 |         }
 509 |  123 |     }
 510 |  124 | }
 511 |  125 | 
 512 |  126 | extension String {
 513 |  127 |     static func * (string: String, count: Int) -> String {
 514 |  128 |         String(repeating: string, count: count)
 515 |  129 |     }
 516 |  130 | }
 517 | 
 518 | ```
 519 | 
 520 | `spoke/Tests/TextExtractionTests.swift`:
 521 | 
 522 | ```swift
 523 |    1 | import Foundation
 524 |    2 | 
 525 |    3 | // MARK: - Text Extraction Service Tests
 526 |    4 | 
 527 |    5 | /// 独立运行的测试脚本
 528 |    6 | /// 用法: swift Tests/TextExtractionTests.swift
 529 |    7 | @main
 530 |    8 | struct TextExtractionTests {
 531 |    9 |     
 532 |   10 |     static var tempDirectory: URL!
 533 |   11 |     static var passCount = 0
 534 |   12 |     static var failCount = 0
 535 |   13 |     
 536 |   14 |     static func main() async {
 537 |   15 |         print("🧪 TextExtractionService 单元测试")
 538 |   16 |         print("=" * 50)
 539 |   17 |         
 540 |   18 |         // 创建临时目录
 541 |   19 |         tempDirectory = FileManager.default.temporaryDirectory
 542 |   20 |             .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
 543 |   21 |         try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 544 |   22 |         
 545 |   23 |         defer {
 546 |   24 |             // 清理
 547 |   25 |             try? FileManager.default.removeItem(at: tempDirectory)
 548 |   26 |             print("\n" + "=" * 50)
 549 |   27 |             print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
 550 |   28 |         }
 551 |   29 |         
 552 |   30 |         // 运行测试
 553 |   31 |         await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
 554 |   32 |         await runTest("单文件提取") { try await testSingleFileExtraction() }
 555 |   33 |         await runTest("多文件合并") { try await testMultipleFilesExtraction() }
 556 |   34 |         await runTest("排除 node_modules") { try await testExcludesNodeModules() }
 557 |   35 |         await runTest("排除锁文件") { try await testExcludesLockFiles() }
 558 |   36 |         await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
 559 |   37 |         await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
 560 |   38 |         await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
 561 |   39 |         await runTest("添加行号") { try await testAddsLineNumbers() }
 562 |   40 |         await runTest("目录结构输出") { try await testDirectoryStructure() }
 563 |   41 |         await runTest("ZIP 提取") { try await testZIPExtraction() }
 564 |   42 |     }
 565 |   43 |     
 566 |   44 |     // MARK: - Test Runner
 567 |   45 |     
 568 |   46 |     static func runTest(_ name: String, _ test: () async throws -> Void) async {
 569 |   47 |         print("\n📝 测试: \(name)")
 570 |   48 |         do {
 571 |   49 |             try await test()
 572 |   50 |             print("   ✅ 通过")
 573 |   51 |             passCount += 1
 574 |   52 |         } catch {
 575 |   53 |             print("   ❌ 失败: \(error)")
 576 |   54 |             failCount += 1
 577 |   55 |         }
 578 |   56 |     }
 579 |   57 |     
 580 |   58 |     // MARK: - Helpers
 581 |   59 |     
 582 |   60 |     static func createFile(name: String, content: String) throws -> URL {
 583 |   61 |         let fileURL = tempDirectory.appendingPathComponent(name)
 584 |   62 |         let dir = fileURL.deletingLastPathComponent()
 585 |   63 |         try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
 586 |   64 |         try content.write(to: fileURL, atomically: true, encoding: .utf8)
 587 |   65 |         return fileURL
 588 |   66 |     }
 589 |   67 |     
 590 |   68 |     static func createDirectory(name: String) throws -> URL {
 591 |   69 |         let dirURL = tempDirectory.appendingPathComponent(name)
 592 |   70 |         try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
 593 |   71 |         return dirURL
 594 |   72 |     }
 595 |   73 |     
 596 |   74 |     // MARK: - Test Cases
 597 |   75 |     
 598 |   76 |     static func testCodeExtensions() async throws {
 599 |   77 |         // 创建各种代码文件
 600 |   78 |         _ = try createFile(name: "test.swift", content: "let x = 1")
 601 |   79 |         _ = try createFile(name: "app.js", content: "const x = 1")
 602 |   80 |         _ = try createFile(name: "main.py", content: "x = 1")
 603 |   81 |         _ = try createFile(name: "README.md", content: "# Title")
 604 |   82 |         
 605 |   83 |         let result = await extractFromFolder(tempDirectory)
 606 |   84 |         guard case .success(let bundle) = result else {
 607 |   85 |             throw TestError("提取失败")
 608 |   86 |         }
 609 |   87 |         
 610 |   88 |         guard bundle.fileCount == 4 else {
 611 |   89 |             throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
 612 |   90 |         }
 613 |   91 |     }
 614 |   92 |     
 615 |   93 |     static func testSingleFileExtraction() async throws {
 616 |   94 |         // 清理并创建新目录
 617 |   95 |         try FileManager.default.removeItem(at: tempDirectory)
 618 |   96 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 619 |   97 |         
 620 |   98 |         _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
 621 |   99 |         
 622 |  100 |         let result = await extractFromFolder(tempDirectory)
 623 |  101 |         guard case .success(let bundle) = result else {
 624 |  102 |             throw TestError("提取失败")
 625 |  103 |         }
 626 |  104 |         
 627 |  105 |         guard bundle.fileCount == 1 else {
 628 |  106 |             throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
 629 |  107 |         }
 630 |  108 |         guard bundle.content.contains("print(\"Hello\")") else {
 631 |  109 |             throw TestError("内容不包含预期文本")
 632 |  110 |         }
 633 |  111 |     }
 634 |  112 |     
 635 |  113 |     static func testMultipleFilesExtraction() async throws {
 636 |  114 |         try FileManager.default.removeItem(at: tempDirectory)
 637 |  115 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 638 |  116 |         
 639 |  117 |         _ = try createFile(name: "a.swift", content: "let a = 1")
 640 |  118 |         _ = try createFile(name: "b.swift", content: "let b = 2")
 641 |  119 |         _ = try createFile(name: "c.js", content: "const c = 3")
 642 |  120 |         
 643 |  121 |         let result = await extractFromFolder(tempDirectory)
 644 |  122 |         guard case .success(let bundle) = result else {
 645 |  123 |             throw TestError("提取失败")
 646 |  124 |         }
 647 |  125 |         
 648 |  126 |         guard bundle.fileCount == 3 else {
 649 |  127 |             throw TestError("文件数量错误")
 650 |  128 |         }
 651 |  129 |         guard bundle.content.contains("let a = 1") &&
 652 |  130 |               bundle.content.contains("let b = 2") &&
 653 |  131 |               bundle.content.contains("const c = 3") else {
 654 |  132 |             throw TestError("内容缺失")
 655 |  133 |         }
 656 |  134 |     }
 657 |  135 |     
 658 |  136 |     static func testExcludesNodeModules() async throws {
 659 |  137 |         try FileManager.default.removeItem(at: tempDirectory)
 660 |  138 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 661 |  139 |         
 662 |  140 |         let nodeModules = try createDirectory(name: "node_modules")
 663 |  141 |         try "const secret = 'password'".write(
 664 |  142 |             to: nodeModules.appendingPathComponent("secret.js"),
 665 |  143 |             atomically: true, encoding: .utf8
 666 |  144 |         )
 667 |  145 |         _ = try createFile(name: "app.js", content: "const app = 1")
 668 |  146 |         
 669 |  147 |         let result = await extractFromFolder(tempDirectory)
 670 |  148 |         guard case .success(let bundle) = result else {
 671 |  149 |             throw TestError("提取失败")
 672 |  150 |         }
 673 |  151 |         
 674 |  152 |         guard bundle.fileCount == 1 else {
 675 |  153 |             throw TestError("应该只包含 app.js")
 676 |  154 |         }
 677 |  155 |         guard !bundle.content.contains("secret") else {
 678 |  156 |             throw TestError("不应包含 node_modules 内容")
 679 |  157 |         }
 680 |  158 |     }
 681 |  159 |     
 682 |  160 |     static func testExcludesLockFiles() async throws {
 683 |  161 |         try FileManager.default.removeItem(at: tempDirectory)
 684 |  162 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 685 |  163 |         
 686 |  164 |         _ = try createFile(name: "package-lock.json", content: "{}")
 687 |  165 |         _ = try createFile(name: "yarn.lock", content: "")
 688 |  166 |         _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
 689 |  167 |         
 690 |  168 |         let result = await extractFromFolder(tempDirectory)
 691 |  169 |         guard case .success(let bundle) = result else {
 692 |  170 |             throw TestError("提取失败")
 693 |  171 |         }
 694 |  172 |         
 695 |  173 |         guard bundle.fileCount == 1 else {
 696 |  174 |             throw TestError("应该只包含 package.json")
 697 |  175 |         }
 698 |  176 |     }
 699 |  177 |     
 700 |  178 |     static func testNestedDirectories() async throws {
 701 |  179 |         try FileManager.default.removeItem(at: tempDirectory)
 702 |  180 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 703 |  181 |         
 704 |  182 |         _ = try createFile(name: "root.swift", content: "let root = 1")
 705 |  183 |         _ = try createFile(name: "src/app.swift", content: "let src = 2")
 706 |  184 |         _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
 707 |  185 |         
 708 |  186 |         let result = await extractFromFolder(tempDirectory)
 709 |  187 |         guard case .success(let bundle) = result else {
 710 |  188 |             throw TestError("提取失败")
 711 |  189 |         }
 712 |  190 |         
 713 |  191 |         guard bundle.fileCount == 3 else {
 714 |  192 |             throw TestError("应该包含 3 个文件")
 715 |  193 |         }
 716 |  194 |         guard bundle.content.contains("let root = 1") &&
 717 |  195 |               bundle.content.contains("let src = 2") &&
 718 |  196 |               bundle.content.contains("let lib = 3") else {
 719 |  197 |             throw TestError("缺少嵌套目录内容")
 720 |  198 |         }
 721 |  199 |     }
 722 |  200 |     
 723 |  201 |     static func testEmptyFolderError() async throws {
 724 |  202 |         try FileManager.default.removeItem(at: tempDirectory)
 725 |  203 |         let emptyDir = try createDirectory(name: "empty")
 726 |  204 |         
 727 |  205 |         let result = await extractFromFolder(emptyDir)
 728 |  206 |         guard case .failure = result else {
 729 |  207 |             throw TestError("空文件夹应该返回错误")
 730 |  208 |         }
 731 |  209 |     }
 732 |  210 |     
 733 |  211 |     static func testIgnoresNonCodeFiles() async throws {
 734 |  212 |         try FileManager.default.removeItem(at: tempDirectory)
 735 |  213 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 736 |  214 |         
 737 |  215 |         _ = try createFile(name: "image.png", content: "fake")
 738 |  216 |         _ = try createFile(name: "video.mp4", content: "fake")
 739 |  217 |         _ = try createFile(name: "main.swift", content: "let x = 1")
 740 |  218 |         
 741 |  219 |         let result = await extractFromFolder(tempDirectory)
 742 |  220 |         guard case .success(let bundle) = result else {
 743 |  221 |             throw TestError("提取失败")
 744 |  222 |         }
 745 |  223 |         
 746 |  224 |         guard bundle.fileCount == 1 else {
 747 |  225 |             throw TestError("应该只包含 .swift 文件")
 748 |  226 |         }
 749 |  227 |     }
 750 |  228 |     
 751 |  229 |     static func testAddsLineNumbers() async throws {
 752 |  230 |         try FileManager.default.removeItem(at: tempDirectory)
 753 |  231 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 754 |  232 |         
 755 |  233 |         _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
 756 |  234 |         
 757 |  235 |         let result = await extractFromFolder(tempDirectory)
 758 |  236 |         guard case .success(let bundle) = result else {
 759 |  237 |             throw TestError("提取失败")
 760 |  238 |         }
 761 |  239 |         
 762 |  240 |         guard bundle.content.contains("1│") &&
 763 |  241 |               bundle.content.contains("2│") &&
 764 |  242 |               bundle.content.contains("3│") else {
 765 |  243 |             throw TestError("缺少行号")
 766 |  244 |         }
 767 |  245 |     }
 768 |  246 |     
 769 |  247 |     static func testDirectoryStructure() async throws {
 770 |  248 |         try FileManager.default.removeItem(at: tempDirectory)
 771 |  249 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 772 |  250 |         
 773 |  251 |         _ = try createFile(name: "main.swift", content: "entry")
 774 |  252 |         _ = try createFile(name: "src/app.swift", content: "code")
 775 |  253 |         
 776 |  254 |         let result = await extractFromFolder(tempDirectory)
 777 |  255 |         guard case .success(let bundle) = result else {
 778 |  256 |             throw TestError("提取失败")
 779 |  257 |         }
 780 |  258 |         
 781 |  259 |         guard bundle.content.contains("# 目录结构") else {
 782 |  260 |             throw TestError("缺少目录结构标题")
 783 |  261 |         }
 784 |  262 |     }
 785 |  263 |     
 786 |  264 |     static func testZIPExtraction() async throws {
 787 |  265 |         try FileManager.default.removeItem(at: tempDirectory)
 788 |  266 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 789 |  267 |         
 790 |  268 |         // 创建源文件
 791 |  269 |         let sourceDir = try createDirectory(name: "source")
 792 |  270 |         try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
 793 |  271 |         
 794 |  272 |         // 创建 ZIP
 795 |  273 |         let zipPath = tempDirectory.appendingPathComponent("test.zip")
 796 |  274 |         let process = Process()
 797 |  275 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
 798 |  276 |         process.currentDirectoryURL = tempDirectory
 799 |  277 |         process.arguments = ["-r", zipPath.path, "source"]
 800 |  278 |         process.standardOutput = FileHandle.nullDevice
 801 |  279 |         process.standardError = FileHandle.nullDevice
 802 |  280 |         try process.run()
 803 |  281 |         process.waitUntilExit()
 804 |  282 |         
 805 |  283 |         guard process.terminationStatus == 0 else {
 806 |  284 |             throw TestError("创建 ZIP 失败")
 807 |  285 |         }
 808 |  286 |         
 809 |  287 |         let result = await extractFromZIP(zipPath)
 810 |  288 |         guard case .success(let bundle) = result else {
 811 |  289 |             throw TestError("ZIP 提取失败")
 812 |  290 |         }
 813 |  291 |         
 814 |  292 |         guard bundle.fileCount == 1 else {
 815 |  293 |             throw TestError("ZIP 文件数量错误")
 816 |  294 |         }
 817 |  295 |         guard bundle.content.contains("let x = 1") else {
 818 |  296 |             throw TestError("ZIP 内容缺失")
 819 |  297 |         }
 820 |  298 |     }
 821 |  299 | }
 822 |  300 | 
 823 |  301 | // MARK: - TextExtractionService (简化版，用于测试)
 824 |  302 | 
 825 |  303 | struct TextBundle {
 826 |  304 |     let content: String
 827 |  305 |     let fileCount: Int
 828 |  306 |     let sourcePath: String
 829 |  307 |     let files: [String]
 830 |  308 | }
 831 |  309 | 
 832 |  310 | enum TextExtractionError: Error, Equatable {
 833 |  311 |     case folderNotFound
 834 |  312 |     case zipExtractionFailed(String)
 835 |  313 |     case noTextFilesFound
 836 |  314 |     case accessDenied
 837 |  315 | }
 838 |  316 | 
 839 |  317 | func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
 840 |  318 |     let codeExtensions: Set<String> = [
 841 |  319 |         "js", "jsx", "ts", "tsx", "mjs", "cjs",
 842 |  320 |         "html", "htm", "css", "scss", "less", "vue", "svelte",
 843 |  321 |         "py", "pyw", "pyi",
 844 |  322 |         "java", "kt", "kts", "scala",
 845 |  323 |         "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
 846 |  324 |         "rs", "go", "rb", "erb", "php", "swift",
 847 |  325 |         "sh", "bash", "zsh", "fish",
 848 |  326 |         "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
 849 |  327 |         "md", "mdx", "txt", "rst", "asciidoc",
 850 |  328 |         "sql", "graphql", "proto", "dockerfile"
 851 |  329 |     ]
 852 |  330 |     
 853 |  331 |     let excludedDirs: Set<String> = [
 854 |  332 |         "node_modules", ".git", ".svn", ".hg",
 855 |  333 |         "dist", "build", "target", ".next", ".nuxt",
 856 |  334 |         "__pycache__", ".pytest_cache", ".tox",
 857 |  335 |         "venv", "env", ".env", ".venv",
 858 |  336 |         "vendor", "Pods", "Carthage",
 859 |  337 |         ".idea", ".vscode", ".vs"
 860 |  338 |     ]
 861 |  339 |     
 862 |  340 |     let excludedFiles: Set<String> = [
 863 |  341 |         ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
 864 |  342 |         "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
 865 |  343 |         "Podfile.lock", "Gemfile.lock", "Cargo.lock"
 866 |  344 |     ]
 867 |  345 |     
 868 |  346 |     // 递归收集文件
 869 |  347 |     func collectFiles(in directory: URL) -> [URL] {
 870 |  348 |         var result: [URL] = []
 871 |  349 |         let fm = FileManager.default
 872 |  350 |         
 873 |  351 |         guard let contents = try? fm.contentsOfDirectory(
 874 |  352 |             at: directory,
 875 |  353 |             includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
 876 |  354 |             options: [.skipsHiddenFiles]
 877 |  355 |         ) else { return [] }
 878 |  356 |         
 879 |  357 |         for url in contents {
 880 |  358 |             let fileName = url.lastPathComponent
 881 |  359 |             if excludedFiles.contains(fileName) { continue }
 882 |  360 |             
 883 |  361 |             let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
 884 |  362 |             
 885 |  363 |             if values?.isDirectory == true {
 886 |  364 |                 if !excludedDirs.contains(fileName) {
 887 |  365 |                     result.append(contentsOf: collectFiles(in: url))
 888 |  366 |                 }
 889 |  367 |             } else if values?.isRegularFile == true {
 890 |  368 |                 let ext = url.pathExtension.lowercased()
 891 |  369 |                 if codeExtensions.contains(ext) {
 892 |  370 |                     result.append(url)
 893 |  371 |                 }
 894 |  372 |             }
 895 |  373 |         }
 896 |  374 |         return result.sorted { $0.path < $1.path }
 897 |  375 |     }
 898 |  376 |     
 899 |  377 |     let files = collectFiles(in: folderURL)
 900 |  378 |     guard !files.isEmpty else {
 901 |  379 |         return .failure(.noTextFilesFound)
 902 |  380 |     }
 903 |  381 |     
 904 |  382 |     // 合并内容
 905 |  383 |     var parts: [String] = ["# 目录结构\n```"]
 906 |  384 |     for file in files {
 907 |  385 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 908 |  386 |         parts.append(rel)
 909 |  387 |     }
 910 |  388 |     parts.append("```\n\n# 文件内容\n")
 911 |  389 |     
 912 |  390 |     for file in files {
 913 |  391 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 914 |  392 |         let ext = file.pathExtension
 915 |  393 |         if let content = try? String(contentsOf: file, encoding: .utf8) {
 916 |  394 |             let numbered = content.components(separatedBy: .newlines).enumerated()
 917 |  395 |                 .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
 918 |  396 |             parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
 919 |  397 |         }
 920 |  398 |     }
 921 |  399 |     
 922 |  400 |     return .success(TextBundle(
 923 |  401 |         content: parts.joined(separator: "\n"),
 924 |  402 |         fileCount: files.count,
 925 |  403 |         sourcePath: folderURL.path,
 926 |  404 |         files: files.map { $0.path }
 927 |  405 |     ))
 928 |  406 | }
 929 |  407 | 
 930 |  408 | func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
 931 |  409 |     let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
 932 |  410 |     try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
 933 |  411 |     defer { try? FileManager.default.removeItem(at: tempDir) }
 934 |  412 |     
 935 |  413 |     let process = Process()
 936 |  414 |     process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
 937 |  415 |     process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
 938 |  416 |     process.standardOutput = FileHandle.nullDevice
 939 |  417 |     process.standardError = FileHandle.nullDevice
 940 |  418 |     
 941 |  419 |     do {
 942 |  420 |         try process.run()
 943 |  421 |         process.waitUntilExit()
 944 |  422 |         
 945 |  423 |         guard process.terminationStatus == 0 else {
 946 |  424 |             return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
 947 |  425 |         }
 948 |  426 |         
 949 |  427 |         return await extractFromFolder(tempDir)
 950 |  428 |     } catch {
 951 |  429 |         return .failure(.zipExtractionFailed(error.localizedDescription))
 952 |  430 |     }
 953 |  431 | }
 954 |  432 | 
 955 |  433 | // MARK: - Helpers
 956 |  434 | 
 957 |  435 | struct TestError: Error, CustomStringConvertible {
 958 |  436 |     let message: String
 959 |  437 |     init(_ message: String) { self.message = message }
 960 |  438 |     var description: String { message }
 961 |  439 | }
 962 |  440 | 
 963 |  441 | extension String {
 964 |  442 |     static func * (string: String, count: Int) -> String {
 965 |  443 |         String(repeating: string, count: count)
 966 |  444 |     }
 967 |  445 | }
 968 | 
 969 | ```
 970 | 
 971 | `spoke/Tests/run-tests.sh`:
 972 | 
 973 | ```sh
 974 |    1 | #!/bin/bash
 975 |    2 | # 运行所有单元测试
 976 |    3 | # 用法: ./Tests/run-tests.sh
 977 |    4 | 
 978 |    5 | set -e
 979 |    6 | 
 980 |    7 | cd "$(dirname "$0")/.."
 981 |    8 | 
 982 |    9 | echo "🧪 运行所有单元测试"
 983 |   10 | echo "=================================="
 984 |   11 | 
 985 |   12 | # 编译并运行 TextExtractionTests
 986 |   13 | echo ""
 987 |   14 | echo "📦 编译 TextExtractionTests..."
 988 |   15 | swiftc -parse-as-library -o /tmp/text_extraction_tests Tests/TextExtractionTests.swift
 989 |   16 | echo "🚀 运行测试..."
 990 |   17 | /tmp/text_extraction_tests
 991 |   18 | 
 992 |   19 | echo ""
 993 |   20 | echo "=================================="
 994 |   21 | 
 995 |   22 | # 编译并运行 AttachmentTests
 996 |   23 | echo ""
 997 |   24 | echo "📦 编译 AttachmentTests..."
 998 |   25 | swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift
 999 |   26 | echo "🚀 运行测试..."
1000 |   27 | /tmp/attachment_tests
1001 |   28 | 
1002 |   29 | echo ""
1003 |   30 | echo "=================================="
1004 |   31 | echo "🎉 所有测试完成!"
1005 | 
1006 | ```
1007 | 
1008 | `spoke/Tests/test_edge_tts.swift`:
1009 | 
1010 | ```swift
1011 |    1 | #!/usr/bin/env swift
1012 |    2 | 
1013 |    3 | import Foundation
1014 |    4 | import CryptoKit
1015 |    5 | import AVFoundation
1016 |    6 | 
1017 |    7 | // MARK: - Edge TTS 测试脚本
1018 |    8 | 
1019 |    9 | print("🧪 Edge TTS 测试")
1020 |   10 | print(String(repeating: "=", count: 50))
1021 |   11 | 
1022 |   12 | // 配置
1023 |   13 | let text = "你好，这是语音合成测试。Hello, this is a test."
1024 |   14 | let voice = "zh-CN-XiaoxiaoNeural"
1025 |   15 | let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
1026 |   16 | let chromiumVersion = "130.0.2849.68"
1027 |   17 | let windowsFileTimeEpoch: Int64 = 11_644_473_600
1028 |   18 | 
1029 |   19 | // 生成 DRM Token
1030 |   20 | func generateSecMsGecToken() -> String {
1031 |   21 |     let currentTime = Int64(Date().timeIntervalSince1970)
1032 |   22 |     let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
1033 |   23 |     let roundedTicks = ticks - (ticks % 3_000_000_000)
1034 |   24 |     let strToHash = "\(roundedTicks)\(trustedClientToken)"
1035 |   25 |     let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
1036 |   26 |     return hash.map { String(format: "%02X", $0) }.joined()
1037 |   27 | }
1038 |   28 | 
1039 |   29 | // WebSocket Delegate
1040 |   30 | class WSDelegate: NSObject, URLSessionWebSocketDelegate {
1041 |   31 |     var onOpen: (() -> Void)?
1042 |   32 |     
1043 |   33 |     func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
1044 |   34 |         print("   ✅ WebSocket 已连接")
1045 |   35 |         onOpen?()
1046 |   36 |     }
1047 |   37 | }
1048 |   38 | 
1049 |   39 | // 主测试
1050 |   40 | func runTest() async {
1051 |   41 |     print("\n📝 测试文本: \(text)")
1052 |   42 |     print("🎤 语音: \(voice)")
1053 |   43 |     
1054 |   44 |     // 构建 URL
1055 |   45 |     let secMsGec = generateSecMsGecToken()
1056 |   46 |     let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
1057 |   47 |     
1058 |   48 |     guard let url = URL(string: urlString) else {
1059 |   49 |         print("❌ URL 无效")
1060 |   50 |         return
1061 |   51 |     }
1062 |   52 |     
1063 |   53 |     // 创建 WebSocket
1064 |   54 |     print("\n🔗 正在连接...")
1065 |   55 |     var request = URLRequest(url: url)
1066 |   56 |     request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
1067 |   57 |     request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
1068 |   58 |     
1069 |   59 |     let delegate = WSDelegate()
1070 |   60 |     let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
1071 |   61 |     let ws = session.webSocketTask(with: request)
1072 |   62 |     
1073 |   63 |     // 等待连接
1074 |   64 |     await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
1075 |   65 |         delegate.onOpen = { cont.resume() }
1076 |   66 |         ws.resume()
1077 |   67 |     }
1078 |   68 |     
1079 |   69 |     // 发送配置
1080 |   70 |     print("📤 发送配置...")
1081 |   71 |     let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
1082 |   72 |     do {
1083 |   73 |         try await ws.send(.string(configMessage))
1084 |   74 |         print("   ✅ 配置已发送")
1085 |   75 |     } catch {
1086 |   76 |         print("   ❌ 发送配置失败: \(error)")
1087 |   77 |         return
1088 |   78 |     }
1089 |   79 |     
1090 |   80 |     // 发送 SSML
1091 |   81 |     print("📤 发送 SSML...")
1092 |   82 |     let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
1093 |   83 |     let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
1094 |   84 |     do {
1095 |   85 |         try await ws.send(.string(ssmlMessage))
1096 |   86 |         print("   ✅ SSML 已发送")
1097 |   87 |     } catch {
1098 |   88 |         print("   ❌ 发送 SSML 失败: \(error)")
1099 |   89 |         return
1100 |   90 |     }
1101 |   91 |     
1102 |   92 |     // 接收音频
1103 |   93 |     print("\n📥 接收音频数据...")
1104 |   94 |     var audioData = Data()
1105 |   95 |     var messageCount = 0
1106 |   96 |     
1107 |   97 |     while true {
1108 |   98 |         do {
1109 |   99 |             let message = try await ws.receive()
1110 |  100 |             messageCount += 1
1111 |  101 |             
1112 |  102 |             switch message {
1113 |  103 |             case .data(let data):
1114 |  104 |                 // 尝试解析为字符串查看内容
1115 |  105 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
1116 |  106 |                     // 找到音频分隔符后的数据
1117 |  107 |                     if let range = str.range(of: "Path:audio\r\n") {
1118 |  108 |                         let offset = range.upperBound.utf16Offset(in: str)
1119 |  109 |                         let audioChunk = data.suffix(from: offset)
1120 |  110 |                         audioData.append(audioChunk)
1121 |  111 |                         print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
1122 |  112 |                     }
1123 |  113 |                 } else {
1124 |  114 |                     // 纯二进制音频
1125 |  115 |                     audioData.append(data)
1126 |  116 |                     print("   收到音频块 #\(messageCount): \(data.count) bytes")
1127 |  117 |                 }
1128 |  118 |                 
1129 |  119 |             case .string(let str):
1130 |  120 |                 if str.contains("Path:turn.end") {
1131 |  121 |                     print("   ✅ 收到结束信号")
1132 |  122 |                     break
1133 |  123 |                 } else if str.contains("Path:audio.metadata") {
1134 |  124 |                     print("   收到元数据")
1135 |  125 |                 } else {
1136 |  126 |                     print("   收到文本: \(str.prefix(50))...")
1137 |  127 |                 }
1138 |  128 |                 continue
1139 |  129 |                 
1140 |  130 |             @unknown default:
1141 |  131 |                 continue
1142 |  132 |             }
1143 |  133 |             
1144 |  134 |             if messageCount > 100 { break } // 防止死循环
1145 |  135 |             
1146 |  136 |         } catch {
1147 |  137 |             print("   ⚠️ 接收错误: \(error)")
1148 |  138 |             break
1149 |  139 |         }
1150 |  140 |     }
1151 |  141 |     
1152 |  142 |     ws.cancel(with: .goingAway, reason: nil)
1153 |  143 |     
1154 |  144 |     print("\n📊 结果:")
1155 |  145 |     print("   总消息数: \(messageCount)")
1156 |  146 |     print("   音频大小: \(audioData.count) bytes")
1157 |  147 |     
1158 |  148 |     if audioData.isEmpty {
1159 |  149 |         print("   ❌ 没有收到音频数据")
1160 |  150 |         return
1161 |  151 |     }
1162 |  152 |     
1163 |  153 |     // 检查音频头
1164 |  154 |     let header = audioData.prefix(16)
1165 |  155 |     print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
1166 |  156 |     
1167 |  157 |     // MP3 文件应该以 FF FB 或 ID3 开头
1168 |  158 |     if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
1169 |  159 |         print("   ✅ 看起来是有效的 MP3 格式")
1170 |  160 |     } else {
1171 |  161 |         print("   ⚠️ 可能不是标准 MP3 格式")
1172 |  162 |     }
1173 |  163 |     
1174 |  164 |     // 保存到文件
1175 |  165 |     let tempPath = "/tmp/edge_tts_test.mp3"
1176 |  166 |     do {
1177 |  167 |         try audioData.write(to: URL(fileURLWithPath: tempPath))
1178 |  168 |         print("\n💾 已保存到: \(tempPath)")
1179 |  169 |     } catch {
1180 |  170 |         print("   ❌ 保存失败: \(error)")
1181 |  171 |         return
1182 |  172 |     }
1183 |  173 |     
1184 |  174 |     // 播放测试
1185 |  175 |     print("\n🔊 播放测试...")
1186 |  176 |     do {
1187 |  177 |         let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
1188 |  178 |         player.prepareToPlay()
1189 |  179 |         
1190 |  180 |         if player.play() {
1191 |  181 |             print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
1192 |  182 |             
1193 |  183 |             // 等待播放完成
1194 |  184 |             while player.isPlaying {
1195 |  185 |                 try await Task.sleep(nanoseconds: 100_000_000)
1196 |  186 |             }
1197 |  187 |             print("   ✅ 播放完成!")
1198 |  188 |         } else {
1199 |  189 |             print("   ❌ 播放启动失败")
1200 |  190 |         }
1201 |  191 |     } catch {
1202 |  192 |         print("   ❌ 播放错误: \(error)")
1203 |  193 |         
1204 |  194 |         // 尝试用 afplay 播放
1205 |  195 |         print("\n🔧 尝试用 afplay 播放...")
1206 |  196 |         let process = Process()
1207 |  197 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
1208 |  198 |         process.arguments = [tempPath]
1209 |  199 |         try? process.run()
1210 |  200 |         process.waitUntilExit()
1211 |  201 |         
1212 |  202 |         if process.terminationStatus == 0 {
1213 |  203 |             print("   ✅ afplay 播放成功!")
1214 |  204 |         } else {
1215 |  205 |             print("   ❌ afplay 也失败了")
1216 |  206 |         }
1217 |  207 |     }
1218 |  208 | }
1219 |  209 | 
1220 |  210 | // 运行测试
1221 |  211 | Task {
1222 |  212 |     await runTest()
1223 |  213 |     exit(0)
1224 |  214 | }
1225 |  215 | 
1226 |  216 | // 保持运行
1227 |  217 | RunLoop.main.run()
1228 | 
1229 | ```

```

`spoke/docs/code2prompt-output/lucid-source.json`:

```json
   1 | {
   2 |   "directory_name": "spoke",
   3 |   "files": [
   4 |     "spoke/Tests/AttachmentTests.swift",
   5 |     "spoke/Tests/EdgeTTSTests.swift",
   6 |     "spoke/Tests/TextExtractionTests.swift",
   7 |     "spoke/Tests/test_edge_tts.swift"
   8 |   ],
   9 |   "model_info": "ChatGPT models, text-embedding-ada-002",
  10 |   "prompt": "<directory>spoke</directory>\n\n<source-tree>\nspoke\n└── Tests\n    ├── AttachmentTests.swift\n    ├── EdgeTTSTests.swift\n    ├── TextExtractionTests.swift\n    └── test_edge_tts.swift\n\n</source-tree>\n\n<files>\n<file path=\"spoke/Tests/AttachmentTests.swift\">\n```swift\nimport Foundation\nimport AppKit\n\n// MARK: - Attachment Tests\n\n/// Attachment 类型单元测试\n/// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests\n@main\nstruct AttachmentTests {\n    \n    static var passCount = 0\n    static var failCount = 0\n    \n    static func main() async {\n        print(\"🧪 Attachment 类型单元测试\")\n        print(\"=\" * 50)\n        \n        // 运行测试\n        runTest(\"Image 类型属性\") { try testImageAttachment() }\n        runTest(\"Screenshot 类型属性\") { try testScreenshotAttachment() }\n        runTest(\"File 类型属性\") { try testFileAttachment() }\n        runTest(\"TextBundle 类型属性\") { try testTextBundleAttachment() }\n        runTest(\"视频文件检测\") { try testVideoDetection() }\n        runTest(\"ID 相等性判断\") { try testEqualityById() }\n        runTest(\"缩略图缩放大图\") { try testThumbnailResizesLarge() }\n        runTest(\"缩略图保持比例\") { try testThumbnailPreservesRatio() }\n        runTest(\"缩略图不放大小图\") { try testThumbnailNoUpscale() }\n        runTest(\"缩略图处理空图\") { try testThumbnailZeroSize() }\n        \n        print(\"\\n\" + \"=\" * 50)\n        print(\"✅ 通过: \\(passCount)  ❌ 失败: \\(failCount)\")\n    }\n    \n    // MARK: - Test Runner\n    \n    static func runTest(_ name: String, _ test: () throws -> Void) {\n        print(\"\\n📝 测试: \\(name)\")\n        do {\n            try test()\n            print(\"   ✅ 通过\")\n            passCount += 1\n        } catch {\n            print(\"   ❌ 失败: \\(error)\")\n            failCount += 1\n        }\n    }\n    \n    // MARK: - Test Cases: Attachment Types\n    \n    static func testImageAttachment() throws {\n        let image = NSImage(size: NSSize(width: 100, height: 100))\n        let thumbnail = NSImage(size: NSSize(width: 50, height: 50))\n        let id = UUID()\n        \n        let attachment = Attachment.image(image, thumbnail, id)\n        \n        try assertEqual(attachment.id, id, \"ID\")\n        try assertEqual(attachment.displayTitle, \"图片\", \"displayTitle\")\n        try assertNotNil(attachment.thumbnail, \"thumbnail\")\n        try assertNotNil(attachment.originalImage, \"originalImage\")\n        try assertFalse(attachment.isVideo, \"isVideo\")\n        try assertFalse(attachment.isTextBundle, \"isTextBundle\")\n        try assertNil(attachment.textContent, \"textContent\")\n    }\n    \n    static func testScreenshotAttachment() throws {\n        let image = NSImage(size: NSSize(width: 1920, height: 1080))\n        let id = UUID()\n        \n        let attachment = Attachment.screenshot(image, nil, id)\n        \n        try assertEqual(attachment.id, id, \"ID\")\n        try assertEqual(attachment.displayTitle, \"截图\", \"displayTitle\")\n        try assertNil(attachment.thumbnail, \"thumbnail (should be nil)\")\n        try assertNotNil(attachment.originalImage, \"originalImage\")\n    }\n    \n    static func testFileAttachment() throws {\n        let url = URL(fileURLWithPath: \"/tmp/test.pdf\")\n        let id = UUID()\n        \n        let attachment = Attachment.file(url, id)\n        \n        try assertEqual(attachment.id, id, \"ID\")\n        try assertEqual(attachment.displayTitle, \"test.pdf\", \"displayTitle\")\n        try assertEqual(attachment.fileName, \"test.pdf\", \"fileName\")\n        try assertNil(attachment.thumbnail, \"thumbnail\")\n        try assertNil(attachment.originalImage, \"originalImage\")\n    }\n    \n    static func testTextBundleAttachment() throws {\n        let content = \"# Code content\\nlet x = 1\"\n        let source = \"my-project\"\n        let count = 42\n        let id = UUID()\n        \n        let attachment = Attachment.textBundle(content, source, count, id)\n        \n        try assertEqual(attachment.id, id, \"ID\")\n        try assertEqual(attachment.displayTitle, \"my-project (42 文件)\", \"displayTitle\")\n        try assertEqual(attachment.fileName, source, \"fileName\")\n        try assertTrue(attachment.isTextBundle, \"isTextBundle\")\n        try assertEqual(attachment.textContent, content, \"textContent\")\n    }\n    \n    static func testVideoDetection() throws {\n        let mp4 = Attachment.file(URL(fileURLWithPath: \"/tmp/video.mp4\"), UUID())\n        let mov = Attachment.file(URL(fileURLWithPath: \"/tmp/video.mov\"), UUID())\n        let txt = Attachment.file(URL(fileURLWithPath: \"/tmp/text.txt\"), UUID())\n        \n        try assertTrue(mp4.isVideo, \"mp4 should be video\")\n        try assertTrue(mov.isVideo, \"mov should be video\")\n        try assertFalse(txt.isVideo, \"txt should not be video\")\n    }\n    \n    static func testEqualityById() throws {\n        let id = UUID()\n        let image1 = NSImage(size: NSSize(width: 100, height: 100))\n        let image2 = NSImage(size: NSSize(width: 200, height: 200))\n        \n        let att1 = Attachment.image(image1, nil, id)\n        let att2 = Attachment.image(image2, nil, id)\n        let att3 = Attachment.image(image1, nil, UUID())\n        \n        try assertTrue(att1 == att2, \"Same ID should be equal\")\n        try assertFalse(att1 == att3, \"Different ID should not be equal\")\n    }\n    \n    // MARK: - Test Cases: Thumbnail Generation\n    \n    static func testThumbnailResizesLarge() throws {\n        let large = createTestImage(width: 2000, height: 1000)\n        let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)\n        \n        try assertTrue(thumb.size.width <= 256, \"Width should be <= 256\")\n        try assertTrue(thumb.size.height <= 256, \"Height should be <= 256\")\n    }\n    \n    static func testThumbnailPreservesRatio() throws {\n        let image = createTestImage(width: 2000, height: 1000)\n        let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)\n        \n        let ratio = thumb.size.width / thumb.size.height\n        try assertTrue(abs(ratio - 2.0) < 0.01, \"Ratio should be 2:1, got \\(ratio)\")\n    }\n    \n    static func testThumbnailNoUpscale() throws {\n        let small = createTestImage(width: 50, height: 50)\n        let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)\n        \n        try assertEqual(thumb.size.width, 50, \"Width\")\n        try assertEqual(thumb.size.height, 50, \"Height\")\n    }\n    \n    static func testThumbnailZeroSize() throws {\n        let zero = NSImage(size: NSSize(width: 0, height: 0))\n        let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)\n        \n        try assertEqual(thumb.size.width, 0, \"Width\")\n    }\n    \n    // MARK: - Helpers\n    \n    static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {\n        let image = NSImage(size: NSSize(width: width, height: height))\n        image.lockFocus()\n        NSColor.red.setFill()\n        NSRect(x: 0, y: 0, width: width, height: height).fill()\n        image.unlockFocus()\n        return image\n    }\n}\n\n// MARK: - Attachment Type (简化版，用于测试)\n\nimport UniformTypeIdentifiers\n\nenum Attachment: Identifiable, Equatable {\n    case image(NSImage, NSImage?, UUID)\n    case screenshot(NSImage, NSImage?, UUID)\n    case file(URL, UUID)\n    case textBundle(String, String, Int, UUID)\n    \n    var id: UUID {\n        switch self {\n        case .image(_, _, let id), .screenshot(_, _, let id),\n             .file(_, let id), .textBundle(_, _, _, let id):\n            return id\n        }\n    }\n    \n    var thumbnail: NSImage? {\n        switch self {\n        case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb\n        default: return nil\n        }\n    }\n    \n    var originalImage: NSImage? {\n        switch self {\n        case .image(let img, _, _), .screenshot(let img, _, _): return img\n        default: return nil\n        }\n    }\n    \n    var fileName: String? {\n        switch self {\n        case .file(let url, _): return url.lastPathComponent\n        case .textBundle(_, let source, _, _): return source\n        default: return nil\n        }\n    }\n    \n    var displayTitle: String {\n        switch self {\n        case .image: return \"图片\"\n        case .screenshot: return \"截图\"\n        case .file(let url, _): return url.lastPathComponent\n        case .textBundle(_, let source, let count, _): return \"\\(source) (\\(count) 文件)\"\n        }\n    }\n    \n    var isVideo: Bool {\n        if case .file(let url, _) = self,\n           let uti = UTType(filenameExtension: url.pathExtension) {\n            return uti.conforms(to: .movie) || uti.conforms(to: .video)\n        }\n        return false\n    }\n    \n    var isTextBundle: Bool {\n        if case .textBundle = self { return true }\n        return false\n    }\n    \n    var textContent: String? {\n        if case .textBundle(let content, _, _, _) = self { return content }\n        return nil\n    }\n    \n    static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }\n    \n    static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {\n        let size = image.size\n        guard size.width > 0 && size.height > 0 else { return image }\n        \n        let scale = min(maxSize / size.width, maxSize / size.height, 1.0)\n        let newSize = NSSize(width: size.width * scale, height: size.height * scale)\n        \n        let thumbnail = NSImage(size: newSize)\n        thumbnail.lockFocus()\n        image.draw(in: NSRect(origin: .zero, size: newSize),\n                   from: NSRect(origin: .zero, size: size),\n                   operation: .copy, fraction: 1.0)\n        thumbnail.unlockFocus()\n        return thumbnail\n    }\n}\n\n// MARK: - Assertion Helpers\n\nstruct TestError: Error, CustomStringConvertible {\n    let message: String\n    init(_ message: String) { self.message = message }\n    var description: String { message }\n}\n\nfunc assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {\n    if actual != expected {\n        throw TestError(\"\\(name): 期望 \\(expected), 实际 \\(actual)\")\n    }\n}\n\nfunc assertTrue(_ condition: Bool, _ message: String) throws {\n    if !condition { throw TestError(message) }\n}\n\nfunc assertFalse(_ condition: Bool, _ message: String) throws {\n    if condition { throw TestError(message) }\n}\n\nfunc assertNil<T>(_ value: T?, _ message: String) throws {\n    if value != nil { throw TestError(\"\\(message) 应该是 nil\") }\n}\n\nfunc assertNotNil<T>(_ value: T?, _ message: String) throws {\n    if value == nil { throw TestError(\"\\(message) 不应该是 nil\") }\n}\n\nextension String {\n    static func * (string: String, count: Int) -> String {\n        String(repeating: string, count: count)\n    }\n}\n\n```\n</file>\n<file path=\"spoke/Tests/EdgeTTSTests.swift\">\n```swift\nimport Foundation\nimport AVFoundation\n\n// MARK: - Edge TTS 单元测试\n\n@main\nstruct EdgeTTSTests {\n    static func main() async {\n        print(\"🧪 Edge TTS 单元测试\")\n        print(\"=\" * 50)\n        \n        await testSynthesizeAndPlay()\n    }\n    \n    /// 测试合成并播放\n    static func testSynthesizeAndPlay() async {\n        print(\"\\n📝 测试: 合成并播放\")\n        \n        let text = \"你好，这是语音合成测试。\"\n        let voice = \"zh-CN-XiaoxiaoNeural\"\n        \n        do {\n            // 1. 合成音频\n            print(\"   正在合成...\")\n            let audioData = try await synthesize(text: text, voice: voice)\n            print(\"   ✅ 合成完成: \\(audioData.count) bytes\")\n            \n            // 2. 检查音频头\n            print(\"   音频头部: \\(audioData.prefix(16).map { String(format: \"%02X\", $0) }.joined(separator: \" \"))\")\n            \n            // 3. 保存到文件测试\n            let tempPath = \"/tmp/edge_tts_test.mp3\"\n            try audioData.write(to: URL(fileURLWithPath: tempPath))\n            print(\"   ✅ 已保存到: \\(tempPath)\")\n            \n            // 4. 用 AVAudioPlayer 播放\n            print(\"   正在播放...\")\n            let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))\n            player.prepareToPlay()\n            player.play()\n            \n            // 等待播放完成\n            while player.isPlaying {\n                try await Task.sleep(nanoseconds: 100_000_000)\n            }\n            print(\"   ✅ 播放完成!\")\n            \n        } catch {\n            print(\"   ❌ 错误: \\(error)\")\n        }\n    }\n    \n    /// 合成音频\n    static func synthesize(text: String, voice: String) async throws -> Data {\n        // DRM Token\n        let trustedClientToken = \"6A5AA1D4EAFF4E9FB37E23D68491D6F4\"\n        let chromiumVersion = \"130.0.2849.68\"\n        let windowsFileTimeEpoch: Int64 = 11_644_473_600\n        \n        let currentTime = Int64(Date().timeIntervalSince1970)\n        let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000\n        let roundedTicks = ticks - (ticks % 3_000_000_000)\n        let strToHash = \"\\(roundedTicks)\\(trustedClientToken)\"\n        \n        // SHA256\n        import CryptoKit\n        let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)\n        let secMsGec = hash.map { String(format: \"%02X\", $0) }.joined()\n        \n        // URL\n        let urlString = \"wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\\(trustedClientToken)&Sec-MS-GEC=\\(secMsGec)&Sec-MS-GEC-Version=1-\\(chromiumVersion)\"\n        let url = URL(string: urlString)!\n        \n        // WebSocket\n        var request = URLRequest(url: url)\n        request.setValue(\"chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold\", forHTTPHeaderField: \"Origin\")\n        request.setValue(\"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\\(chromiumVersion) Edg/\\(chromiumVersion)\", forHTTPHeaderField: \"User-Agent\")\n        \n        let session = URLSession.shared\n        let ws = session.webSocketTask(with: request)\n        ws.resume()\n        \n        // 等待连接\n        try await Task.sleep(nanoseconds: 500_000_000)\n        \n        // 发送配置\n        let configMessage = \"Content-Type:application/json; charset=utf-8\\r\\nPath:speech.config\\r\\n\\r\\n{\\\"context\\\":{\\\"synthesis\\\":{\\\"audio\\\":{\\\"metadataoptions\\\":{\\\"sentenceBoundaryEnabled\\\":\\\"false\\\",\\\"wordBoundaryEnabled\\\":\\\"false\\\"},\\\"outputFormat\\\":\\\"audio-24khz-48kbitrate-mono-mp3\\\"}}}}\"\n        try await ws.send(.string(configMessage))\n        \n        // 发送 SSML\n        let ssml = \"<speak version=\\\"1.0\\\" xmlns=\\\"http://www.w3.org/2001/10/synthesis\\\" xml:lang=\\\"zh-CN\\\"><voice name=\\\"\\(voice)\\\"><prosody rate=\\\"+0%\\\" pitch=\\\"+0Hz\\\">\\(text)</prosody></voice></speak>\"\n        let ssmlMessage = \"X-RequestId:\\(UUID().uuidString)\\r\\nContent-Type:application/ssml+xml\\r\\nPath:ssml\\r\\n\\r\\n\\(ssml)\"\n        try await ws.send(.string(ssmlMessage))\n        \n        // 接收音频\n        var audioData = Data()\n        \n        while true {\n            let message = try await ws.receive()\n            \n            switch message {\n            case .data(let data):\n                // 检查是否包含 Path:audio\n                if let str = String(data: data, encoding: .utf8), str.contains(\"Path:audio\\r\\n\") {\n                    if let range = str.range(of: \"Path:audio\\r\\n\") {\n                        let offset = range.upperBound.utf16Offset(in: str)\n                        audioData.append(data[offset...])\n                    }\n                } else {\n                    audioData.append(data)\n                }\n                \n            case .string(let str):\n                if str.contains(\"Path:turn.end\") {\n                    ws.cancel(with: .goingAway, reason: nil)\n                    return audioData\n                }\n                \n            @unknown default:\n                break\n            }\n        }\n    }\n}\n\nextension String {\n    static func * (string: String, count: Int) -> String {\n        String(repeating: string, count: count)\n    }\n}\n\n```\n</file>\n<file path=\"spoke/Tests/TextExtractionTests.swift\">\n```swift\nimport Foundation\n\n// MARK: - Text Extraction Service Tests\n\n/// 独立运行的测试脚本\n/// 用法: swift Tests/TextExtractionTests.swift\n@main\nstruct TextExtractionTests {\n    \n    static var tempDirectory: URL!\n    static var passCount = 0\n    static var failCount = 0\n    \n    static func main() async {\n        print(\"🧪 TextExtractionService 单元测试\")\n        print(\"=\" * 50)\n        \n        // 创建临时目录\n        tempDirectory = FileManager.default.temporaryDirectory\n            .appendingPathComponent(\"TextExtractionTests-\\(UUID().uuidString)\")\n        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        defer {\n            // 清理\n            try? FileManager.default.removeItem(at: tempDirectory)\n            print(\"\\n\" + \"=\" * 50)\n            print(\"✅ 通过: \\(passCount)  ❌ 失败: \\(failCount)\")\n        }\n        \n        // 运行测试\n        await runTest(\"代码文件扩展名识别\") { try await testCodeExtensions() }\n        await runTest(\"单文件提取\") { try await testSingleFileExtraction() }\n        await runTest(\"多文件合并\") { try await testMultipleFilesExtraction() }\n        await runTest(\"排除 node_modules\") { try await testExcludesNodeModules() }\n        await runTest(\"排除锁文件\") { try await testExcludesLockFiles() }\n        await runTest(\"递归遍历嵌套目录\") { try await testNestedDirectories() }\n        await runTest(\"空文件夹返回错误\") { try await testEmptyFolderError() }\n        await runTest(\"忽略非代码文件\") { try await testIgnoresNonCodeFiles() }\n        await runTest(\"添加行号\") { try await testAddsLineNumbers() }\n        await runTest(\"目录结构输出\") { try await testDirectoryStructure() }\n        await runTest(\"ZIP 提取\") { try await testZIPExtraction() }\n    }\n    \n    // MARK: - Test Runner\n    \n    static func runTest(_ name: String, _ test: () async throws -> Void) async {\n        print(\"\\n📝 测试: \\(name)\")\n        do {\n            try await test()\n            print(\"   ✅ 通过\")\n            passCount += 1\n        } catch {\n            print(\"   ❌ 失败: \\(error)\")\n            failCount += 1\n        }\n    }\n    \n    // MARK: - Helpers\n    \n    static func createFile(name: String, content: String) throws -> URL {\n        let fileURL = tempDirectory.appendingPathComponent(name)\n        let dir = fileURL.deletingLastPathComponent()\n        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)\n        try content.write(to: fileURL, atomically: true, encoding: .utf8)\n        return fileURL\n    }\n    \n    static func createDirectory(name: String) throws -> URL {\n        let dirURL = tempDirectory.appendingPathComponent(name)\n        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)\n        return dirURL\n    }\n    \n    // MARK: - Test Cases\n    \n    static func testCodeExtensions() async throws {\n        // 创建各种代码文件\n        _ = try createFile(name: \"test.swift\", content: \"let x = 1\")\n        _ = try createFile(name: \"app.js\", content: \"const x = 1\")\n        _ = try createFile(name: \"main.py\", content: \"x = 1\")\n        _ = try createFile(name: \"README.md\", content: \"# Title\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.fileCount == 4 else {\n            throw TestError(\"文件数量错误: 期望 4, 实际 \\(bundle.fileCount)\")\n        }\n    }\n    \n    static func testSingleFileExtraction() async throws {\n        // 清理并创建新目录\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        _ = try createFile(name: \"main.swift\", content: \"print(\\\"Hello\\\")\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.fileCount == 1 else {\n            throw TestError(\"文件数量错误: 期望 1, 实际 \\(bundle.fileCount)\")\n        }\n        guard bundle.content.contains(\"print(\\\"Hello\\\")\") else {\n            throw TestError(\"内容不包含预期文本\")\n        }\n    }\n    \n    static func testMultipleFilesExtraction() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        _ = try createFile(name: \"a.swift\", content: \"let a = 1\")\n        _ = try createFile(name: \"b.swift\", content: \"let b = 2\")\n        _ = try createFile(name: \"c.js\", content: \"const c = 3\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.fileCount == 3 else {\n            throw TestError(\"文件数量错误\")\n        }\n        guard bundle.content.contains(\"let a = 1\") &&\n              bundle.content.contains(\"let b = 2\") &&\n              bundle.content.contains(\"const c = 3\") else {\n            throw TestError(\"内容缺失\")\n        }\n    }\n    \n    static func testExcludesNodeModules() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        let nodeModules = try createDirectory(name: \"node_modules\")\n        try \"const secret = 'password'\".write(\n            to: nodeModules.appendingPathComponent(\"secret.js\"),\n            atomically: true, encoding: .utf8\n        )\n        _ = try createFile(name: \"app.js\", content: \"const app = 1\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.fileCount == 1 else {\n            throw TestError(\"应该只包含 app.js\")\n        }\n        guard !bundle.content.contains(\"secret\") else {\n            throw TestError(\"不应包含 node_modules 内容\")\n        }\n    }\n    \n    static func testExcludesLockFiles() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        _ = try createFile(name: \"package-lock.json\", content: \"{}\")\n        _ = try createFile(name: \"yarn.lock\", content: \"\")\n        _ = try createFile(name: \"package.json\", content: \"{\\\"name\\\": \\\"test\\\"}\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.fileCount == 1 else {\n            throw TestError(\"应该只包含 package.json\")\n        }\n    }\n    \n    static func testNestedDirectories() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        _ = try createFile(name: \"root.swift\", content: \"let root = 1\")\n        _ = try createFile(name: \"src/app.swift\", content: \"let src = 2\")\n        _ = try createFile(name: \"src/lib/utils.swift\", content: \"let lib = 3\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.fileCount == 3 else {\n            throw TestError(\"应该包含 3 个文件\")\n        }\n        guard bundle.content.contains(\"let root = 1\") &&\n              bundle.content.contains(\"let src = 2\") &&\n              bundle.content.contains(\"let lib = 3\") else {\n            throw TestError(\"缺少嵌套目录内容\")\n        }\n    }\n    \n    static func testEmptyFolderError() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        let emptyDir = try createDirectory(name: \"empty\")\n        \n        let result = await extractFromFolder(emptyDir)\n        guard case .failure = result else {\n            throw TestError(\"空文件夹应该返回错误\")\n        }\n    }\n    \n    static func testIgnoresNonCodeFiles() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        _ = try createFile(name: \"image.png\", content: \"fake\")\n        _ = try createFile(name: \"video.mp4\", content: \"fake\")\n        _ = try createFile(name: \"main.swift\", content: \"let x = 1\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.fileCount == 1 else {\n            throw TestError(\"应该只包含 .swift 文件\")\n        }\n    }\n    \n    static func testAddsLineNumbers() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        _ = try createFile(name: \"test.txt\", content: \"line one\\nline two\\nline three\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.content.contains(\"1│\") &&\n              bundle.content.contains(\"2│\") &&\n              bundle.content.contains(\"3│\") else {\n            throw TestError(\"缺少行号\")\n        }\n    }\n    \n    static func testDirectoryStructure() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        _ = try createFile(name: \"main.swift\", content: \"entry\")\n        _ = try createFile(name: \"src/app.swift\", content: \"code\")\n        \n        let result = await extractFromFolder(tempDirectory)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"提取失败\")\n        }\n        \n        guard bundle.content.contains(\"# 目录结构\") else {\n            throw TestError(\"缺少目录结构标题\")\n        }\n    }\n    \n    static func testZIPExtraction() async throws {\n        try FileManager.default.removeItem(at: tempDirectory)\n        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)\n        \n        // 创建源文件\n        let sourceDir = try createDirectory(name: \"source\")\n        try \"let x = 1\".write(to: sourceDir.appendingPathComponent(\"test.swift\"), atomically: true, encoding: .utf8)\n        \n        // 创建 ZIP\n        let zipPath = tempDirectory.appendingPathComponent(\"test.zip\")\n        let process = Process()\n        process.executableURL = URL(fileURLWithPath: \"/usr/bin/zip\")\n        process.currentDirectoryURL = tempDirectory\n        process.arguments = [\"-r\", zipPath.path, \"source\"]\n        process.standardOutput = FileHandle.nullDevice\n        process.standardError = FileHandle.nullDevice\n        try process.run()\n        process.waitUntilExit()\n        \n        guard process.terminationStatus == 0 else {\n            throw TestError(\"创建 ZIP 失败\")\n        }\n        \n        let result = await extractFromZIP(zipPath)\n        guard case .success(let bundle) = result else {\n            throw TestError(\"ZIP 提取失败\")\n        }\n        \n        guard bundle.fileCount == 1 else {\n            throw TestError(\"ZIP 文件数量错误\")\n        }\n        guard bundle.content.contains(\"let x = 1\") else {\n            throw TestError(\"ZIP 内容缺失\")\n        }\n    }\n}\n\n// MARK: - TextExtractionService (简化版，用于测试)\n\nstruct TextBundle {\n    let content: String\n    let fileCount: Int\n    let sourcePath: String\n    let files: [String]\n}\n\nenum TextExtractionError: Error, Equatable {\n    case folderNotFound\n    case zipExtractionFailed(String)\n    case noTextFilesFound\n    case accessDenied\n}\n\nfunc extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {\n    let codeExtensions: Set<String> = [\n        \"js\", \"jsx\", \"ts\", \"tsx\", \"mjs\", \"cjs\",\n        \"html\", \"htm\", \"css\", \"scss\", \"less\", \"vue\", \"svelte\",\n        \"py\", \"pyw\", \"pyi\",\n        \"java\", \"kt\", \"kts\", \"scala\",\n        \"c\", \"cpp\", \"cc\", \"cxx\", \"h\", \"hpp\", \"hxx\",\n        \"rs\", \"go\", \"rb\", \"erb\", \"php\", \"swift\",\n        \"sh\", \"bash\", \"zsh\", \"fish\",\n        \"json\", \"yaml\", \"yml\", \"toml\", \"xml\", \"ini\", \"cfg\", \"conf\",\n        \"md\", \"mdx\", \"txt\", \"rst\", \"asciidoc\",\n        \"sql\", \"graphql\", \"proto\", \"dockerfile\"\n    ]\n    \n    let excludedDirs: Set<String> = [\n        \"node_modules\", \".git\", \".svn\", \".hg\",\n        \"dist\", \"build\", \"target\", \".next\", \".nuxt\",\n        \"__pycache__\", \".pytest_cache\", \".tox\",\n        \"venv\", \"env\", \".env\", \".venv\",\n        \"vendor\", \"Pods\", \"Carthage\",\n        \".idea\", \".vscode\", \".vs\"\n    ]\n    \n    let excludedFiles: Set<String> = [\n        \".DS_Store\", \"Thumbs.db\", \".gitignore\", \".gitattributes\",\n        \"package-lock.json\", \"yarn.lock\", \"pnpm-lock.yaml\",\n        \"Podfile.lock\", \"Gemfile.lock\", \"Cargo.lock\"\n    ]\n    \n    // 递归收集文件\n    func collectFiles(in directory: URL) -> [URL] {\n        var result: [URL] = []\n        let fm = FileManager.default\n        \n        guard let contents = try? fm.contentsOfDirectory(\n            at: directory,\n            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],\n            options: [.skipsHiddenFiles]\n        ) else { return [] }\n        \n        for url in contents {\n            let fileName = url.lastPathComponent\n            if excludedFiles.contains(fileName) { continue }\n            \n            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])\n            \n            if values?.isDirectory == true {\n                if !excludedDirs.contains(fileName) {\n                    result.append(contentsOf: collectFiles(in: url))\n                }\n            } else if values?.isRegularFile == true {\n                let ext = url.pathExtension.lowercased()\n                if codeExtensions.contains(ext) {\n                    result.append(url)\n                }\n            }\n        }\n        return result.sorted { $0.path < $1.path }\n    }\n    \n    let files = collectFiles(in: folderURL)\n    guard !files.isEmpty else {\n        return .failure(.noTextFilesFound)\n    }\n    \n    // 合并内容\n    var parts: [String] = [\"# 目录结构\\n```\"]\n    for file in files {\n        let rel = file.path.replacingOccurrences(of: folderURL.path + \"/\", with: \"\")\n        parts.append(rel)\n    }\n    parts.append(\"```\\n\\n# 文件内容\\n\")\n    \n    for file in files {\n        let rel = file.path.replacingOccurrences(of: folderURL.path + \"/\", with: \"\")\n        let ext = file.pathExtension\n        if let content = try? String(contentsOf: file, encoding: .utf8) {\n            let numbered = content.components(separatedBy: .newlines).enumerated()\n                .map { \"\\($0.offset + 1)│ \\($0.element)\" }.joined(separator: \"\\n\")\n            parts.append(\"## \\(rel)\\n```\\(ext)\\n\\(numbered)\\n```\\n\")\n        }\n    }\n    \n    return .success(TextBundle(\n        content: parts.joined(separator: \"\\n\"),\n        fileCount: files.count,\n        sourcePath: folderURL.path,\n        files: files.map { $0.path }\n    ))\n}\n\nfunc extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {\n    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(\"zip-\\(UUID().uuidString)\")\n    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)\n    defer { try? FileManager.default.removeItem(at: tempDir) }\n    \n    let process = Process()\n    process.executableURL = URL(fileURLWithPath: \"/usr/bin/unzip\")\n    process.arguments = [\"-q\", \"-o\", zipURL.path, \"-d\", tempDir.path]\n    process.standardOutput = FileHandle.nullDevice\n    process.standardError = FileHandle.nullDevice\n    \n    do {\n        try process.run()\n        process.waitUntilExit()\n        \n        guard process.terminationStatus == 0 else {\n            return .failure(.zipExtractionFailed(\"Exit code: \\(process.terminationStatus)\"))\n        }\n        \n        return await extractFromFolder(tempDir)\n    } catch {\n        return .failure(.zipExtractionFailed(error.localizedDescription))\n    }\n}\n\n// MARK: - Helpers\n\nstruct TestError: Error, CustomStringConvertible {\n    let message: String\n    init(_ message: String) { self.message = message }\n    var description: String { message }\n}\n\nextension String {\n    static func * (string: String, count: Int) -> String {\n        String(repeating: string, count: count)\n    }\n}\n\n```\n</file>\n<file path=\"spoke/Tests/test_edge_tts.swift\">\n```swift\n#!/usr/bin/env swift\n\nimport Foundation\nimport CryptoKit\nimport AVFoundation\n\n// MARK: - Edge TTS 测试脚本\n\nprint(\"🧪 Edge TTS 测试\")\nprint(String(repeating: \"=\", count: 50))\n\n// 配置\nlet text = \"你好，这是语音合成测试。Hello, this is a test.\"\nlet voice = \"zh-CN-XiaoxiaoNeural\"\nlet trustedClientToken = \"6A5AA1D4EAFF4E9FB37E23D68491D6F4\"\nlet chromiumVersion = \"130.0.2849.68\"\nlet windowsFileTimeEpoch: Int64 = 11_644_473_600\n\n// 生成 DRM Token\nfunc generateSecMsGecToken() -> String {\n    let currentTime = Int64(Date().timeIntervalSince1970)\n    let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000\n    let roundedTicks = ticks - (ticks % 3_000_000_000)\n    let strToHash = \"\\(roundedTicks)\\(trustedClientToken)\"\n    let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)\n    return hash.map { String(format: \"%02X\", $0) }.joined()\n}\n\n// WebSocket Delegate\nclass WSDelegate: NSObject, URLSessionWebSocketDelegate {\n    var onOpen: (() -> Void)?\n    \n    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {\n        print(\"   ✅ WebSocket 已连接\")\n        onOpen?()\n    }\n}\n\n// 主测试\nfunc runTest() async {\n    print(\"\\n📝 测试文本: \\(text)\")\n    print(\"🎤 语音: \\(voice)\")\n    \n    // 构建 URL\n    let secMsGec = generateSecMsGecToken()\n    let urlString = \"wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\\(trustedClientToken)&Sec-MS-GEC=\\(secMsGec)&Sec-MS-GEC-Version=1-\\(chromiumVersion)\"\n    \n    guard let url = URL(string: urlString) else {\n        print(\"❌ URL 无效\")\n        return\n    }\n    \n    // 创建 WebSocket\n    print(\"\\n🔗 正在连接...\")\n    var request = URLRequest(url: url)\n    request.setValue(\"chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold\", forHTTPHeaderField: \"Origin\")\n    request.setValue(\"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\\(chromiumVersion) Edg/\\(chromiumVersion)\", forHTTPHeaderField: \"User-Agent\")\n    \n    let delegate = WSDelegate()\n    let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)\n    let ws = session.webSocketTask(with: request)\n    \n    // 等待连接\n    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in\n        delegate.onOpen = { cont.resume() }\n        ws.resume()\n    }\n    \n    // 发送配置\n    print(\"📤 发送配置...\")\n    let configMessage = \"Content-Type:application/json; charset=utf-8\\r\\nPath:speech.config\\r\\n\\r\\n{\\\"context\\\":{\\\"synthesis\\\":{\\\"audio\\\":{\\\"metadataoptions\\\":{\\\"sentenceBoundaryEnabled\\\":\\\"false\\\",\\\"wordBoundaryEnabled\\\":\\\"false\\\"},\\\"outputFormat\\\":\\\"audio-24khz-48kbitrate-mono-mp3\\\"}}}}\"\n    do {\n        try await ws.send(.string(configMessage))\n        print(\"   ✅ 配置已发送\")\n    } catch {\n        print(\"   ❌ 发送配置失败: \\(error)\")\n        return\n    }\n    \n    // 发送 SSML\n    print(\"📤 发送 SSML...\")\n    let ssml = \"<speak version=\\\"1.0\\\" xmlns=\\\"http://www.w3.org/2001/10/synthesis\\\" xml:lang=\\\"zh-CN\\\"><voice name=\\\"\\(voice)\\\"><prosody rate=\\\"+0%\\\" pitch=\\\"+0Hz\\\">\\(text)</prosody></voice></speak>\"\n    let ssmlMessage = \"X-RequestId:\\(UUID().uuidString)\\r\\nContent-Type:application/ssml+xml\\r\\nPath:ssml\\r\\n\\r\\n\\(ssml)\"\n    do {\n        try await ws.send(.string(ssmlMessage))\n        print(\"   ✅ SSML 已发送\")\n    } catch {\n        print(\"   ❌ 发送 SSML 失败: \\(error)\")\n        return\n    }\n    \n    // 接收音频\n    print(\"\\n📥 接收音频数据...\")\n    var audioData = Data()\n    var messageCount = 0\n    \n    while true {\n        do {\n            let message = try await ws.receive()\n            messageCount += 1\n            \n            switch message {\n            case .data(let data):\n                // 尝试解析为字符串查看内容\n                if let str = String(data: data, encoding: .utf8), str.contains(\"Path:audio\\r\\n\") {\n                    // 找到音频分隔符后的数据\n                    if let range = str.range(of: \"Path:audio\\r\\n\") {\n                        let offset = range.upperBound.utf16Offset(in: str)\n                        let audioChunk = data.suffix(from: offset)\n                        audioData.append(audioChunk)\n                        print(\"   收到音频块 #\\(messageCount): \\(audioChunk.count) bytes (有 header)\")\n                    }\n                } else {\n                    // 纯二进制音频\n                    audioData.append(data)\n                    print(\"   收到音频块 #\\(messageCount): \\(data.count) bytes\")\n                }\n                \n            case .string(let str):\n                if str.contains(\"Path:turn.end\") {\n                    print(\"   ✅ 收到结束信号\")\n                    break\n                } else if str.contains(\"Path:audio.metadata\") {\n                    print(\"   收到元数据\")\n                } else {\n                    print(\"   收到文本: \\(str.prefix(50))...\")\n                }\n                continue\n                \n            @unknown default:\n                continue\n            }\n            \n            if messageCount > 100 { break } // 防止死循环\n            \n        } catch {\n            print(\"   ⚠️ 接收错误: \\(error)\")\n            break\n        }\n    }\n    \n    ws.cancel(with: .goingAway, reason: nil)\n    \n    print(\"\\n📊 结果:\")\n    print(\"   总消息数: \\(messageCount)\")\n    print(\"   音频大小: \\(audioData.count) bytes\")\n    \n    if audioData.isEmpty {\n        print(\"   ❌ 没有收到音频数据\")\n        return\n    }\n    \n    // 检查音频头\n    let header = audioData.prefix(16)\n    print(\"   音频头: \\(header.map { String(format: \"%02X\", $0) }.joined(separator: \" \"))\")\n    \n    // MP3 文件应该以 FF FB 或 ID3 开头\n    if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {\n        print(\"   ✅ 看起来是有效的 MP3 格式\")\n    } else {\n        print(\"   ⚠️ 可能不是标准 MP3 格式\")\n    }\n    \n    // 保存到文件\n    let tempPath = \"/tmp/edge_tts_test.mp3\"\n    do {\n        try audioData.write(to: URL(fileURLWithPath: tempPath))\n        print(\"\\n💾 已保存到: \\(tempPath)\")\n    } catch {\n        print(\"   ❌ 保存失败: \\(error)\")\n        return\n    }\n    \n    // 播放测试\n    print(\"\\n🔊 播放测试...\")\n    do {\n        let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))\n        player.prepareToPlay()\n        \n        if player.play() {\n            print(\"   ▶️ 正在播放 (时长: \\(String(format: \"%.1f\", player.duration))秒)\")\n            \n            // 等待播放完成\n            while player.isPlaying {\n                try await Task.sleep(nanoseconds: 100_000_000)\n            }\n            print(\"   ✅ 播放完成!\")\n        } else {\n            print(\"   ❌ 播放启动失败\")\n        }\n    } catch {\n        print(\"   ❌ 播放错误: \\(error)\")\n        \n        // 尝试用 afplay 播放\n        print(\"\\n🔧 尝试用 afplay 播放...\")\n        let process = Process()\n        process.executableURL = URL(fileURLWithPath: \"/usr/bin/afplay\")\n        process.arguments = [tempPath]\n        try? process.run()\n        process.waitUntilExit()\n        \n        if process.terminationStatus == 0 {\n            print(\"   ✅ afplay 播放成功!\")\n        } else {\n            print(\"   ❌ afplay 也失败了\")\n        }\n    }\n}\n\n// 运行测试\nTask {\n    await runTest()\n    exit(0)\n}\n\n// 保持运行\nRunLoop.main.run()\n\n```\n</file>\n</files>",
  11 |   "token_count": 9990
  12 | }

```

`spoke/docs/code2prompt-output/lucid-source.md`:

```md
   1 | Project Path: spoke
   2 | 
   3 | Source Tree:
   4 | 
   5 | ```txt
   6 | spoke
   7 | └── Tests
   8 |     ├── AttachmentTests.swift
   9 |     ├── EdgeTTSTests.swift
  10 |     ├── TextExtractionTests.swift
  11 |     └── test_edge_tts.swift
  12 | 
  13 | ```
  14 | 
  15 | `spoke/Tests/AttachmentTests.swift`:
  16 | 
  17 | ```swift
  18 |    1 | import Foundation
  19 |    2 | import AppKit
  20 |    3 | 
  21 |    4 | // MARK: - Attachment Tests
  22 |    5 | 
  23 |    6 | /// Attachment 类型单元测试
  24 |    7 | /// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
  25 |    8 | @main
  26 |    9 | struct AttachmentTests {
  27 |   10 |     
  28 |   11 |     static var passCount = 0
  29 |   12 |     static var failCount = 0
  30 |   13 |     
  31 |   14 |     static func main() async {
  32 |   15 |         print("🧪 Attachment 类型单元测试")
  33 |   16 |         print("=" * 50)
  34 |   17 |         
  35 |   18 |         // 运行测试
  36 |   19 |         runTest("Image 类型属性") { try testImageAttachment() }
  37 |   20 |         runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
  38 |   21 |         runTest("File 类型属性") { try testFileAttachment() }
  39 |   22 |         runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
  40 |   23 |         runTest("视频文件检测") { try testVideoDetection() }
  41 |   24 |         runTest("ID 相等性判断") { try testEqualityById() }
  42 |   25 |         runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
  43 |   26 |         runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
  44 |   27 |         runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
  45 |   28 |         runTest("缩略图处理空图") { try testThumbnailZeroSize() }
  46 |   29 |         
  47 |   30 |         print("\n" + "=" * 50)
  48 |   31 |         print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  49 |   32 |     }
  50 |   33 |     
  51 |   34 |     // MARK: - Test Runner
  52 |   35 |     
  53 |   36 |     static func runTest(_ name: String, _ test: () throws -> Void) {
  54 |   37 |         print("\n📝 测试: \(name)")
  55 |   38 |         do {
  56 |   39 |             try test()
  57 |   40 |             print("   ✅ 通过")
  58 |   41 |             passCount += 1
  59 |   42 |         } catch {
  60 |   43 |             print("   ❌ 失败: \(error)")
  61 |   44 |             failCount += 1
  62 |   45 |         }
  63 |   46 |     }
  64 |   47 |     
  65 |   48 |     // MARK: - Test Cases: Attachment Types
  66 |   49 |     
  67 |   50 |     static func testImageAttachment() throws {
  68 |   51 |         let image = NSImage(size: NSSize(width: 100, height: 100))
  69 |   52 |         let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
  70 |   53 |         let id = UUID()
  71 |   54 |         
  72 |   55 |         let attachment = Attachment.image(image, thumbnail, id)
  73 |   56 |         
  74 |   57 |         try assertEqual(attachment.id, id, "ID")
  75 |   58 |         try assertEqual(attachment.displayTitle, "图片", "displayTitle")
  76 |   59 |         try assertNotNil(attachment.thumbnail, "thumbnail")
  77 |   60 |         try assertNotNil(attachment.originalImage, "originalImage")
  78 |   61 |         try assertFalse(attachment.isVideo, "isVideo")
  79 |   62 |         try assertFalse(attachment.isTextBundle, "isTextBundle")
  80 |   63 |         try assertNil(attachment.textContent, "textContent")
  81 |   64 |     }
  82 |   65 |     
  83 |   66 |     static func testScreenshotAttachment() throws {
  84 |   67 |         let image = NSImage(size: NSSize(width: 1920, height: 1080))
  85 |   68 |         let id = UUID()
  86 |   69 |         
  87 |   70 |         let attachment = Attachment.screenshot(image, nil, id)
  88 |   71 |         
  89 |   72 |         try assertEqual(attachment.id, id, "ID")
  90 |   73 |         try assertEqual(attachment.displayTitle, "截图", "displayTitle")
  91 |   74 |         try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
  92 |   75 |         try assertNotNil(attachment.originalImage, "originalImage")
  93 |   76 |     }
  94 |   77 |     
  95 |   78 |     static func testFileAttachment() throws {
  96 |   79 |         let url = URL(fileURLWithPath: "/tmp/test.pdf")
  97 |   80 |         let id = UUID()
  98 |   81 |         
  99 |   82 |         let attachment = Attachment.file(url, id)
 100 |   83 |         
 101 |   84 |         try assertEqual(attachment.id, id, "ID")
 102 |   85 |         try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
 103 |   86 |         try assertEqual(attachment.fileName, "test.pdf", "fileName")
 104 |   87 |         try assertNil(attachment.thumbnail, "thumbnail")
 105 |   88 |         try assertNil(attachment.originalImage, "originalImage")
 106 |   89 |     }
 107 |   90 |     
 108 |   91 |     static func testTextBundleAttachment() throws {
 109 |   92 |         let content = "# Code content\nlet x = 1"
 110 |   93 |         let source = "my-project"
 111 |   94 |         let count = 42
 112 |   95 |         let id = UUID()
 113 |   96 |         
 114 |   97 |         let attachment = Attachment.textBundle(content, source, count, id)
 115 |   98 |         
 116 |   99 |         try assertEqual(attachment.id, id, "ID")
 117 |  100 |         try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
 118 |  101 |         try assertEqual(attachment.fileName, source, "fileName")
 119 |  102 |         try assertTrue(attachment.isTextBundle, "isTextBundle")
 120 |  103 |         try assertEqual(attachment.textContent, content, "textContent")
 121 |  104 |     }
 122 |  105 |     
 123 |  106 |     static func testVideoDetection() throws {
 124 |  107 |         let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
 125 |  108 |         let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
 126 |  109 |         let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
 127 |  110 |         
 128 |  111 |         try assertTrue(mp4.isVideo, "mp4 should be video")
 129 |  112 |         try assertTrue(mov.isVideo, "mov should be video")
 130 |  113 |         try assertFalse(txt.isVideo, "txt should not be video")
 131 |  114 |     }
 132 |  115 |     
 133 |  116 |     static func testEqualityById() throws {
 134 |  117 |         let id = UUID()
 135 |  118 |         let image1 = NSImage(size: NSSize(width: 100, height: 100))
 136 |  119 |         let image2 = NSImage(size: NSSize(width: 200, height: 200))
 137 |  120 |         
 138 |  121 |         let att1 = Attachment.image(image1, nil, id)
 139 |  122 |         let att2 = Attachment.image(image2, nil, id)
 140 |  123 |         let att3 = Attachment.image(image1, nil, UUID())
 141 |  124 |         
 142 |  125 |         try assertTrue(att1 == att2, "Same ID should be equal")
 143 |  126 |         try assertFalse(att1 == att3, "Different ID should not be equal")
 144 |  127 |     }
 145 |  128 |     
 146 |  129 |     // MARK: - Test Cases: Thumbnail Generation
 147 |  130 |     
 148 |  131 |     static func testThumbnailResizesLarge() throws {
 149 |  132 |         let large = createTestImage(width: 2000, height: 1000)
 150 |  133 |         let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
 151 |  134 |         
 152 |  135 |         try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
 153 |  136 |         try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
 154 |  137 |     }
 155 |  138 |     
 156 |  139 |     static func testThumbnailPreservesRatio() throws {
 157 |  140 |         let image = createTestImage(width: 2000, height: 1000)
 158 |  141 |         let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
 159 |  142 |         
 160 |  143 |         let ratio = thumb.size.width / thumb.size.height
 161 |  144 |         try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
 162 |  145 |     }
 163 |  146 |     
 164 |  147 |     static func testThumbnailNoUpscale() throws {
 165 |  148 |         let small = createTestImage(width: 50, height: 50)
 166 |  149 |         let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
 167 |  150 |         
 168 |  151 |         try assertEqual(thumb.size.width, 50, "Width")
 169 |  152 |         try assertEqual(thumb.size.height, 50, "Height")
 170 |  153 |     }
 171 |  154 |     
 172 |  155 |     static func testThumbnailZeroSize() throws {
 173 |  156 |         let zero = NSImage(size: NSSize(width: 0, height: 0))
 174 |  157 |         let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
 175 |  158 |         
 176 |  159 |         try assertEqual(thumb.size.width, 0, "Width")
 177 |  160 |     }
 178 |  161 |     
 179 |  162 |     // MARK: - Helpers
 180 |  163 |     
 181 |  164 |     static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
 182 |  165 |         let image = NSImage(size: NSSize(width: width, height: height))
 183 |  166 |         image.lockFocus()
 184 |  167 |         NSColor.red.setFill()
 185 |  168 |         NSRect(x: 0, y: 0, width: width, height: height).fill()
 186 |  169 |         image.unlockFocus()
 187 |  170 |         return image
 188 |  171 |     }
 189 |  172 | }
 190 |  173 | 
 191 |  174 | // MARK: - Attachment Type (简化版，用于测试)
 192 |  175 | 
 193 |  176 | import UniformTypeIdentifiers
 194 |  177 | 
 195 |  178 | enum Attachment: Identifiable, Equatable {
 196 |  179 |     case image(NSImage, NSImage?, UUID)
 197 |  180 |     case screenshot(NSImage, NSImage?, UUID)
 198 |  181 |     case file(URL, UUID)
 199 |  182 |     case textBundle(String, String, Int, UUID)
 200 |  183 |     
 201 |  184 |     var id: UUID {
 202 |  185 |         switch self {
 203 |  186 |         case .image(_, _, let id), .screenshot(_, _, let id),
 204 |  187 |              .file(_, let id), .textBundle(_, _, _, let id):
 205 |  188 |             return id
 206 |  189 |         }
 207 |  190 |     }
 208 |  191 |     
 209 |  192 |     var thumbnail: NSImage? {
 210 |  193 |         switch self {
 211 |  194 |         case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
 212 |  195 |         default: return nil
 213 |  196 |         }
 214 |  197 |     }
 215 |  198 |     
 216 |  199 |     var originalImage: NSImage? {
 217 |  200 |         switch self {
 218 |  201 |         case .image(let img, _, _), .screenshot(let img, _, _): return img
 219 |  202 |         default: return nil
 220 |  203 |         }
 221 |  204 |     }
 222 |  205 |     
 223 |  206 |     var fileName: String? {
 224 |  207 |         switch self {
 225 |  208 |         case .file(let url, _): return url.lastPathComponent
 226 |  209 |         case .textBundle(_, let source, _, _): return source
 227 |  210 |         default: return nil
 228 |  211 |         }
 229 |  212 |     }
 230 |  213 |     
 231 |  214 |     var displayTitle: String {
 232 |  215 |         switch self {
 233 |  216 |         case .image: return "图片"
 234 |  217 |         case .screenshot: return "截图"
 235 |  218 |         case .file(let url, _): return url.lastPathComponent
 236 |  219 |         case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
 237 |  220 |         }
 238 |  221 |     }
 239 |  222 |     
 240 |  223 |     var isVideo: Bool {
 241 |  224 |         if case .file(let url, _) = self,
 242 |  225 |            let uti = UTType(filenameExtension: url.pathExtension) {
 243 |  226 |             return uti.conforms(to: .movie) || uti.conforms(to: .video)
 244 |  227 |         }
 245 |  228 |         return false
 246 |  229 |     }
 247 |  230 |     
 248 |  231 |     var isTextBundle: Bool {
 249 |  232 |         if case .textBundle = self { return true }
 250 |  233 |         return false
 251 |  234 |     }
 252 |  235 |     
 253 |  236 |     var textContent: String? {
 254 |  237 |         if case .textBundle(let content, _, _, _) = self { return content }
 255 |  238 |         return nil
 256 |  239 |     }
 257 |  240 |     
 258 |  241 |     static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
 259 |  242 |     
 260 |  243 |     static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
 261 |  244 |         let size = image.size
 262 |  245 |         guard size.width > 0 && size.height > 0 else { return image }
 263 |  246 |         
 264 |  247 |         let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
 265 |  248 |         let newSize = NSSize(width: size.width * scale, height: size.height * scale)
 266 |  249 |         
 267 |  250 |         let thumbnail = NSImage(size: newSize)
 268 |  251 |         thumbnail.lockFocus()
 269 |  252 |         image.draw(in: NSRect(origin: .zero, size: newSize),
 270 |  253 |                    from: NSRect(origin: .zero, size: size),
 271 |  254 |                    operation: .copy, fraction: 1.0)
 272 |  255 |         thumbnail.unlockFocus()
 273 |  256 |         return thumbnail
 274 |  257 |     }
 275 |  258 | }
 276 |  259 | 
 277 |  260 | // MARK: - Assertion Helpers
 278 |  261 | 
 279 |  262 | struct TestError: Error, CustomStringConvertible {
 280 |  263 |     let message: String
 281 |  264 |     init(_ message: String) { self.message = message }
 282 |  265 |     var description: String { message }
 283 |  266 | }
 284 |  267 | 
 285 |  268 | func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
 286 |  269 |     if actual != expected {
 287 |  270 |         throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
 288 |  271 |     }
 289 |  272 | }
 290 |  273 | 
 291 |  274 | func assertTrue(_ condition: Bool, _ message: String) throws {
 292 |  275 |     if !condition { throw TestError(message) }
 293 |  276 | }
 294 |  277 | 
 295 |  278 | func assertFalse(_ condition: Bool, _ message: String) throws {
 296 |  279 |     if condition { throw TestError(message) }
 297 |  280 | }
 298 |  281 | 
 299 |  282 | func assertNil<T>(_ value: T?, _ message: String) throws {
 300 |  283 |     if value != nil { throw TestError("\(message) 应该是 nil") }
 301 |  284 | }
 302 |  285 | 
 303 |  286 | func assertNotNil<T>(_ value: T?, _ message: String) throws {
 304 |  287 |     if value == nil { throw TestError("\(message) 不应该是 nil") }
 305 |  288 | }
 306 |  289 | 
 307 |  290 | extension String {
 308 |  291 |     static func * (string: String, count: Int) -> String {
 309 |  292 |         String(repeating: string, count: count)
 310 |  293 |     }
 311 |  294 | }
 312 | 
 313 | ```
 314 | 
 315 | `spoke/Tests/EdgeTTSTests.swift`:
 316 | 
 317 | ```swift
 318 |    1 | import Foundation
 319 |    2 | import AVFoundation
 320 |    3 | 
 321 |    4 | // MARK: - Edge TTS 单元测试
 322 |    5 | 
 323 |    6 | @main
 324 |    7 | struct EdgeTTSTests {
 325 |    8 |     static func main() async {
 326 |    9 |         print("🧪 Edge TTS 单元测试")
 327 |   10 |         print("=" * 50)
 328 |   11 |         
 329 |   12 |         await testSynthesizeAndPlay()
 330 |   13 |     }
 331 |   14 |     
 332 |   15 |     /// 测试合成并播放
 333 |   16 |     static func testSynthesizeAndPlay() async {
 334 |   17 |         print("\n📝 测试: 合成并播放")
 335 |   18 |         
 336 |   19 |         let text = "你好，这是语音合成测试。"
 337 |   20 |         let voice = "zh-CN-XiaoxiaoNeural"
 338 |   21 |         
 339 |   22 |         do {
 340 |   23 |             // 1. 合成音频
 341 |   24 |             print("   正在合成...")
 342 |   25 |             let audioData = try await synthesize(text: text, voice: voice)
 343 |   26 |             print("   ✅ 合成完成: \(audioData.count) bytes")
 344 |   27 |             
 345 |   28 |             // 2. 检查音频头
 346 |   29 |             print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
 347 |   30 |             
 348 |   31 |             // 3. 保存到文件测试
 349 |   32 |             let tempPath = "/tmp/edge_tts_test.mp3"
 350 |   33 |             try audioData.write(to: URL(fileURLWithPath: tempPath))
 351 |   34 |             print("   ✅ 已保存到: \(tempPath)")
 352 |   35 |             
 353 |   36 |             // 4. 用 AVAudioPlayer 播放
 354 |   37 |             print("   正在播放...")
 355 |   38 |             let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
 356 |   39 |             player.prepareToPlay()
 357 |   40 |             player.play()
 358 |   41 |             
 359 |   42 |             // 等待播放完成
 360 |   43 |             while player.isPlaying {
 361 |   44 |                 try await Task.sleep(nanoseconds: 100_000_000)
 362 |   45 |             }
 363 |   46 |             print("   ✅ 播放完成!")
 364 |   47 |             
 365 |   48 |         } catch {
 366 |   49 |             print("   ❌ 错误: \(error)")
 367 |   50 |         }
 368 |   51 |     }
 369 |   52 |     
 370 |   53 |     /// 合成音频
 371 |   54 |     static func synthesize(text: String, voice: String) async throws -> Data {
 372 |   55 |         // DRM Token
 373 |   56 |         let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
 374 |   57 |         let chromiumVersion = "130.0.2849.68"
 375 |   58 |         let windowsFileTimeEpoch: Int64 = 11_644_473_600
 376 |   59 |         
 377 |   60 |         let currentTime = Int64(Date().timeIntervalSince1970)
 378 |   61 |         let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
 379 |   62 |         let roundedTicks = ticks - (ticks % 3_000_000_000)
 380 |   63 |         let strToHash = "\(roundedTicks)\(trustedClientToken)"
 381 |   64 |         
 382 |   65 |         // SHA256
 383 |   66 |         import CryptoKit
 384 |   67 |         let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
 385 |   68 |         let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
 386 |   69 |         
 387 |   70 |         // URL
 388 |   71 |         let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
 389 |   72 |         let url = URL(string: urlString)!
 390 |   73 |         
 391 |   74 |         // WebSocket
 392 |   75 |         var request = URLRequest(url: url)
 393 |   76 |         request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
 394 |   77 |         request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
 395 |   78 |         
 396 |   79 |         let session = URLSession.shared
 397 |   80 |         let ws = session.webSocketTask(with: request)
 398 |   81 |         ws.resume()
 399 |   82 |         
 400 |   83 |         // 等待连接
 401 |   84 |         try await Task.sleep(nanoseconds: 500_000_000)
 402 |   85 |         
 403 |   86 |         // 发送配置
 404 |   87 |         let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
 405 |   88 |         try await ws.send(.string(configMessage))
 406 |   89 |         
 407 |   90 |         // 发送 SSML
 408 |   91 |         let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
 409 |   92 |         let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
 410 |   93 |         try await ws.send(.string(ssmlMessage))
 411 |   94 |         
 412 |   95 |         // 接收音频
 413 |   96 |         var audioData = Data()
 414 |   97 |         
 415 |   98 |         while true {
 416 |   99 |             let message = try await ws.receive()
 417 |  100 |             
 418 |  101 |             switch message {
 419 |  102 |             case .data(let data):
 420 |  103 |                 // 检查是否包含 Path:audio
 421 |  104 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 422 |  105 |                     if let range = str.range(of: "Path:audio\r\n") {
 423 |  106 |                         let offset = range.upperBound.utf16Offset(in: str)
 424 |  107 |                         audioData.append(data[offset...])
 425 |  108 |                     }
 426 |  109 |                 } else {
 427 |  110 |                     audioData.append(data)
 428 |  111 |                 }
 429 |  112 |                 
 430 |  113 |             case .string(let str):
 431 |  114 |                 if str.contains("Path:turn.end") {
 432 |  115 |                     ws.cancel(with: .goingAway, reason: nil)
 433 |  116 |                     return audioData
 434 |  117 |                 }
 435 |  118 |                 
 436 |  119 |             @unknown default:
 437 |  120 |                 break
 438 |  121 |             }
 439 |  122 |         }
 440 |  123 |     }
 441 |  124 | }
 442 |  125 | 
 443 |  126 | extension String {
 444 |  127 |     static func * (string: String, count: Int) -> String {
 445 |  128 |         String(repeating: string, count: count)
 446 |  129 |     }
 447 |  130 | }
 448 | 
 449 | ```
 450 | 
 451 | `spoke/Tests/TextExtractionTests.swift`:
 452 | 
 453 | ```swift
 454 |    1 | import Foundation
 455 |    2 | 
 456 |    3 | // MARK: - Text Extraction Service Tests
 457 |    4 | 
 458 |    5 | /// 独立运行的测试脚本
 459 |    6 | /// 用法: swift Tests/TextExtractionTests.swift
 460 |    7 | @main
 461 |    8 | struct TextExtractionTests {
 462 |    9 |     
 463 |   10 |     static var tempDirectory: URL!
 464 |   11 |     static var passCount = 0
 465 |   12 |     static var failCount = 0
 466 |   13 |     
 467 |   14 |     static func main() async {
 468 |   15 |         print("🧪 TextExtractionService 单元测试")
 469 |   16 |         print("=" * 50)
 470 |   17 |         
 471 |   18 |         // 创建临时目录
 472 |   19 |         tempDirectory = FileManager.default.temporaryDirectory
 473 |   20 |             .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
 474 |   21 |         try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 475 |   22 |         
 476 |   23 |         defer {
 477 |   24 |             // 清理
 478 |   25 |             try? FileManager.default.removeItem(at: tempDirectory)
 479 |   26 |             print("\n" + "=" * 50)
 480 |   27 |             print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
 481 |   28 |         }
 482 |   29 |         
 483 |   30 |         // 运行测试
 484 |   31 |         await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
 485 |   32 |         await runTest("单文件提取") { try await testSingleFileExtraction() }
 486 |   33 |         await runTest("多文件合并") { try await testMultipleFilesExtraction() }
 487 |   34 |         await runTest("排除 node_modules") { try await testExcludesNodeModules() }
 488 |   35 |         await runTest("排除锁文件") { try await testExcludesLockFiles() }
 489 |   36 |         await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
 490 |   37 |         await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
 491 |   38 |         await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
 492 |   39 |         await runTest("添加行号") { try await testAddsLineNumbers() }
 493 |   40 |         await runTest("目录结构输出") { try await testDirectoryStructure() }
 494 |   41 |         await runTest("ZIP 提取") { try await testZIPExtraction() }
 495 |   42 |     }
 496 |   43 |     
 497 |   44 |     // MARK: - Test Runner
 498 |   45 |     
 499 |   46 |     static func runTest(_ name: String, _ test: () async throws -> Void) async {
 500 |   47 |         print("\n📝 测试: \(name)")
 501 |   48 |         do {
 502 |   49 |             try await test()
 503 |   50 |             print("   ✅ 通过")
 504 |   51 |             passCount += 1
 505 |   52 |         } catch {
 506 |   53 |             print("   ❌ 失败: \(error)")
 507 |   54 |             failCount += 1
 508 |   55 |         }
 509 |   56 |     }
 510 |   57 |     
 511 |   58 |     // MARK: - Helpers
 512 |   59 |     
 513 |   60 |     static func createFile(name: String, content: String) throws -> URL {
 514 |   61 |         let fileURL = tempDirectory.appendingPathComponent(name)
 515 |   62 |         let dir = fileURL.deletingLastPathComponent()
 516 |   63 |         try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
 517 |   64 |         try content.write(to: fileURL, atomically: true, encoding: .utf8)
 518 |   65 |         return fileURL
 519 |   66 |     }
 520 |   67 |     
 521 |   68 |     static func createDirectory(name: String) throws -> URL {
 522 |   69 |         let dirURL = tempDirectory.appendingPathComponent(name)
 523 |   70 |         try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
 524 |   71 |         return dirURL
 525 |   72 |     }
 526 |   73 |     
 527 |   74 |     // MARK: - Test Cases
 528 |   75 |     
 529 |   76 |     static func testCodeExtensions() async throws {
 530 |   77 |         // 创建各种代码文件
 531 |   78 |         _ = try createFile(name: "test.swift", content: "let x = 1")
 532 |   79 |         _ = try createFile(name: "app.js", content: "const x = 1")
 533 |   80 |         _ = try createFile(name: "main.py", content: "x = 1")
 534 |   81 |         _ = try createFile(name: "README.md", content: "# Title")
 535 |   82 |         
 536 |   83 |         let result = await extractFromFolder(tempDirectory)
 537 |   84 |         guard case .success(let bundle) = result else {
 538 |   85 |             throw TestError("提取失败")
 539 |   86 |         }
 540 |   87 |         
 541 |   88 |         guard bundle.fileCount == 4 else {
 542 |   89 |             throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
 543 |   90 |         }
 544 |   91 |     }
 545 |   92 |     
 546 |   93 |     static func testSingleFileExtraction() async throws {
 547 |   94 |         // 清理并创建新目录
 548 |   95 |         try FileManager.default.removeItem(at: tempDirectory)
 549 |   96 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 550 |   97 |         
 551 |   98 |         _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
 552 |   99 |         
 553 |  100 |         let result = await extractFromFolder(tempDirectory)
 554 |  101 |         guard case .success(let bundle) = result else {
 555 |  102 |             throw TestError("提取失败")
 556 |  103 |         }
 557 |  104 |         
 558 |  105 |         guard bundle.fileCount == 1 else {
 559 |  106 |             throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
 560 |  107 |         }
 561 |  108 |         guard bundle.content.contains("print(\"Hello\")") else {
 562 |  109 |             throw TestError("内容不包含预期文本")
 563 |  110 |         }
 564 |  111 |     }
 565 |  112 |     
 566 |  113 |     static func testMultipleFilesExtraction() async throws {
 567 |  114 |         try FileManager.default.removeItem(at: tempDirectory)
 568 |  115 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 569 |  116 |         
 570 |  117 |         _ = try createFile(name: "a.swift", content: "let a = 1")
 571 |  118 |         _ = try createFile(name: "b.swift", content: "let b = 2")
 572 |  119 |         _ = try createFile(name: "c.js", content: "const c = 3")
 573 |  120 |         
 574 |  121 |         let result = await extractFromFolder(tempDirectory)
 575 |  122 |         guard case .success(let bundle) = result else {
 576 |  123 |             throw TestError("提取失败")
 577 |  124 |         }
 578 |  125 |         
 579 |  126 |         guard bundle.fileCount == 3 else {
 580 |  127 |             throw TestError("文件数量错误")
 581 |  128 |         }
 582 |  129 |         guard bundle.content.contains("let a = 1") &&
 583 |  130 |               bundle.content.contains("let b = 2") &&
 584 |  131 |               bundle.content.contains("const c = 3") else {
 585 |  132 |             throw TestError("内容缺失")
 586 |  133 |         }
 587 |  134 |     }
 588 |  135 |     
 589 |  136 |     static func testExcludesNodeModules() async throws {
 590 |  137 |         try FileManager.default.removeItem(at: tempDirectory)
 591 |  138 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 592 |  139 |         
 593 |  140 |         let nodeModules = try createDirectory(name: "node_modules")
 594 |  141 |         try "const secret = 'password'".write(
 595 |  142 |             to: nodeModules.appendingPathComponent("secret.js"),
 596 |  143 |             atomically: true, encoding: .utf8
 597 |  144 |         )
 598 |  145 |         _ = try createFile(name: "app.js", content: "const app = 1")
 599 |  146 |         
 600 |  147 |         let result = await extractFromFolder(tempDirectory)
 601 |  148 |         guard case .success(let bundle) = result else {
 602 |  149 |             throw TestError("提取失败")
 603 |  150 |         }
 604 |  151 |         
 605 |  152 |         guard bundle.fileCount == 1 else {
 606 |  153 |             throw TestError("应该只包含 app.js")
 607 |  154 |         }
 608 |  155 |         guard !bundle.content.contains("secret") else {
 609 |  156 |             throw TestError("不应包含 node_modules 内容")
 610 |  157 |         }
 611 |  158 |     }
 612 |  159 |     
 613 |  160 |     static func testExcludesLockFiles() async throws {
 614 |  161 |         try FileManager.default.removeItem(at: tempDirectory)
 615 |  162 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 616 |  163 |         
 617 |  164 |         _ = try createFile(name: "package-lock.json", content: "{}")
 618 |  165 |         _ = try createFile(name: "yarn.lock", content: "")
 619 |  166 |         _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
 620 |  167 |         
 621 |  168 |         let result = await extractFromFolder(tempDirectory)
 622 |  169 |         guard case .success(let bundle) = result else {
 623 |  170 |             throw TestError("提取失败")
 624 |  171 |         }
 625 |  172 |         
 626 |  173 |         guard bundle.fileCount == 1 else {
 627 |  174 |             throw TestError("应该只包含 package.json")
 628 |  175 |         }
 629 |  176 |     }
 630 |  177 |     
 631 |  178 |     static func testNestedDirectories() async throws {
 632 |  179 |         try FileManager.default.removeItem(at: tempDirectory)
 633 |  180 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 634 |  181 |         
 635 |  182 |         _ = try createFile(name: "root.swift", content: "let root = 1")
 636 |  183 |         _ = try createFile(name: "src/app.swift", content: "let src = 2")
 637 |  184 |         _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
 638 |  185 |         
 639 |  186 |         let result = await extractFromFolder(tempDirectory)
 640 |  187 |         guard case .success(let bundle) = result else {
 641 |  188 |             throw TestError("提取失败")
 642 |  189 |         }
 643 |  190 |         
 644 |  191 |         guard bundle.fileCount == 3 else {
 645 |  192 |             throw TestError("应该包含 3 个文件")
 646 |  193 |         }
 647 |  194 |         guard bundle.content.contains("let root = 1") &&
 648 |  195 |               bundle.content.contains("let src = 2") &&
 649 |  196 |               bundle.content.contains("let lib = 3") else {
 650 |  197 |             throw TestError("缺少嵌套目录内容")
 651 |  198 |         }
 652 |  199 |     }
 653 |  200 |     
 654 |  201 |     static func testEmptyFolderError() async throws {
 655 |  202 |         try FileManager.default.removeItem(at: tempDirectory)
 656 |  203 |         let emptyDir = try createDirectory(name: "empty")
 657 |  204 |         
 658 |  205 |         let result = await extractFromFolder(emptyDir)
 659 |  206 |         guard case .failure = result else {
 660 |  207 |             throw TestError("空文件夹应该返回错误")
 661 |  208 |         }
 662 |  209 |     }
 663 |  210 |     
 664 |  211 |     static func testIgnoresNonCodeFiles() async throws {
 665 |  212 |         try FileManager.default.removeItem(at: tempDirectory)
 666 |  213 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 667 |  214 |         
 668 |  215 |         _ = try createFile(name: "image.png", content: "fake")
 669 |  216 |         _ = try createFile(name: "video.mp4", content: "fake")
 670 |  217 |         _ = try createFile(name: "main.swift", content: "let x = 1")
 671 |  218 |         
 672 |  219 |         let result = await extractFromFolder(tempDirectory)
 673 |  220 |         guard case .success(let bundle) = result else {
 674 |  221 |             throw TestError("提取失败")
 675 |  222 |         }
 676 |  223 |         
 677 |  224 |         guard bundle.fileCount == 1 else {
 678 |  225 |             throw TestError("应该只包含 .swift 文件")
 679 |  226 |         }
 680 |  227 |     }
 681 |  228 |     
 682 |  229 |     static func testAddsLineNumbers() async throws {
 683 |  230 |         try FileManager.default.removeItem(at: tempDirectory)
 684 |  231 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 685 |  232 |         
 686 |  233 |         _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
 687 |  234 |         
 688 |  235 |         let result = await extractFromFolder(tempDirectory)
 689 |  236 |         guard case .success(let bundle) = result else {
 690 |  237 |             throw TestError("提取失败")
 691 |  238 |         }
 692 |  239 |         
 693 |  240 |         guard bundle.content.contains("1│") &&
 694 |  241 |               bundle.content.contains("2│") &&
 695 |  242 |               bundle.content.contains("3│") else {
 696 |  243 |             throw TestError("缺少行号")
 697 |  244 |         }
 698 |  245 |     }
 699 |  246 |     
 700 |  247 |     static func testDirectoryStructure() async throws {
 701 |  248 |         try FileManager.default.removeItem(at: tempDirectory)
 702 |  249 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 703 |  250 |         
 704 |  251 |         _ = try createFile(name: "main.swift", content: "entry")
 705 |  252 |         _ = try createFile(name: "src/app.swift", content: "code")
 706 |  253 |         
 707 |  254 |         let result = await extractFromFolder(tempDirectory)
 708 |  255 |         guard case .success(let bundle) = result else {
 709 |  256 |             throw TestError("提取失败")
 710 |  257 |         }
 711 |  258 |         
 712 |  259 |         guard bundle.content.contains("# 目录结构") else {
 713 |  260 |             throw TestError("缺少目录结构标题")
 714 |  261 |         }
 715 |  262 |     }
 716 |  263 |     
 717 |  264 |     static func testZIPExtraction() async throws {
 718 |  265 |         try FileManager.default.removeItem(at: tempDirectory)
 719 |  266 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 720 |  267 |         
 721 |  268 |         // 创建源文件
 722 |  269 |         let sourceDir = try createDirectory(name: "source")
 723 |  270 |         try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
 724 |  271 |         
 725 |  272 |         // 创建 ZIP
 726 |  273 |         let zipPath = tempDirectory.appendingPathComponent("test.zip")
 727 |  274 |         let process = Process()
 728 |  275 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
 729 |  276 |         process.currentDirectoryURL = tempDirectory
 730 |  277 |         process.arguments = ["-r", zipPath.path, "source"]
 731 |  278 |         process.standardOutput = FileHandle.nullDevice
 732 |  279 |         process.standardError = FileHandle.nullDevice
 733 |  280 |         try process.run()
 734 |  281 |         process.waitUntilExit()
 735 |  282 |         
 736 |  283 |         guard process.terminationStatus == 0 else {
 737 |  284 |             throw TestError("创建 ZIP 失败")
 738 |  285 |         }
 739 |  286 |         
 740 |  287 |         let result = await extractFromZIP(zipPath)
 741 |  288 |         guard case .success(let bundle) = result else {
 742 |  289 |             throw TestError("ZIP 提取失败")
 743 |  290 |         }
 744 |  291 |         
 745 |  292 |         guard bundle.fileCount == 1 else {
 746 |  293 |             throw TestError("ZIP 文件数量错误")
 747 |  294 |         }
 748 |  295 |         guard bundle.content.contains("let x = 1") else {
 749 |  296 |             throw TestError("ZIP 内容缺失")
 750 |  297 |         }
 751 |  298 |     }
 752 |  299 | }
 753 |  300 | 
 754 |  301 | // MARK: - TextExtractionService (简化版，用于测试)
 755 |  302 | 
 756 |  303 | struct TextBundle {
 757 |  304 |     let content: String
 758 |  305 |     let fileCount: Int
 759 |  306 |     let sourcePath: String
 760 |  307 |     let files: [String]
 761 |  308 | }
 762 |  309 | 
 763 |  310 | enum TextExtractionError: Error, Equatable {
 764 |  311 |     case folderNotFound
 765 |  312 |     case zipExtractionFailed(String)
 766 |  313 |     case noTextFilesFound
 767 |  314 |     case accessDenied
 768 |  315 | }
 769 |  316 | 
 770 |  317 | func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
 771 |  318 |     let codeExtensions: Set<String> = [
 772 |  319 |         "js", "jsx", "ts", "tsx", "mjs", "cjs",
 773 |  320 |         "html", "htm", "css", "scss", "less", "vue", "svelte",
 774 |  321 |         "py", "pyw", "pyi",
 775 |  322 |         "java", "kt", "kts", "scala",
 776 |  323 |         "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
 777 |  324 |         "rs", "go", "rb", "erb", "php", "swift",
 778 |  325 |         "sh", "bash", "zsh", "fish",
 779 |  326 |         "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
 780 |  327 |         "md", "mdx", "txt", "rst", "asciidoc",
 781 |  328 |         "sql", "graphql", "proto", "dockerfile"
 782 |  329 |     ]
 783 |  330 |     
 784 |  331 |     let excludedDirs: Set<String> = [
 785 |  332 |         "node_modules", ".git", ".svn", ".hg",
 786 |  333 |         "dist", "build", "target", ".next", ".nuxt",
 787 |  334 |         "__pycache__", ".pytest_cache", ".tox",
 788 |  335 |         "venv", "env", ".env", ".venv",
 789 |  336 |         "vendor", "Pods", "Carthage",
 790 |  337 |         ".idea", ".vscode", ".vs"
 791 |  338 |     ]
 792 |  339 |     
 793 |  340 |     let excludedFiles: Set<String> = [
 794 |  341 |         ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
 795 |  342 |         "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
 796 |  343 |         "Podfile.lock", "Gemfile.lock", "Cargo.lock"
 797 |  344 |     ]
 798 |  345 |     
 799 |  346 |     // 递归收集文件
 800 |  347 |     func collectFiles(in directory: URL) -> [URL] {
 801 |  348 |         var result: [URL] = []
 802 |  349 |         let fm = FileManager.default
 803 |  350 |         
 804 |  351 |         guard let contents = try? fm.contentsOfDirectory(
 805 |  352 |             at: directory,
 806 |  353 |             includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
 807 |  354 |             options: [.skipsHiddenFiles]
 808 |  355 |         ) else { return [] }
 809 |  356 |         
 810 |  357 |         for url in contents {
 811 |  358 |             let fileName = url.lastPathComponent
 812 |  359 |             if excludedFiles.contains(fileName) { continue }
 813 |  360 |             
 814 |  361 |             let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
 815 |  362 |             
 816 |  363 |             if values?.isDirectory == true {
 817 |  364 |                 if !excludedDirs.contains(fileName) {
 818 |  365 |                     result.append(contentsOf: collectFiles(in: url))
 819 |  366 |                 }
 820 |  367 |             } else if values?.isRegularFile == true {
 821 |  368 |                 let ext = url.pathExtension.lowercased()
 822 |  369 |                 if codeExtensions.contains(ext) {
 823 |  370 |                     result.append(url)
 824 |  371 |                 }
 825 |  372 |             }
 826 |  373 |         }
 827 |  374 |         return result.sorted { $0.path < $1.path }
 828 |  375 |     }
 829 |  376 |     
 830 |  377 |     let files = collectFiles(in: folderURL)
 831 |  378 |     guard !files.isEmpty else {
 832 |  379 |         return .failure(.noTextFilesFound)
 833 |  380 |     }
 834 |  381 |     
 835 |  382 |     // 合并内容
 836 |  383 |     var parts: [String] = ["# 目录结构\n```"]
 837 |  384 |     for file in files {
 838 |  385 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 839 |  386 |         parts.append(rel)
 840 |  387 |     }
 841 |  388 |     parts.append("```\n\n# 文件内容\n")
 842 |  389 |     
 843 |  390 |     for file in files {
 844 |  391 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 845 |  392 |         let ext = file.pathExtension
 846 |  393 |         if let content = try? String(contentsOf: file, encoding: .utf8) {
 847 |  394 |             let numbered = content.components(separatedBy: .newlines).enumerated()
 848 |  395 |                 .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
 849 |  396 |             parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
 850 |  397 |         }
 851 |  398 |     }
 852 |  399 |     
 853 |  400 |     return .success(TextBundle(
 854 |  401 |         content: parts.joined(separator: "\n"),
 855 |  402 |         fileCount: files.count,
 856 |  403 |         sourcePath: folderURL.path,
 857 |  404 |         files: files.map { $0.path }
 858 |  405 |     ))
 859 |  406 | }
 860 |  407 | 
 861 |  408 | func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
 862 |  409 |     let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
 863 |  410 |     try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
 864 |  411 |     defer { try? FileManager.default.removeItem(at: tempDir) }
 865 |  412 |     
 866 |  413 |     let process = Process()
 867 |  414 |     process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
 868 |  415 |     process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
 869 |  416 |     process.standardOutput = FileHandle.nullDevice
 870 |  417 |     process.standardError = FileHandle.nullDevice
 871 |  418 |     
 872 |  419 |     do {
 873 |  420 |         try process.run()
 874 |  421 |         process.waitUntilExit()
 875 |  422 |         
 876 |  423 |         guard process.terminationStatus == 0 else {
 877 |  424 |             return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
 878 |  425 |         }
 879 |  426 |         
 880 |  427 |         return await extractFromFolder(tempDir)
 881 |  428 |     } catch {
 882 |  429 |         return .failure(.zipExtractionFailed(error.localizedDescription))
 883 |  430 |     }
 884 |  431 | }
 885 |  432 | 
 886 |  433 | // MARK: - Helpers
 887 |  434 | 
 888 |  435 | struct TestError: Error, CustomStringConvertible {
 889 |  436 |     let message: String
 890 |  437 |     init(_ message: String) { self.message = message }
 891 |  438 |     var description: String { message }
 892 |  439 | }
 893 |  440 | 
 894 |  441 | extension String {
 895 |  442 |     static func * (string: String, count: Int) -> String {
 896 |  443 |         String(repeating: string, count: count)
 897 |  444 |     }
 898 |  445 | }
 899 | 
 900 | ```
 901 | 
 902 | `spoke/Tests/test_edge_tts.swift`:
 903 | 
 904 | ```swift
 905 |    1 | #!/usr/bin/env swift
 906 |    2 | 
 907 |    3 | import Foundation
 908 |    4 | import CryptoKit
 909 |    5 | import AVFoundation
 910 |    6 | 
 911 |    7 | // MARK: - Edge TTS 测试脚本
 912 |    8 | 
 913 |    9 | print("🧪 Edge TTS 测试")
 914 |   10 | print(String(repeating: "=", count: 50))
 915 |   11 | 
 916 |   12 | // 配置
 917 |   13 | let text = "你好，这是语音合成测试。Hello, this is a test."
 918 |   14 | let voice = "zh-CN-XiaoxiaoNeural"
 919 |   15 | let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
 920 |   16 | let chromiumVersion = "130.0.2849.68"
 921 |   17 | let windowsFileTimeEpoch: Int64 = 11_644_473_600
 922 |   18 | 
 923 |   19 | // 生成 DRM Token
 924 |   20 | func generateSecMsGecToken() -> String {
 925 |   21 |     let currentTime = Int64(Date().timeIntervalSince1970)
 926 |   22 |     let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
 927 |   23 |     let roundedTicks = ticks - (ticks % 3_000_000_000)
 928 |   24 |     let strToHash = "\(roundedTicks)\(trustedClientToken)"
 929 |   25 |     let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
 930 |   26 |     return hash.map { String(format: "%02X", $0) }.joined()
 931 |   27 | }
 932 |   28 | 
 933 |   29 | // WebSocket Delegate
 934 |   30 | class WSDelegate: NSObject, URLSessionWebSocketDelegate {
 935 |   31 |     var onOpen: (() -> Void)?
 936 |   32 |     
 937 |   33 |     func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
 938 |   34 |         print("   ✅ WebSocket 已连接")
 939 |   35 |         onOpen?()
 940 |   36 |     }
 941 |   37 | }
 942 |   38 | 
 943 |   39 | // 主测试
 944 |   40 | func runTest() async {
 945 |   41 |     print("\n📝 测试文本: \(text)")
 946 |   42 |     print("🎤 语音: \(voice)")
 947 |   43 |     
 948 |   44 |     // 构建 URL
 949 |   45 |     let secMsGec = generateSecMsGecToken()
 950 |   46 |     let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
 951 |   47 |     
 952 |   48 |     guard let url = URL(string: urlString) else {
 953 |   49 |         print("❌ URL 无效")
 954 |   50 |         return
 955 |   51 |     }
 956 |   52 |     
 957 |   53 |     // 创建 WebSocket
 958 |   54 |     print("\n🔗 正在连接...")
 959 |   55 |     var request = URLRequest(url: url)
 960 |   56 |     request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
 961 |   57 |     request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
 962 |   58 |     
 963 |   59 |     let delegate = WSDelegate()
 964 |   60 |     let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
 965 |   61 |     let ws = session.webSocketTask(with: request)
 966 |   62 |     
 967 |   63 |     // 等待连接
 968 |   64 |     await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
 969 |   65 |         delegate.onOpen = { cont.resume() }
 970 |   66 |         ws.resume()
 971 |   67 |     }
 972 |   68 |     
 973 |   69 |     // 发送配置
 974 |   70 |     print("📤 发送配置...")
 975 |   71 |     let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
 976 |   72 |     do {
 977 |   73 |         try await ws.send(.string(configMessage))
 978 |   74 |         print("   ✅ 配置已发送")
 979 |   75 |     } catch {
 980 |   76 |         print("   ❌ 发送配置失败: \(error)")
 981 |   77 |         return
 982 |   78 |     }
 983 |   79 |     
 984 |   80 |     // 发送 SSML
 985 |   81 |     print("📤 发送 SSML...")
 986 |   82 |     let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
 987 |   83 |     let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
 988 |   84 |     do {
 989 |   85 |         try await ws.send(.string(ssmlMessage))
 990 |   86 |         print("   ✅ SSML 已发送")
 991 |   87 |     } catch {
 992 |   88 |         print("   ❌ 发送 SSML 失败: \(error)")
 993 |   89 |         return
 994 |   90 |     }
 995 |   91 |     
 996 |   92 |     // 接收音频
 997 |   93 |     print("\n📥 接收音频数据...")
 998 |   94 |     var audioData = Data()
 999 |   95 |     var messageCount = 0
1000 |   96 |     
1001 |   97 |     while true {
1002 |   98 |         do {
1003 |   99 |             let message = try await ws.receive()
1004 |  100 |             messageCount += 1
1005 |  101 |             
1006 |  102 |             switch message {
1007 |  103 |             case .data(let data):
1008 |  104 |                 // 尝试解析为字符串查看内容
1009 |  105 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
1010 |  106 |                     // 找到音频分隔符后的数据
1011 |  107 |                     if let range = str.range(of: "Path:audio\r\n") {
1012 |  108 |                         let offset = range.upperBound.utf16Offset(in: str)
1013 |  109 |                         let audioChunk = data.suffix(from: offset)
1014 |  110 |                         audioData.append(audioChunk)
1015 |  111 |                         print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
1016 |  112 |                     }
1017 |  113 |                 } else {
1018 |  114 |                     // 纯二进制音频
1019 |  115 |                     audioData.append(data)
1020 |  116 |                     print("   收到音频块 #\(messageCount): \(data.count) bytes")
1021 |  117 |                 }
1022 |  118 |                 
1023 |  119 |             case .string(let str):
1024 |  120 |                 if str.contains("Path:turn.end") {
1025 |  121 |                     print("   ✅ 收到结束信号")
1026 |  122 |                     break
1027 |  123 |                 } else if str.contains("Path:audio.metadata") {
1028 |  124 |                     print("   收到元数据")
1029 |  125 |                 } else {
1030 |  126 |                     print("   收到文本: \(str.prefix(50))...")
1031 |  127 |                 }
1032 |  128 |                 continue
1033 |  129 |                 
1034 |  130 |             @unknown default:
1035 |  131 |                 continue
1036 |  132 |             }
1037 |  133 |             
1038 |  134 |             if messageCount > 100 { break } // 防止死循环
1039 |  135 |             
1040 |  136 |         } catch {
1041 |  137 |             print("   ⚠️ 接收错误: \(error)")
1042 |  138 |             break
1043 |  139 |         }
1044 |  140 |     }
1045 |  141 |     
1046 |  142 |     ws.cancel(with: .goingAway, reason: nil)
1047 |  143 |     
1048 |  144 |     print("\n📊 结果:")
1049 |  145 |     print("   总消息数: \(messageCount)")
1050 |  146 |     print("   音频大小: \(audioData.count) bytes")
1051 |  147 |     
1052 |  148 |     if audioData.isEmpty {
1053 |  149 |         print("   ❌ 没有收到音频数据")
1054 |  150 |         return
1055 |  151 |     }
1056 |  152 |     
1057 |  153 |     // 检查音频头
1058 |  154 |     let header = audioData.prefix(16)
1059 |  155 |     print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
1060 |  156 |     
1061 |  157 |     // MP3 文件应该以 FF FB 或 ID3 开头
1062 |  158 |     if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
1063 |  159 |         print("   ✅ 看起来是有效的 MP3 格式")
1064 |  160 |     } else {
1065 |  161 |         print("   ⚠️ 可能不是标准 MP3 格式")
1066 |  162 |     }
1067 |  163 |     
1068 |  164 |     // 保存到文件
1069 |  165 |     let tempPath = "/tmp/edge_tts_test.mp3"
1070 |  166 |     do {
1071 |  167 |         try audioData.write(to: URL(fileURLWithPath: tempPath))
1072 |  168 |         print("\n💾 已保存到: \(tempPath)")
1073 |  169 |     } catch {
1074 |  170 |         print("   ❌ 保存失败: \(error)")
1075 |  171 |         return
1076 |  172 |     }
1077 |  173 |     
1078 |  174 |     // 播放测试
1079 |  175 |     print("\n🔊 播放测试...")
1080 |  176 |     do {
1081 |  177 |         let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
1082 |  178 |         player.prepareToPlay()
1083 |  179 |         
1084 |  180 |         if player.play() {
1085 |  181 |             print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
1086 |  182 |             
1087 |  183 |             // 等待播放完成
1088 |  184 |             while player.isPlaying {
1089 |  185 |                 try await Task.sleep(nanoseconds: 100_000_000)
1090 |  186 |             }
1091 |  187 |             print("   ✅ 播放完成!")
1092 |  188 |         } else {
1093 |  189 |             print("   ❌ 播放启动失败")
1094 |  190 |         }
1095 |  191 |     } catch {
1096 |  192 |         print("   ❌ 播放错误: \(error)")
1097 |  193 |         
1098 |  194 |         // 尝试用 afplay 播放
1099 |  195 |         print("\n🔧 尝试用 afplay 播放...")
1100 |  196 |         let process = Process()
1101 |  197 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
1102 |  198 |         process.arguments = [tempPath]
1103 |  199 |         try? process.run()
1104 |  200 |         process.waitUntilExit()
1105 |  201 |         
1106 |  202 |         if process.terminationStatus == 0 {
1107 |  203 |             print("   ✅ afplay 播放成功!")
1108 |  204 |         } else {
1109 |  205 |             print("   ❌ afplay 也失败了")
1110 |  206 |         }
1111 |  207 |     }
1112 |  208 | }
1113 |  209 | 
1114 |  210 | // 运行测试
1115 |  211 | Task {
1116 |  212 |     await runTest()
1117 |  213 |     exit(0)
1118 |  214 | }
1119 |  215 | 
1120 |  216 | // 保持运行
1121 |  217 | RunLoop.main.run()
1122 | 
1123 | ```

```
```

`spoke/docs/code2prompt-output/lucid-source.md`:

```md
Project Path: spoke

Source Tree:

```txt
spoke
└── Tests
    ├── AttachmentTests.swift
    ├── EdgeTTSTests.swift
    ├── TextExtractionTests.swift
    └── test_edge_tts.swift

```

`spoke/Tests/AttachmentTests.swift`:

```swift
   1 | import Foundation
   2 | import AppKit
   3 | 
   4 | // MARK: - Attachment Tests
   5 | 
   6 | /// Attachment 类型单元测试
   7 | /// 用法: swiftc -parse-as-library -o /tmp/attachment_tests Tests/AttachmentTests.swift && /tmp/attachment_tests
   8 | @main
   9 | struct AttachmentTests {
  10 |     
  11 |     static var passCount = 0
  12 |     static var failCount = 0
  13 |     
  14 |     static func main() async {
  15 |         print("🧪 Attachment 类型单元测试")
  16 |         print("=" * 50)
  17 |         
  18 |         // 运行测试
  19 |         runTest("Image 类型属性") { try testImageAttachment() }
  20 |         runTest("Screenshot 类型属性") { try testScreenshotAttachment() }
  21 |         runTest("File 类型属性") { try testFileAttachment() }
  22 |         runTest("TextBundle 类型属性") { try testTextBundleAttachment() }
  23 |         runTest("视频文件检测") { try testVideoDetection() }
  24 |         runTest("ID 相等性判断") { try testEqualityById() }
  25 |         runTest("缩略图缩放大图") { try testThumbnailResizesLarge() }
  26 |         runTest("缩略图保持比例") { try testThumbnailPreservesRatio() }
  27 |         runTest("缩略图不放大小图") { try testThumbnailNoUpscale() }
  28 |         runTest("缩略图处理空图") { try testThumbnailZeroSize() }
  29 |         
  30 |         print("\n" + "=" * 50)
  31 |         print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  32 |     }
  33 |     
  34 |     // MARK: - Test Runner
  35 |     
  36 |     static func runTest(_ name: String, _ test: () throws -> Void) {
  37 |         print("\n📝 测试: \(name)")
  38 |         do {
  39 |             try test()
  40 |             print("   ✅ 通过")
  41 |             passCount += 1
  42 |         } catch {
  43 |             print("   ❌ 失败: \(error)")
  44 |             failCount += 1
  45 |         }
  46 |     }
  47 |     
  48 |     // MARK: - Test Cases: Attachment Types
  49 |     
  50 |     static func testImageAttachment() throws {
  51 |         let image = NSImage(size: NSSize(width: 100, height: 100))
  52 |         let thumbnail = NSImage(size: NSSize(width: 50, height: 50))
  53 |         let id = UUID()
  54 |         
  55 |         let attachment = Attachment.image(image, thumbnail, id)
  56 |         
  57 |         try assertEqual(attachment.id, id, "ID")
  58 |         try assertEqual(attachment.displayTitle, "图片", "displayTitle")
  59 |         try assertNotNil(attachment.thumbnail, "thumbnail")
  60 |         try assertNotNil(attachment.originalImage, "originalImage")
  61 |         try assertFalse(attachment.isVideo, "isVideo")
  62 |         try assertFalse(attachment.isTextBundle, "isTextBundle")
  63 |         try assertNil(attachment.textContent, "textContent")
  64 |     }
  65 |     
  66 |     static func testScreenshotAttachment() throws {
  67 |         let image = NSImage(size: NSSize(width: 1920, height: 1080))
  68 |         let id = UUID()
  69 |         
  70 |         let attachment = Attachment.screenshot(image, nil, id)
  71 |         
  72 |         try assertEqual(attachment.id, id, "ID")
  73 |         try assertEqual(attachment.displayTitle, "截图", "displayTitle")
  74 |         try assertNil(attachment.thumbnail, "thumbnail (should be nil)")
  75 |         try assertNotNil(attachment.originalImage, "originalImage")
  76 |     }
  77 |     
  78 |     static func testFileAttachment() throws {
  79 |         let url = URL(fileURLWithPath: "/tmp/test.pdf")
  80 |         let id = UUID()
  81 |         
  82 |         let attachment = Attachment.file(url, id)
  83 |         
  84 |         try assertEqual(attachment.id, id, "ID")
  85 |         try assertEqual(attachment.displayTitle, "test.pdf", "displayTitle")
  86 |         try assertEqual(attachment.fileName, "test.pdf", "fileName")
  87 |         try assertNil(attachment.thumbnail, "thumbnail")
  88 |         try assertNil(attachment.originalImage, "originalImage")
  89 |     }
  90 |     
  91 |     static func testTextBundleAttachment() throws {
  92 |         let content = "# Code content\nlet x = 1"
  93 |         let source = "my-project"
  94 |         let count = 42
  95 |         let id = UUID()
  96 |         
  97 |         let attachment = Attachment.textBundle(content, source, count, id)
  98 |         
  99 |         try assertEqual(attachment.id, id, "ID")
 100 |         try assertEqual(attachment.displayTitle, "my-project (42 文件)", "displayTitle")
 101 |         try assertEqual(attachment.fileName, source, "fileName")
 102 |         try assertTrue(attachment.isTextBundle, "isTextBundle")
 103 |         try assertEqual(attachment.textContent, content, "textContent")
 104 |     }
 105 |     
 106 |     static func testVideoDetection() throws {
 107 |         let mp4 = Attachment.file(URL(fileURLWithPath: "/tmp/video.mp4"), UUID())
 108 |         let mov = Attachment.file(URL(fileURLWithPath: "/tmp/video.mov"), UUID())
 109 |         let txt = Attachment.file(URL(fileURLWithPath: "/tmp/text.txt"), UUID())
 110 |         
 111 |         try assertTrue(mp4.isVideo, "mp4 should be video")
 112 |         try assertTrue(mov.isVideo, "mov should be video")
 113 |         try assertFalse(txt.isVideo, "txt should not be video")
 114 |     }
 115 |     
 116 |     static func testEqualityById() throws {
 117 |         let id = UUID()
 118 |         let image1 = NSImage(size: NSSize(width: 100, height: 100))
 119 |         let image2 = NSImage(size: NSSize(width: 200, height: 200))
 120 |         
 121 |         let att1 = Attachment.image(image1, nil, id)
 122 |         let att2 = Attachment.image(image2, nil, id)
 123 |         let att3 = Attachment.image(image1, nil, UUID())
 124 |         
 125 |         try assertTrue(att1 == att2, "Same ID should be equal")
 126 |         try assertFalse(att1 == att3, "Different ID should not be equal")
 127 |     }
 128 |     
 129 |     // MARK: - Test Cases: Thumbnail Generation
 130 |     
 131 |     static func testThumbnailResizesLarge() throws {
 132 |         let large = createTestImage(width: 2000, height: 1000)
 133 |         let thumb = Attachment.makeThumbnail(from: large, maxSize: 256)
 134 |         
 135 |         try assertTrue(thumb.size.width <= 256, "Width should be <= 256")
 136 |         try assertTrue(thumb.size.height <= 256, "Height should be <= 256")
 137 |     }
 138 |     
 139 |     static func testThumbnailPreservesRatio() throws {
 140 |         let image = createTestImage(width: 2000, height: 1000)
 141 |         let thumb = Attachment.makeThumbnail(from: image, maxSize: 256)
 142 |         
 143 |         let ratio = thumb.size.width / thumb.size.height
 144 |         try assertTrue(abs(ratio - 2.0) < 0.01, "Ratio should be 2:1, got \(ratio)")
 145 |     }
 146 |     
 147 |     static func testThumbnailNoUpscale() throws {
 148 |         let small = createTestImage(width: 50, height: 50)
 149 |         let thumb = Attachment.makeThumbnail(from: small, maxSize: 256)
 150 |         
 151 |         try assertEqual(thumb.size.width, 50, "Width")
 152 |         try assertEqual(thumb.size.height, 50, "Height")
 153 |     }
 154 |     
 155 |     static func testThumbnailZeroSize() throws {
 156 |         let zero = NSImage(size: NSSize(width: 0, height: 0))
 157 |         let thumb = Attachment.makeThumbnail(from: zero, maxSize: 256)
 158 |         
 159 |         try assertEqual(thumb.size.width, 0, "Width")
 160 |     }
 161 |     
 162 |     // MARK: - Helpers
 163 |     
 164 |     static func createTestImage(width: CGFloat, height: CGFloat) -> NSImage {
 165 |         let image = NSImage(size: NSSize(width: width, height: height))
 166 |         image.lockFocus()
 167 |         NSColor.red.setFill()
 168 |         NSRect(x: 0, y: 0, width: width, height: height).fill()
 169 |         image.unlockFocus()
 170 |         return image
 171 |     }
 172 | }
 173 | 
 174 | // MARK: - Attachment Type (简化版，用于测试)
 175 | 
 176 | import UniformTypeIdentifiers
 177 | 
 178 | enum Attachment: Identifiable, Equatable {
 179 |     case image(NSImage, NSImage?, UUID)
 180 |     case screenshot(NSImage, NSImage?, UUID)
 181 |     case file(URL, UUID)
 182 |     case textBundle(String, String, Int, UUID)
 183 |     
 184 |     var id: UUID {
 185 |         switch self {
 186 |         case .image(_, _, let id), .screenshot(_, _, let id),
 187 |              .file(_, let id), .textBundle(_, _, _, let id):
 188 |             return id
 189 |         }
 190 |     }
 191 |     
 192 |     var thumbnail: NSImage? {
 193 |         switch self {
 194 |         case .image(_, let thumb, _), .screenshot(_, let thumb, _): return thumb
 195 |         default: return nil
 196 |         }
 197 |     }
 198 |     
 199 |     var originalImage: NSImage? {
 200 |         switch self {
 201 |         case .image(let img, _, _), .screenshot(let img, _, _): return img
 202 |         default: return nil
 203 |         }
 204 |     }
 205 |     
 206 |     var fileName: String? {
 207 |         switch self {
 208 |         case .file(let url, _): return url.lastPathComponent
 209 |         case .textBundle(_, let source, _, _): return source
 210 |         default: return nil
 211 |         }
 212 |     }
 213 |     
 214 |     var displayTitle: String {
 215 |         switch self {
 216 |         case .image: return "图片"
 217 |         case .screenshot: return "截图"
 218 |         case .file(let url, _): return url.lastPathComponent
 219 |         case .textBundle(_, let source, let count, _): return "\(source) (\(count) 文件)"
 220 |         }
 221 |     }
 222 |     
 223 |     var isVideo: Bool {
 224 |         if case .file(let url, _) = self,
 225 |            let uti = UTType(filenameExtension: url.pathExtension) {
 226 |             return uti.conforms(to: .movie) || uti.conforms(to: .video)
 227 |         }
 228 |         return false
 229 |     }
 230 |     
 231 |     var isTextBundle: Bool {
 232 |         if case .textBundle = self { return true }
 233 |         return false
 234 |     }
 235 |     
 236 |     var textContent: String? {
 237 |         if case .textBundle(let content, _, _, _) = self { return content }
 238 |         return nil
 239 |     }
 240 |     
 241 |     static func == (lhs: Attachment, rhs: Attachment) -> Bool { lhs.id == rhs.id }
 242 |     
 243 |     static func makeThumbnail(from image: NSImage, maxSize: CGFloat = 256) -> NSImage {
 244 |         let size = image.size
 245 |         guard size.width > 0 && size.height > 0 else { return image }
 246 |         
 247 |         let scale = min(maxSize / size.width, maxSize / size.height, 1.0)
 248 |         let newSize = NSSize(width: size.width * scale, height: size.height * scale)
 249 |         
 250 |         let thumbnail = NSImage(size: newSize)
 251 |         thumbnail.lockFocus()
 252 |         image.draw(in: NSRect(origin: .zero, size: newSize),
 253 |                    from: NSRect(origin: .zero, size: size),
 254 |                    operation: .copy, fraction: 1.0)
 255 |         thumbnail.unlockFocus()
 256 |         return thumbnail
 257 |     }
 258 | }
 259 | 
 260 | // MARK: - Assertion Helpers
 261 | 
 262 | struct TestError: Error, CustomStringConvertible {
 263 |     let message: String
 264 |     init(_ message: String) { self.message = message }
 265 |     var description: String { message }
 266 | }
 267 | 
 268 | func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) throws {
 269 |     if actual != expected {
 270 |         throw TestError("\(name): 期望 \(expected), 实际 \(actual)")
 271 |     }
 272 | }
 273 | 
 274 | func assertTrue(_ condition: Bool, _ message: String) throws {
 275 |     if !condition { throw TestError(message) }
 276 | }
 277 | 
 278 | func assertFalse(_ condition: Bool, _ message: String) throws {
 279 |     if condition { throw TestError(message) }
 280 | }
 281 | 
 282 | func assertNil<T>(_ value: T?, _ message: String) throws {
 283 |     if value != nil { throw TestError("\(message) 应该是 nil") }
 284 | }
 285 | 
 286 | func assertNotNil<T>(_ value: T?, _ message: String) throws {
 287 |     if value == nil { throw TestError("\(message) 不应该是 nil") }
 288 | }
 289 | 
 290 | extension String {
 291 |     static func * (string: String, count: Int) -> String {
 292 |         String(repeating: string, count: count)
 293 |     }
 294 | }

```

`spoke/Tests/EdgeTTSTests.swift`:

```swift
   1 | import Foundation
   2 | import AVFoundation
   3 | 
   4 | // MARK: - Edge TTS 单元测试
   5 | 
   6 | @main
   7 | struct EdgeTTSTests {
   8 |     static func main() async {
   9 |         print("🧪 Edge TTS 单元测试")
  10 |         print("=" * 50)
  11 |         
  12 |         await testSynthesizeAndPlay()
  13 |     }
  14 |     
  15 |     /// 测试合成并播放
  16 |     static func testSynthesizeAndPlay() async {
  17 |         print("\n📝 测试: 合成并播放")
  18 |         
  19 |         let text = "你好，这是语音合成测试。"
  20 |         let voice = "zh-CN-XiaoxiaoNeural"
  21 |         
  22 |         do {
  23 |             // 1. 合成音频
  24 |             print("   正在合成...")
  25 |             let audioData = try await synthesize(text: text, voice: voice)
  26 |             print("   ✅ 合成完成: \(audioData.count) bytes")
  27 |             
  28 |             // 2. 检查音频头
  29 |             print("   音频头部: \(audioData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))")
  30 |             
  31 |             // 3. 保存到文件测试
  32 |             let tempPath = "/tmp/edge_tts_test.mp3"
  33 |             try audioData.write(to: URL(fileURLWithPath: tempPath))
  34 |             print("   ✅ 已保存到: \(tempPath)")
  35 |             
  36 |             // 4. 用 AVAudioPlayer 播放
  37 |             print("   正在播放...")
  38 |             let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
  39 |             player.prepareToPlay()
  40 |             player.play()
  41 |             
  42 |             // 等待播放完成
  43 |             while player.isPlaying {
  44 |                 try await Task.sleep(nanoseconds: 100_000_000)
  45 |             }
  46 |             print("   ✅ 播放完成!")
  47 |             
  48 |         } catch {
  49 |             print("   ❌ 错误: \(error)")
  50 |         }
  51 |     }
  52 |     
  53 |     /// 合成音频
  54 |     static func synthesize(text: String, voice: String) async throws -> Data {
  55 |         // DRM Token
  56 |         let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
  57 |         let chromiumVersion = "130.0.2849.68"
  58 |         let windowsFileTimeEpoch: Int64 = 11_644_473_600
  59 |         
  60 |         let currentTime = Int64(Date().timeIntervalSince1970)
  61 |         let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
  62 |         let roundedTicks = ticks - (ticks % 3_000_000_000)
  63 |         let strToHash = "\(roundedTicks)\(trustedClientToken)"
  64 |         
  65 |         // SHA256
  66 |         import CryptoKit
  67 |         let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
  68 |         let secMsGec = hash.map { String(format: "%02X", $0) }.joined()
  69 |         
  70 |         // URL
  71 |         let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
  72 |         let url = URL(string: urlString)!
  73 |         
  74 |         // WebSocket
  75 |         var request = URLRequest(url: url)
  76 |         request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
  77 |         request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
  78 |         
  79 |         let session = URLSession.shared
  80 |         let ws = session.webSocketTask(with: request)
  81 |         ws.resume()
  82 |         
  83 |         // 等待连接
  84 |         try await Task.sleep(nanoseconds: 500_000_000)
  85 |         
  86 |         // 发送配置
  87 |         let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
  88 |         try await ws.send(.string(configMessage))
  89 |         
  90 |         // 发送 SSML
  91 |         let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
  92 |         let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
  93 |         try await ws.send(.string(ssmlMessage))
  94 |         
  95 |         // 接收音频
  96 |         var audioData = Data()
  97 |         
  98 |         while true {
  99 |             let message = try await ws.receive()
 100 |             
 101 |             switch message {
 102 |             case .data(let data):
 103 |                 // 检查是否包含 Path:audio
 104 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 105 |                     if let range = str.range(of: "Path:audio\r\n") {
 106 |                         let offset = range.upperBound.utf16Offset(in: str)
 107 |                         audioData.append(data[offset...])
 108 |                     }
 109 |                 } else {
 110 |                     audioData.append(data)
 111 |                 }
 112 |                 
 113 |             case .string(let str):
 114 |                 if str.contains("Path:turn.end") {
 115 |                     ws.cancel(with: .goingAway, reason: nil)
 116 |                     return audioData
 117 |                 }
 118 |                 
 119 |             @unknown default:
 120 |                 break
 121 |             }
 122 |         }
 123 |     }
 124 | }
 125 | 
 126 | extension String {
 127 |     static func * (string: String, count: Int) -> String {
 128 |         String(repeating: string, count: count)
 129 |     }
 130 | }

```

`spoke/Tests/TextExtractionTests.swift`:

```swift
   1 | import Foundation
   2 | 
   3 | // MARK: - Text Extraction Service Tests
   4 | 
   5 | /// 独立运行的测试脚本
   6 | /// 用法: swift Tests/TextExtractionTests.swift
   7 | @main
   8 | struct TextExtractionTests {
   9 |     
  10 |     static var tempDirectory: URL!
  11 |     static var passCount = 0
  12 |     static var failCount = 0
  13 |     
  14 |     static func main() async {
  15 |         print("🧪 TextExtractionService 单元测试")
  16 |         print("=" * 50)
  17 |         
  18 |         // 创建临时目录
  19 |         tempDirectory = FileManager.default.temporaryDirectory
  20 |             .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
  21 |         try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  22 |         
  23 |         defer {
  24 |             // 清理
  25 |             try? FileManager.default.removeItem(at: tempDirectory)
  26 |             print("\n" + "=" * 50)
  27 |             print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
  28 |         }
  29 |         
  30 |         // 运行测试
  31 |         await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
  32 |         await runTest("单文件提取") { try await testSingleFileExtraction() }
  33 |         await runTest("多文件合并") { try await testMultipleFilesExtraction() }
  34 |         await runTest("排除 node_modules") { try await testExcludesNodeModules() }
  35 |         await runTest("排除锁文件") { try await testExcludesLockFiles() }
  36 |         await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
  37 |         await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
  38 |         await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
  39 |         await runTest("添加行号") { try await testAddsLineNumbers() }
  40 |         await runTest("目录结构输出") { try await testDirectoryStructure() }
  41 |         await runTest("ZIP 提取") { try await testZIPExtraction() }
  42 |     }
  43 |     
  44 |     // MARK: - Test Runner
  45 |     
  46 |     static func runTest(_ name: String, _ test: () async throws -> Void) async {
  47 |         print("\n📝 测试: \(name)")
  48 |         do {
  49 |             try await test()
  50 |             print("   ✅ 通过")
  51 |             passCount += 1
  52 |         } catch {
  53 |             print("   ❌ 失败: \(error)")
  54 |             failCount += 1
  55 |         }
  56 |     }
  57 |     
  58 |     // MARK: - Helpers
  59 |     
  60 |     static func createFile(name: String, content: String) throws -> URL {
  61 |         let fileURL = tempDirectory.appendingPathComponent(name)
  62 |         let dir = fileURL.deletingLastPathComponent()
  63 |         try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  64 |         try content.write(to: fileURL, atomically: true, encoding: .utf8)
  65 |         return fileURL
  66 |     }
  67 |     
  68 |     static func createDirectory(name: String) throws -> URL {
  69 |         let dirURL = tempDirectory.appendingPathComponent(name)
  70 |         try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
  71 |         return dirURL
  72 |     }
  73 |     
  74 |     // MARK: - Test Cases
  75 |     
  76 |     static func testCodeExtensions() async throws {
  77 |         // 创建各种代码文件
  78 |         _ = try createFile(name: "test.swift", content: "let x = 1")
  79 |         _ = try createFile(name: "app.js", content: "const x = 1")
  80 |         _ = try createFile(name: "main.py", content: "x = 1")
  81 |         _ = try createFile(name: "README.md", content: "# Title")
  82 |         
  83 |         let result = await extractFromFolder(tempDirectory)
  84 |         guard case .success(let bundle) = result else {
  85 |             throw TestError("提取失败")
  86 |         }
  87 |         
  88 |         guard bundle.fileCount == 4 else {
  89 |             throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
  90 |         }
  91 |     }
  92 |     
  93 |     static func testSingleFileExtraction() async throws {
  94 |         // 清理并创建新目录
  95 |         try FileManager.default.removeItem(at: tempDirectory)
  96 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
  97 |         
  98 |         _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
  99 |         
 100 |         let result = await extractFromFolder(tempDirectory)
 101 |         guard case .success(let bundle) = result else {
 102 |             throw TestError("提取失败")
 103 |         }
 104 |         
 105 |         guard bundle.fileCount == 1 else {
 106 |             throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
 107 |         }
 108 |         guard bundle.content.contains("print(\"Hello\")") else {
 109 |             throw TestError("内容不包含预期文本")
 110 |         }
 111 |     }
 112 |     
 113 |     static func testMultipleFilesExtraction() async throws {
 114 |         try FileManager.default.removeItem(at: tempDirectory)
 115 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 116 |         
 117 |         _ = try createFile(name: "a.swift", content: "let a = 1")
 118 |         _ = try createFile(name: "b.swift", content: "let b = 2")
 119 |         _ = try createFile(name: "c.js", content: "const c = 3")
 120 |         
 121 |         let result = await extractFromFolder(tempDirectory)
 122 |         guard case .success(let bundle) = result else {
 123 |             throw TestError("提取失败")
 124 |         }
 125 |         
 126 |         guard bundle.fileCount == 3 else {
 127 |             throw TestError("文件数量错误")
 128 |         }
 129 |         guard bundle.content.contains("let a = 1") &&
 130 |               bundle.content.contains("let b = 2") &&
 131 |               bundle.content.contains("const c = 3") else {
 132 |             throw TestError("内容缺失")
 133 |         }
 134 |     }
 135 |     
 136 |     static func testExcludesNodeModules() async throws {
 137 |         try FileManager.default.removeItem(at: tempDirectory)
 138 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 139 |         
 140 |         let nodeModules = try createDirectory(name: "node_modules")
 141 |         try "const secret = 'password'".write(
 142 |             to: nodeModules.appendingPathComponent("secret.js"),
 143 |             atomically: true, encoding: .utf8
 144 |         )
 145 |         _ = try createFile(name: "app.js", content: "const app = 1")
 146 |         
 147 |         let result = await extractFromFolder(tempDirectory)
 148 |         guard case .success(let bundle) = result else {
 149 |             throw TestError("提取失败")
 150 |         }
 151 |         
 152 |         guard bundle.fileCount == 1 else {
 153 |             throw TestError("应该只包含 app.js")
 154 |         }
 155 |         guard !bundle.content.contains("secret") else {
 156 |             throw TestError("不应包含 node_modules 内容")
 157 |         }
 158 |     }
 159 |     
 160 |     static func testExcludesLockFiles() async throws {
 161 |         try FileManager.default.removeItem(at: tempDirectory)
 162 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 163 |         
 164 |         _ = try createFile(name: "package-lock.json", content: "{}")
 165 |         _ = try createFile(name: "yarn.lock", content: "")
 166 |         _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
 167 |         
 168 |         let result = await extractFromFolder(tempDirectory)
 169 |         guard case .success(let bundle) = result else {
 170 |             throw TestError("提取失败")
 171 |         }
 172 |         
 173 |         guard bundle.fileCount == 1 else {
 174 |             throw TestError("应该只包含 package.json")
 175 |         }
 176 |     }
 177 |     
 178 |     static func testNestedDirectories() async throws {
 179 |         try FileManager.default.removeItem(at: tempDirectory)
 180 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 181 |         
 182 |         _ = try createFile(name: "root.swift", content: "let root = 1")
 183 |         _ = try createFile(name: "src/app.swift", content: "let src = 2")
 184 |         _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
 185 |         
 186 |         let result = await extractFromFolder(tempDirectory)
 187 |         guard case .success(let bundle) = result else {
 188 |             throw TestError("提取失败")
 189 |         }
 190 |         
 191 |         guard bundle.fileCount == 3 else {
 192 |             throw TestError("应该包含 3 个文件")
 193 |         }
 194 |         guard bundle.content.contains("let root = 1") &&
 195 |               bundle.content.contains("let src = 2") &&
 196 |               bundle.content.contains("let lib = 3") else {
 197 |             throw TestError("缺少嵌套目录内容")
 198 |         }
 199 |     }
 200 |     
 201 |     static func testEmptyFolderError() async throws {
 202 |         try FileManager.default.removeItem(at: tempDirectory)
 203 |         let emptyDir = try createDirectory(name: "empty")
 204 |         
 205 |         let result = await extractFromFolder(emptyDir)
 206 |         guard case .failure = result else {
 207 |             throw TestError("空文件夹应该返回错误")
 208 |         }
 209 |     }
 210 |     
 211 |     static func testIgnoresNonCodeFiles() async throws {
 212 |         try FileManager.default.removeItem(at: tempDirectory)
 213 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 214 |         
 215 |         _ = try createFile(name: "image.png", content: "fake")
 216 |         _ = try createFile(name: "video.mp4", content: "fake")
 217 |         _ = try createFile(name: "main.swift", content: "let x = 1")
 218 |         
 219 |         let result = await extractFromFolder(tempDirectory)
 220 |         guard case .success(let bundle) = result else {
 221 |             throw TestError("提取失败")
 222 |         }
 223 |         
 224 |         guard bundle.fileCount == 1 else {
 225 |             throw TestError("应该只包含 .swift 文件")
 226 |         }
 227 |     }
 228 |     
 229 |     static func testAddsLineNumbers() async throws {
 230 |         try FileManager.default.removeItem(at: tempDirectory)
 231 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 232 |         
 233 |         _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
 234 |         
 235 |         let result = await extractFromFolder(tempDirectory)
 236 |         guard case .success(let bundle) = result else {
 237 |             throw TestError("提取失败")
 238 |         }
 239 |         
 240 |         guard bundle.content.contains("1│") &&
 241 |               bundle.content.contains("2│") &&
 242 |               bundle.content.contains("3│") else {
 243 |             throw TestError("缺少行号")
 244 |         }
 245 |     }
 246 |     
 247 |     static func testDirectoryStructure() async throws {
 248 |         try FileManager.default.removeItem(at: tempDirectory)
 249 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 250 |         
 251 |         _ = try createFile(name: "main.swift", content: "entry")
 252 |         _ = try createFile(name: "src/app.swift", content: "code")
 253 |         
 254 |         let result = await extractFromFolder(tempDirectory)
 255 |         guard case .success(let bundle) = result else {
 256 |             throw TestError("提取失败")
 257 |         }
 258 |         
 259 |         guard bundle.content.contains("# 目录结构") else {
 260 |             throw TestError("缺少目录结构标题")
 261 |         }
 262 |     }
 263 |     
 264 |     static func testZIPExtraction() async throws {
 265 |         try FileManager.default.removeItem(at: tempDirectory)
 266 |         try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
 267 |         
 268 |         // 创建源文件
 269 |         let sourceDir = try createDirectory(name: "source")
 270 |         try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
 271 |         
 272 |         // 创建 ZIP
 273 |         let zipPath = tempDirectory.appendingPathComponent("test.zip")
 274 |         let process = Process()
 275 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
 276 |         process.currentDirectoryURL = tempDirectory
 277 |         process.arguments = ["-r", zipPath.path, "source"]
 278 |         process.standardOutput = FileHandle.nullDevice
 279 |         process.standardError = FileHandle.nullDevice
 280 |         try process.run()
 281 |         process.waitUntilExit()
 282 |         
 283 |         guard process.terminationStatus == 0 else {
 284 |             throw TestError("创建 ZIP 失败")
 285 |         }
 286 |         
 287 |         let result = await extractFromZIP(zipPath)
 288 |         guard case .success(let bundle) = result else {
 289 |             throw TestError("ZIP 提取失败")
 290 |         }
 291 |         
 292 |         guard bundle.fileCount == 1 else {
 293 |             throw TestError("ZIP 文件数量错误")
 294 |         }
 295 |         guard bundle.content.contains("let x = 1") else {
 296 |             throw TestError("ZIP 内容缺失")
 297 |         }
 298 |     }
 299 | }
 300 | 
 301 | // MARK: - TextExtractionService (简化版，用于测试)
 302 | 
 303 | struct TextBundle {
 304 |     let content: String
 305 |     let fileCount: Int
 306 |     let sourcePath: String
 307 |     let files: [String]
 308 | }
 309 | 
 310 | enum TextExtractionError: Error, Equatable {
 311 |     case folderNotFound
 312 |     case zipExtractionFailed(String)
 313 |     case noTextFilesFound
 314 |     case accessDenied
 315 | }
 316 | 
 317 | func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
 318 |     let codeExtensions: Set<String> = [
 319 |         "js", "jsx", "ts", "tsx", "mjs", "cjs",
 320 |         "html", "htm", "css", "scss", "less", "vue", "svelte",
 321 |         "py", "pyw", "pyi",
 322 |         "java", "kt", "kts", "scala",
 323 |         "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
 324 |         "rs", "go", "rb", "erb", "php", "swift",
 325 |         "sh", "bash", "zsh", "fish",
 326 |         "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
 327 |         "md", "mdx", "txt", "rst", "asciidoc",
 328 |         "sql", "graphql", "proto", "dockerfile"
 329 |     ]
 330 |     
 331 |     let excludedDirs: Set<String> = [
 332 |         "node_modules", ".git", ".svn", ".hg",
 333 |         "dist", "build", "target", ".next", ".nuxt",
 334 |         "__pycache__", ".pytest_cache", ".tox",
 335 |         "venv", "env", ".env", ".venv",
 336 |         "vendor", "Pods", "Carthage",
 337 |         ".idea", ".vscode", ".vs"
 338 |     ]
 339 |     
 340 |     let excludedFiles: Set<String> = [
 341 |         ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
 342 |         "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
 343 |         "Podfile.lock", "Gemfile.lock", "Cargo.lock"
 344 |     ]
 345 |     
 346 |     // 递归收集文件
 347 |     func collectFiles(in directory: URL) -> [URL] {
 348 |         var result: [URL] = []
 349 |         let fm = FileManager.default
 350 |         
 351 |         guard let contents = try? fm.contentsOfDirectory(
 352 |             at: directory,
 353 |             includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
 354 |             options: [.skipsHiddenFiles]
 355 |         ) else { return [] }
 356 |         
 357 |         for url in contents {
 358 |             let fileName = url.lastPathComponent
 359 |             if excludedFiles.contains(fileName) { continue }
 360 |             
 361 |             let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
 362 |             
 363 |             if values?.isDirectory == true {
 364 |                 if !excludedDirs.contains(fileName) {
 365 |                     result.append(contentsOf: collectFiles(in: url))
 366 |                 }
 367 |             } else if values?.isRegularFile == true {
 368 |                 let ext = url.pathExtension.lowercased()
 369 |                 if codeExtensions.contains(ext) {
 370 |                     result.append(url)
 371 |                 }
 372 |             }
 373 |         }
 374 |         return result.sorted { $0.path < $1.path }
 375 |     }
 376 |     
 377 |     let files = collectFiles(in: folderURL)
 378 |     guard !files.isEmpty else {
 379 |         return .failure(.noTextFilesFound)
 380 |     }
 381 |     
 382 |     // 合并内容
 383 |     var parts: [String] = ["# 目录结构\n```"]
 384 |     for file in files {
 385 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 386 |         parts.append(rel)
 387 |     }
 388 |     parts.append("```\n\n# 文件内容\n")
 389 |     
 390 |     for file in files {
 391 |         let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
 392 |         let ext = file.pathExtension
 393 |         if let content = try? String(contentsOf: file, encoding: .utf8) {
 394 |             let numbered = content.components(separatedBy: .newlines).enumerated()
 395 |                 .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
 396 |             parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
 397 |         }
 398 |     }
 399 |     
 400 |     return .success(TextBundle(
 401 |         content: parts.joined(separator: "\n"),
 402 |         fileCount: files.count,
 403 |         sourcePath: folderURL.path,
 404 |         files: files.map { $0.path }
 405 |     ))
 406 | }
 407 | 
 408 | func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
 409 |     let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
 410 |     try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
 411 |     defer { try? FileManager.default.removeItem(at: tempDir) }
 412 |     
 413 |     let process = Process()
 414 |     process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
 415 |     process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
 416 |     process.standardOutput = FileHandle.nullDevice
 417 |     process.standardError = FileHandle.nullDevice
 418 |     
 419 |     do {
 420 |         try process.run()
 421 |         process.waitUntilExit()
 422 |         
 423 |         guard process.terminationStatus == 0 else {
 424 |             return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
 425 |         }
 426 |         
 427 |         return await extractFromFolder(tempDir)
 428 |     } catch {
 429 |         return .failure(.zipExtractionFailed(error.localizedDescription))
 430 |     }
 431 | }
 432 | 
 433 | // MARK: - Helpers
 434 | 
 435 | struct TestError: Error, CustomStringConvertible {
 436 |     let message: String
 437 |     init(_ message: String) { self.message = message }
 438 |     var description: String { message }
 439 | }
 440 | 
 441 | extension String {
 442 |     static func * (string: String, count: Int) -> String {
 443 |         String(repeating: string, count: count)
 444 |     }
 445 | }

```

`spoke/Tests/test_edge_tts.swift`:

```swift
   1 | #!/usr/bin/env swift
   2 | 
   3 | import Foundation
   4 | import CryptoKit
   5 | import AVFoundation
   6 | 
   7 | // MARK: - Edge TTS 测试脚本
   8 | 
   9 | print("🧪 Edge TTS 测试")
  10 | print(String(repeating: "=", count: 50))
  11 | 
  12 | // 配置
  13 | let text = "你好，这是语音合成测试。Hello, this is a test."
  14 | let voice = "zh-CN-XiaoxiaoNeural"
  15 | let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
  16 | let chromiumVersion = "130.0.2849.68"
  17 | let windowsFileTimeEpoch: Int64 = 11_644_473_600
  18 | 
  19 | // 生成 DRM Token
  20 | func generateSecMsGecToken() -> String {
  21 |     let currentTime = Int64(Date().timeIntervalSince1970)
  22 |     let ticks = (currentTime + windowsFileTimeEpoch) * 10_000_000
  23 |     let roundedTicks = ticks - (ticks % 3_000_000_000)
  24 |     let strToHash = "\(roundedTicks)\(trustedClientToken)"
  25 |     let hash = SHA256.hash(data: strToHash.data(using: .ascii)!)
  26 |     return hash.map { String(format: "%02X", $0) }.joined()
  27 | }
  28 | 
  29 | // WebSocket Delegate
  30 | class WSDelegate: NSObject, URLSessionWebSocketDelegate {
  31 |     var onOpen: (() -> Void)?
  32 |     
  33 |     func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
  34 |         print("   ✅ WebSocket 已连接")
  35 |         onOpen?()
  36 |     }
  37 | }
  38 | 
  39 | // 主测试
  40 | func runTest() async {
  41 |     print("\n📝 测试文本: \(text)")
  42 |     print("🎤 语音: \(voice)")
  43 |     
  44 |     // 构建 URL
  45 |     let secMsGec = generateSecMsGecToken()
  46 |     let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=\(trustedClientToken)&Sec-MS-GEC=\(secMsGec)&Sec-MS-GEC-Version=1-\(chromiumVersion)"
  47 |     
  48 |     guard let url = URL(string: urlString) else {
  49 |         print("❌ URL 无效")
  50 |         return
  51 |     }
  52 |     
  53 |     // 创建 WebSocket
  54 |     print("\n🔗 正在连接...")
  55 |     var request = URLRequest(url: url)
  56 |     request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
  57 |     request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/\(chromiumVersion) Edg/\(chromiumVersion)", forHTTPHeaderField: "User-Agent")
  58 |     
  59 |     let delegate = WSDelegate()
  60 |     let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
  61 |     let ws = session.webSocketTask(with: request)
  62 |     
  63 |     // 等待连接
  64 |     await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
  65 |         delegate.onOpen = { cont.resume() }
  66 |         ws.resume()
  67 |     }
  68 |     
  69 |     // 发送配置
  70 |     print("📤 发送配置...")
  71 |     let configMessage = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
  72 |     do {
  73 |         try await ws.send(.string(configMessage))
  74 |         print("   ✅ 配置已发送")
  75 |     } catch {
  76 |         print("   ❌ 发送配置失败: \(error)")
  77 |         return
  78 |     }
  79 |     
  80 |     // 发送 SSML
  81 |     print("📤 发送 SSML...")
  82 |     let ssml = "<speak version=\"1.0\" xmlns=\"http://www.w3.org/2001/10/synthesis\" xml:lang=\"zh-CN\"><voice name=\"\(voice)\"><prosody rate=\"+0%\" pitch=\"+0Hz\">\(text)</prosody></voice></speak>"
  83 |     let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
  84 |     do {
  85 |         try await ws.send(.string(ssmlMessage))
  86 |         print("   ✅ SSML 已发送")
  87 |     } catch {
  88 |         print("   ❌ 发送 SSML 失败: \(error)")
  89 |         return
  90 |     }
  91 |     
  92 |     // 接收音频
  93 |     print("\n📥 接收音频数据...")
  94 |     var audioData = Data()
  95 |     var messageCount = 0
  96 |     
  97 |     while true {
  98 |         do {
  99 |             let message = try await ws.receive()
 100 |             messageCount += 1
 101 |             
 102 |             switch message {
 103 |             case .data(let data):
 104 |                 // 尝试解析为字符串查看内容
 105 |                 if let str = String(data: data, encoding: .utf8), str.contains("Path:audio\r\n") {
 106 |                     // 找到音频分隔符后的数据
 107 |                     if let range = str.range(of: "Path:audio\r\n") {
 108 |                         let offset = range.upperBound.utf16Offset(in: str)
 109 |                         let audioChunk = data.suffix(from: offset)
 110 |                         audioData.append(audioChunk)
 111 |                         print("   收到音频块 #\(messageCount): \(audioChunk.count) bytes (有 header)")
 112 |                     }
 113 |                 } else {
 114 |                     // 纯二进制音频
 115 |                     audioData.append(data)
 116 |                     print("   收到音频块 #\(messageCount): \(data.count) bytes")
 117 |                 }
 118 |                 
 119 |             case .string(let str):
 120 |                 if str.contains("Path:turn.end") {
 121 |                     print("   ✅ 收到结束信号")
 122 |                     break
 123 |                 } else if str.contains("Path:audio.metadata") {
 124 |                     print("   收到元数据")
 125 |                 } else {
 126 |                     print("   收到文本: \(str.prefix(50))...")
 127 |                 }
 128 |                 continue
 129 |                 
 130 |             @unknown default:
 131 |                 continue
 132 |             }
 133 |             
 134 |             if messageCount > 100 { break } // 防止死循环
 135 |             
 136 |         } catch {
 137 |             print("   ⚠️ 接收错误: \(error)")
 138 |             break
 139 |         }
 140 |     }
 141 |     
 142 |     ws.cancel(with: .goingAway, reason: nil)
 143 |     
 144 |     print("\n📊 结果:")
 145 |     print("   总消息数: \(messageCount)")
 146 |     print("   音频大小: \(audioData.count) bytes")
 147 |     
 148 |     if audioData.isEmpty {
 149 |         print("   ❌ 没有收到音频数据")
 150 |         return
 151 |     }
 152 |     
 153 |     // 检查音频头
 154 |     let header = audioData.prefix(16)
 155 |     print("   音频头: \(header.map { String(format: "%02X", $0) }.joined(separator: " "))")
 156 |     
 157 |     // MP3 文件应该以 FF FB 或 ID3 开头
 158 |     if header.first == 0xFF || (header.prefix(3) == Data([0x49, 0x44, 0x33])) {
 159 |         print("   ✅ 看起来是有效的 MP3 格式")
 160 |     } else {
 161 |         print("   ⚠️ 可能不是标准 MP3 格式")
 162 |     }
 163 |     
 164 |     // 保存到文件
 165 |     let tempPath = "/tmp/edge_tts_test.mp3"
 166 |     do {
 167 |         try audioData.write(to: URL(fileURLWithPath: tempPath))
 168 |         print("\n💾 已保存到: \(tempPath)")
 169 |     } catch {
 170 |         print("   ❌ 保存失败: \(error)")
 171 |         return
 172 |     }
 173 |     
 174 |     // 播放测试
 175 |     print("\n🔊 播放测试...")
 176 |     do {
 177 |         let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: tempPath))
 178 |         player.prepareToPlay()
 179 |         
 180 |         if player.play() {
 181 |             print("   ▶️ 正在播放 (时长: \(String(format: "%.1f", player.duration))秒)")
 182 |             
 183 |             // 等待播放完成
 184 |             while player.isPlaying {
 185 |                 try await Task.sleep(nanoseconds: 100_000_000)
 186 |             }
 187 |             print("   ✅ 播放完成!")
 188 |         } else {
 189 |             print("   ❌ 播放启动失败")
 190 |         }
 191 |     } catch {
 192 |         print("   ❌ 播放错误: \(error)")
 193 |         
 194 |         // 尝试用 afplay 播放
 195 |         print("\n🔧 尝试用 afplay 播放...")
 196 |         let process = Process()
 197 |         process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
 198 |         process.arguments = [tempPath]
 199 |         try? process.run()
 200 |         process.waitUntilExit()
 201 |         
 202 |         if process.terminationStatus == 0 {
 203 |             print("   ✅ afplay 播放成功!")
 204 |         } else {
 205 |             print("   ❌ afplay 也失败了")
 206 |         }
 207 |     }
 208 | }
 209 | 
 210 | // 运行测试
 211 | Task {
 212 |     await runTest()
 213 |     exit(0)
 214 | }
 215 | 
 216 | // 保持运行
 217 | RunLoop.main.run()

```
```