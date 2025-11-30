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