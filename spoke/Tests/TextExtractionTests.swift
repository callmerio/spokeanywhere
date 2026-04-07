import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("TextExtractionService 测试", .serialized)
struct TextExtractionTests {

    @Test("extractFromFolder 会提取代码与文档文本")
    func extractsCodeAndMarkdown() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try write("let value = 42", to: tempDir.appendingPathComponent("main.swift"))
        try write("# Demo", to: tempDir.appendingPathComponent("README.md"))

        let result = await TextExtractionService.shared.extractFromFolder(tempDir)

        guard case .success(let bundle) = result else {
            Issue.record("expected extraction success")
            return
        }

        #expect(bundle.fileCount == 2)
        #expect(bundle.content.contains("let value = 42"))
        #expect(bundle.content.contains("# Demo"))
    }

    @Test("extractFromFolder 会排除 node_modules 和锁文件")
    func excludesNoiseDirectoriesAndFiles() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try write("console.log('keep')", to: tempDir.appendingPathComponent("app.js"))
        try write("secret", to: tempDir.appendingPathComponent("node_modules/pkg/index.js"))
        try write("{}", to: tempDir.appendingPathComponent("package-lock.json"))

        let result = await TextExtractionService.shared.extractFromFolder(tempDir)

        guard case .success(let bundle) = result else {
            Issue.record("expected extraction success")
            return
        }

        #expect(bundle.fileCount == 1)
        #expect(bundle.content.contains("console.log('keep')"))
        #expect(!bundle.content.contains("secret"))
        #expect(!bundle.content.contains("package-lock"))
    }

    @Test("空目录应返回 noTextFilesFound")
    func emptyFolderReturnsFailure() async throws {
        let tempDir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let result = await TextExtractionService.shared.extractFromFolder(tempDir)

        guard case .failure(let error) = result else {
            Issue.record("expected extraction failure")
            return
        }

        if case .noTextFilesFound = error {
            #expect(Bool(true))
        } else {
            Issue.record("expected noTextFilesFound, got \(error.localizedDescription)")
        }
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TextExtractionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
