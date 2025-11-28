import Foundation

// MARK: - Text Extraction Service Tests

/// 独立运行的测试脚本
/// 用法: swift Tests/TextExtractionTests.swift
@main
struct TextExtractionTests {
    
    static var tempDirectory: URL!
    static var passCount = 0
    static var failCount = 0
    
    static func main() async {
        print("🧪 TextExtractionService 单元测试")
        print("=" * 50)
        
        // 创建临时目录
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        defer {
            // 清理
            try? FileManager.default.removeItem(at: tempDirectory)
            print("\n" + "=" * 50)
            print("✅ 通过: \(passCount)  ❌ 失败: \(failCount)")
        }
        
        // 运行测试
        await runTest("代码文件扩展名识别") { try await testCodeExtensions() }
        await runTest("单文件提取") { try await testSingleFileExtraction() }
        await runTest("多文件合并") { try await testMultipleFilesExtraction() }
        await runTest("排除 node_modules") { try await testExcludesNodeModules() }
        await runTest("排除锁文件") { try await testExcludesLockFiles() }
        await runTest("递归遍历嵌套目录") { try await testNestedDirectories() }
        await runTest("空文件夹返回错误") { try await testEmptyFolderError() }
        await runTest("忽略非代码文件") { try await testIgnoresNonCodeFiles() }
        await runTest("添加行号") { try await testAddsLineNumbers() }
        await runTest("目录结构输出") { try await testDirectoryStructure() }
        await runTest("ZIP 提取") { try await testZIPExtraction() }
    }
    
    // MARK: - Test Runner
    
    static func runTest(_ name: String, _ test: () async throws -> Void) async {
        print("\n📝 测试: \(name)")
        do {
            try await test()
            print("   ✅ 通过")
            passCount += 1
        } catch {
            print("   ❌ 失败: \(error)")
            failCount += 1
        }
    }
    
    // MARK: - Helpers
    
    static func createFile(name: String, content: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    static func createDirectory(name: String) throws -> URL {
        let dirURL = tempDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        return dirURL
    }
    
    // MARK: - Test Cases
    
    static func testCodeExtensions() async throws {
        // 创建各种代码文件
        _ = try createFile(name: "test.swift", content: "let x = 1")
        _ = try createFile(name: "app.js", content: "const x = 1")
        _ = try createFile(name: "main.py", content: "x = 1")
        _ = try createFile(name: "README.md", content: "# Title")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.fileCount == 4 else {
            throw TestError("文件数量错误: 期望 4, 实际 \(bundle.fileCount)")
        }
    }
    
    static func testSingleFileExtraction() async throws {
        // 清理并创建新目录
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        _ = try createFile(name: "main.swift", content: "print(\"Hello\")")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.fileCount == 1 else {
            throw TestError("文件数量错误: 期望 1, 实际 \(bundle.fileCount)")
        }
        guard bundle.content.contains("print(\"Hello\")") else {
            throw TestError("内容不包含预期文本")
        }
    }
    
    static func testMultipleFilesExtraction() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        _ = try createFile(name: "a.swift", content: "let a = 1")
        _ = try createFile(name: "b.swift", content: "let b = 2")
        _ = try createFile(name: "c.js", content: "const c = 3")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.fileCount == 3 else {
            throw TestError("文件数量错误")
        }
        guard bundle.content.contains("let a = 1") &&
              bundle.content.contains("let b = 2") &&
              bundle.content.contains("const c = 3") else {
            throw TestError("内容缺失")
        }
    }
    
    static func testExcludesNodeModules() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        let nodeModules = try createDirectory(name: "node_modules")
        try "const secret = 'password'".write(
            to: nodeModules.appendingPathComponent("secret.js"),
            atomically: true, encoding: .utf8
        )
        _ = try createFile(name: "app.js", content: "const app = 1")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.fileCount == 1 else {
            throw TestError("应该只包含 app.js")
        }
        guard !bundle.content.contains("secret") else {
            throw TestError("不应包含 node_modules 内容")
        }
    }
    
    static func testExcludesLockFiles() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        _ = try createFile(name: "package-lock.json", content: "{}")
        _ = try createFile(name: "yarn.lock", content: "")
        _ = try createFile(name: "package.json", content: "{\"name\": \"test\"}")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.fileCount == 1 else {
            throw TestError("应该只包含 package.json")
        }
    }
    
    static func testNestedDirectories() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        _ = try createFile(name: "root.swift", content: "let root = 1")
        _ = try createFile(name: "src/app.swift", content: "let src = 2")
        _ = try createFile(name: "src/lib/utils.swift", content: "let lib = 3")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.fileCount == 3 else {
            throw TestError("应该包含 3 个文件")
        }
        guard bundle.content.contains("let root = 1") &&
              bundle.content.contains("let src = 2") &&
              bundle.content.contains("let lib = 3") else {
            throw TestError("缺少嵌套目录内容")
        }
    }
    
    static func testEmptyFolderError() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        let emptyDir = try createDirectory(name: "empty")
        
        let result = await extractFromFolder(emptyDir)
        guard case .failure = result else {
            throw TestError("空文件夹应该返回错误")
        }
    }
    
    static func testIgnoresNonCodeFiles() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        _ = try createFile(name: "image.png", content: "fake")
        _ = try createFile(name: "video.mp4", content: "fake")
        _ = try createFile(name: "main.swift", content: "let x = 1")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.fileCount == 1 else {
            throw TestError("应该只包含 .swift 文件")
        }
    }
    
    static func testAddsLineNumbers() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        _ = try createFile(name: "test.txt", content: "line one\nline two\nline three")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.content.contains("1│") &&
              bundle.content.contains("2│") &&
              bundle.content.contains("3│") else {
            throw TestError("缺少行号")
        }
    }
    
    static func testDirectoryStructure() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        _ = try createFile(name: "main.swift", content: "entry")
        _ = try createFile(name: "src/app.swift", content: "code")
        
        let result = await extractFromFolder(tempDirectory)
        guard case .success(let bundle) = result else {
            throw TestError("提取失败")
        }
        
        guard bundle.content.contains("# 目录结构") else {
            throw TestError("缺少目录结构标题")
        }
    }
    
    static func testZIPExtraction() async throws {
        try FileManager.default.removeItem(at: tempDirectory)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 创建源文件
        let sourceDir = try createDirectory(name: "source")
        try "let x = 1".write(to: sourceDir.appendingPathComponent("test.swift"), atomically: true, encoding: .utf8)
        
        // 创建 ZIP
        let zipPath = tempDirectory.appendingPathComponent("test.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tempDirectory
        process.arguments = ["-r", zipPath.path, "source"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw TestError("创建 ZIP 失败")
        }
        
        let result = await extractFromZIP(zipPath)
        guard case .success(let bundle) = result else {
            throw TestError("ZIP 提取失败")
        }
        
        guard bundle.fileCount == 1 else {
            throw TestError("ZIP 文件数量错误")
        }
        guard bundle.content.contains("let x = 1") else {
            throw TestError("ZIP 内容缺失")
        }
    }
}

// MARK: - TextExtractionService (简化版，用于测试)

struct TextBundle {
    let content: String
    let fileCount: Int
    let sourcePath: String
    let files: [String]
}

enum TextExtractionError: Error, Equatable {
    case folderNotFound
    case zipExtractionFailed(String)
    case noTextFilesFound
    case accessDenied
}

func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
    let codeExtensions: Set<String> = [
        "js", "jsx", "ts", "tsx", "mjs", "cjs",
        "html", "htm", "css", "scss", "less", "vue", "svelte",
        "py", "pyw", "pyi",
        "java", "kt", "kts", "scala",
        "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
        "rs", "go", "rb", "erb", "php", "swift",
        "sh", "bash", "zsh", "fish",
        "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
        "md", "mdx", "txt", "rst", "asciidoc",
        "sql", "graphql", "proto", "dockerfile"
    ]
    
    let excludedDirs: Set<String> = [
        "node_modules", ".git", ".svn", ".hg",
        "dist", "build", "target", ".next", ".nuxt",
        "__pycache__", ".pytest_cache", ".tox",
        "venv", "env", ".env", ".venv",
        "vendor", "Pods", "Carthage",
        ".idea", ".vscode", ".vs"
    ]
    
    let excludedFiles: Set<String> = [
        ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
        "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
        "Podfile.lock", "Gemfile.lock", "Cargo.lock"
    ]
    
    // 递归收集文件
    func collectFiles(in directory: URL) -> [URL] {
        var result: [URL] = []
        let fm = FileManager.default
        
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        for url in contents {
            let fileName = url.lastPathComponent
            if excludedFiles.contains(fileName) { continue }
            
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            
            if values?.isDirectory == true {
                if !excludedDirs.contains(fileName) {
                    result.append(contentsOf: collectFiles(in: url))
                }
            } else if values?.isRegularFile == true {
                let ext = url.pathExtension.lowercased()
                if codeExtensions.contains(ext) {
                    result.append(url)
                }
            }
        }
        return result.sorted { $0.path < $1.path }
    }
    
    let files = collectFiles(in: folderURL)
    guard !files.isEmpty else {
        return .failure(.noTextFilesFound)
    }
    
    // 合并内容
    var parts: [String] = ["# 目录结构\n```"]
    for file in files {
        let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
        parts.append(rel)
    }
    parts.append("```\n\n# 文件内容\n")
    
    for file in files {
        let rel = file.path.replacingOccurrences(of: folderURL.path + "/", with: "")
        let ext = file.pathExtension
        if let content = try? String(contentsOf: file, encoding: .utf8) {
            let numbered = content.components(separatedBy: .newlines).enumerated()
                .map { "\($0.offset + 1)│ \($0.element)" }.joined(separator: "\n")
            parts.append("## \(rel)\n```\(ext)\n\(numbered)\n```\n")
        }
    }
    
    return .success(TextBundle(
        content: parts.joined(separator: "\n"),
        fileCount: files.count,
        sourcePath: folderURL.path,
        files: files.map { $0.path }
    ))
}

func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    
    do {
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            return .failure(.zipExtractionFailed("Exit code: \(process.terminationStatus)"))
        }
        
        return await extractFromFolder(tempDir)
    } catch {
        return .failure(.zipExtractionFailed(error.localizedDescription))
    }
}

// MARK: - Helpers

struct TestError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

extension String {
    static func * (string: String, count: Int) -> String {
        String(repeating: string, count: count)
    }
}
