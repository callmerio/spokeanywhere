import Foundation
import os
import UniformTypeIdentifiers

// MARK: - Text Bundle Result

/// 文本提取结果
struct TextBundle {
    /// 合并后的文本内容
    let content: String
    /// 提取的文件数量
    let fileCount: Int
    /// 来源路径
    let sourcePath: String
    /// 文件清单
    let files: [String]
}

/// 提取进度回调
struct ExtractionProgress: Sendable {
    let current: Int
    let total: Int
    let currentFile: String
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}

// MARK: - Extraction Error

enum TextExtractionError: LocalizedError {
    case folderNotFound
    case zipExtractionFailed(String)
    case noTextFilesFound
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "文件夹不存在"
        case .zipExtractionFailed(let reason):
            return "ZIP 解压失败: \(reason)"
        case .noTextFilesFound:
            return "未找到文本文件"
        case .accessDenied:
            return "没有访问权限"
        }
    }

    var failureReason: String? {
        switch self {
        case .folderNotFound:
            return "指定的文件夹路径不存在或已被删除"
        case .zipExtractionFailed(let reason):
            return "ZIP 文件解压过程失败: \(reason)"
        case .noTextFilesFound:
            return "目标文件夹或 ZIP 文件中没有可提取的文本文件"
        case .accessDenied:
            return "应用没有访问该文件夹或文件的权限"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .folderNotFound:
            return "请检查文件夹路径是否正确，或选择其他文件夹"
        case .zipExtractionFailed:
            return "请检查 ZIP 文件是否损坏，或尝试手动解压后重试"
        case .noTextFilesFound:
            return "请确认文件夹中包含文本文件（.txt, .md 等），或选择其他文件夹"
        case .accessDenied:
            return "请在系统设置 > 隐私与安全性中授予应用文件访问权限"
        }
    }
}

// MARK: - Text Extraction Service

/// 文本提取服务
/// 从文件夹或 ZIP 中提取所有文本内容并合并
/// 参考 generate-docs.sh 的逻辑，实现 full 模式
actor TextExtractionService {
    
    // MARK: - Singleton
    
    static let shared = TextExtractionService()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "TextExtraction")
    
    // MARK: - Configuration
    
    /// 支持的代码文件扩展名
    private let codeExtensions: Set<String> = [
        // JavaScript/TypeScript
        "js", "jsx", "ts", "tsx", "mjs", "cjs",
        // Web
        "html", "htm", "css", "scss", "less", "vue", "svelte",
        // Python
        "py", "pyw", "pyi",
        // Java/Kotlin
        "java", "kt", "kts", "scala",
        // C/C++
        "c", "cpp", "cc", "cxx", "h", "hpp", "hxx",
        // Rust
        "rs",
        // Go
        "go",
        // Ruby
        "rb", "erb",
        // PHP
        "php",
        // Swift
        "swift",
        // Shell
        "sh", "bash", "zsh", "fish",
        // Config
        "json", "yaml", "yml", "toml", "xml", "ini", "cfg", "conf",
        // Docs
        "md", "mdx", "txt", "rst", "asciidoc",
        // Other
        "sql", "graphql", "proto", "dockerfile"
    ]
    
    /// 排除的目录名
    private let excludedDirs: Set<String> = [
        "node_modules", ".git", ".svn", ".hg",
        "dist", "build", "target", ".next", ".nuxt",
        "__pycache__", ".pytest_cache", ".tox",
        "venv", "env", ".env", ".venv",
        "vendor", "Pods", "Carthage",
        ".idea", ".vscode", ".vs",
        "coverage", "htmlcov", ".nyc_output",
        ".gradle", ".m2"
    ]
    
    /// 排除的文件名
    private let excludedFiles: Set<String> = [
        ".DS_Store", "Thumbs.db", ".gitignore", ".gitattributes",
        "package-lock.json", "yarn.lock", "pnpm-lock.yaml",
        "Podfile.lock", "Gemfile.lock", "Cargo.lock",
        "composer.lock", "poetry.lock"
    ]
    
    /// 单文件最大大小 (1MB)
    private let maxFileSize: Int = 1_000_000
    
    /// 单文件最大行数
    private let maxLines: Int = 5000
    
    // MARK: - Init
    
    private init() {}
    
    // MARK: - Extract from Folder
    
    /// 从文件夹提取所有文本内容
    func extractFromFolder(_ folderURL: URL) async -> Result<TextBundle, TextExtractionError> {
        await extractFromFolder(folderURL, onProgress: nil)
    }
    
    /// 从文件夹提取所有文本内容（带进度回调）
    func extractFromFolder(_ folderURL: URL, onProgress: (@MainActor @Sendable (ExtractionProgress) -> Void)?) async -> Result<TextBundle, TextExtractionError> {
        logger.info("📂 Starting folder extraction: \(folderURL.path)")
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .failure(.folderNotFound)
        }
        
        do {
            // 收集文件列表（快速）
            let files = try collectTextFiles(in: folderURL)
            logger.info("📝 Found \(files.count) files in \(CFAbsoluteTimeGetCurrent() - startTime)s")
            
            guard !files.isEmpty else {
                return .failure(.noTextFilesFound)
            }
            
            // 并行读取文件内容（带进度）
            let content = try await mergeFilesParallel(files, basePath: folderURL, onProgress: onProgress)
            
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            logger.info("✅ Extraction completed in \(String(format: "%.2f", elapsed))s")
            
            return .success(TextBundle(
                content: content,
                fileCount: files.count,
                sourcePath: folderURL.path,
                files: files.map { $0.path }
            ))
        } catch {
            logger.error("❌ Folder extraction failed: \(error)")
            return .failure(.accessDenied)
        }
    }
    
    // MARK: - Extract from ZIP
    
    /// 从 ZIP 提取所有文本内容
    func extractFromZIP(_ zipURL: URL) async -> Result<TextBundle, TextExtractionError> {
        logger.info("📦 Starting ZIP extraction: \(zipURL.path)")
        
        // 创建临时目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtraction-\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // 使用 unzip 命令解压
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", zipURL.path, "-d", tempDir.path]
            
            let pipe = Pipe()
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                try? FileManager.default.removeItem(at: tempDir)
                return .failure(.zipExtractionFailed(errorMessage))
            }
            
            // 提取文本
            let result = await extractFromFolder(tempDir)
            
            // 清理临时目录
            try? FileManager.default.removeItem(at: tempDir)
            
            // 更新来源信息
            switch result {
            case .success(let bundle):
                return .success(TextBundle(
                    content: bundle.content,
                    fileCount: bundle.fileCount,
                    sourcePath: zipURL.path,
                    files: bundle.files
                ))
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            try? FileManager.default.removeItem(at: tempDir)
            logger.error("❌ ZIP extraction failed: \(error)")
            return .failure(.zipExtractionFailed(error.localizedDescription))
        }
    }
    
    // MARK: - Private Helpers
    
    /// 递归收集文本文件
    private func collectTextFiles(in directory: URL) throws -> [URL] {
        var result: [URL] = []
        
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        for url in contents {
            let fileName = url.lastPathComponent
            
            // 跳过排除的文件
            if excludedFiles.contains(fileName) {
                continue
            }
            
            let resourceValues = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey])
            
            // 目录：递归处理
            if resourceValues.isDirectory == true {
                if !excludedDirs.contains(fileName) {
                    let subFiles = try collectTextFiles(in: url)
                    result.append(contentsOf: subFiles)
                }
                continue
            }
            
            // 文件：检查是否是文本文件
            if resourceValues.isRegularFile == true {
                let ext = url.pathExtension.lowercased()
                
                // 检查扩展名
                guard codeExtensions.contains(ext) else { continue }
                
                // 检查文件大小
                if let size = resourceValues.fileSize, size > maxFileSize {
                    logger.info("⏭️ Skipping large file: \(fileName) (\(size) bytes)")
                    continue
                }
                
                result.append(url)
            }
        }
        
        return result.sorted { $0.path < $1.path }
    }
    
    /// 并行读取并合并文件内容
    private func mergeFilesParallel(_ files: [URL], basePath: URL, onProgress: (@MainActor @Sendable (ExtractionProgress) -> Void)?) async throws -> String {
        // 目录结构（快速生成）
        var header = "# 目录结构\n```\n"
        for file in files {
            let relativePath = file.path.replacingOccurrences(of: basePath.path + "/", with: "")
            header += relativePath + "\n"
        }
        header += "```\n\n# 文件内容\n\n"
        
        // 并行读取文件
        let total = files.count
        var processedCount = 0
        
        // 使用 TaskGroup 并行读取
        let fileContents: [(Int, String)] = await withTaskGroup(of: (Int, String).self) { group in
            for (index, file) in files.enumerated() {
                group.addTask {
                    let relativePath = file.path.replacingOccurrences(of: basePath.path + "/", with: "")
                    let ext = file.pathExtension.lowercased()
                    
                    do {
                        let data = try Data(contentsOf: file)
                        guard let content = String(data: data, encoding: .utf8) else {
                            return (index, "## \(relativePath)\n```\n(无法解码文件内容)\n```\n")
                        }
                        
                        // 快速处理：直接截断而不是分割
                        var processedContent = content
                        if content.count > self.maxFileSize {
                            processedContent = String(content.prefix(self.maxFileSize)) + "\n... (truncated)"
                        }
                        
                        // 简化行号（只在文件开头添加）
                        let lineCount = processedContent.filter { $0 == "\n" }.count + 1
                        let numbered = self.addLineNumbersFast(processedContent)
                        
                        return (index, "## \(relativePath) (\(lineCount) lines)\n```\(ext)\n\(numbered)\n```\n")
                    } catch {
                        return (index, "## \(relativePath)\n```\n(无法读取文件内容)\n```\n")
                    }
                }
            }
            
            var results: [(Int, String)] = []
            for await result in group {
                results.append(result)
                processedCount += 1
                
                // 回调进度
                if let onProgress = onProgress {
                    let progress = ExtractionProgress(
                        current: processedCount,
                        total: total,
                        currentFile: files[result.0].lastPathComponent
                    )
                    await MainActor.run {
                        onProgress(progress)
                    }
                }
            }
            return results
        }
        
        // 按原始顺序排序并合并
        let sorted = fileContents.sorted { $0.0 < $1.0 }.map { $0.1 }
        return header + sorted.joined(separator: "\n")
    }
    
    /// 快速添加行号（优化版，nonisolated 可在 TaskGroup 中调用）
    private nonisolated func addLineNumbersFast(_ content: String) -> String {
        var result = ""
        result.reserveCapacity(content.count + content.count / 10) // 预分配内存
        
        var lineNumber = 1
        var lineStart = content.startIndex
        
        for i in content.indices where content[i] == "\n" {
            let line = content[lineStart..<i]
            result += "\(lineNumber)│ \(line)\n"
            lineNumber += 1
            lineStart = content.index(after: i)
        }
        
        // 最后一行
        if lineStart < content.endIndex {
            let line = content[lineStart...]
            result += "\(lineNumber)│ \(line)"
        }
        
        return result
    }
    
    /// 合并文件内容（保留用于向后兼容）
    private func mergeFiles(_ files: [URL], basePath: URL) throws -> String {
        var parts: [String] = []
        
        // 添加目录结构
        parts.append("# 目录结构\n")
        parts.append("```")
        for file in files {
            let relativePath = file.path.replacingOccurrences(of: basePath.path + "/", with: "")
            parts.append(relativePath)
        }
        parts.append("```\n")
        
        // 添加文件内容
        parts.append("# 文件内容\n")
        
        for file in files {
            let relativePath = file.path.replacingOccurrences(of: basePath.path + "/", with: "")
            let ext = file.pathExtension.lowercased()
            
            do {
                var content = try String(contentsOf: file, encoding: .utf8)
                
                // 限制行数
                let lines = content.components(separatedBy: .newlines)
                if lines.count > maxLines {
                    content = lines.prefix(maxLines).joined(separator: "\n")
                    content += "\n\n... (truncated, \(lines.count - maxLines) more lines)"
                }
                
                // 添加带行号的内容
                let numberedContent = addLineNumbers(content)
                
                parts.append("## \(relativePath)\n")
                parts.append("```\(ext)")
                parts.append(numberedContent)
                parts.append("```\n")
            } catch {
                logger.warning("⚠️ Failed to read file: \(relativePath)")
                parts.append("## \(relativePath)\n")
                parts.append("```\n(无法读取文件内容)\n```\n")
            }
        }
        
        return parts.joined(separator: "\n")
    }
    
    /// 添加行号
    private func addLineNumbers(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        let lineNumberWidth = String(lines.count).count
        
        return lines.enumerated().map { index, line in
            let lineNumber = String(format: "%\(lineNumberWidth)d", index + 1)
            return "\(lineNumber)│ \(line)"
        }.joined(separator: "\n")
    }
}
