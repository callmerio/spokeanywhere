import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("ScreenOCR 调试目录测试")
@MainActor
struct ScreenOCRDebugArtifactsTests {

    @Test("调试产物目录应落在系统临时目录下且不包含开发机绝对路径")
    func usesTemporaryDirectory() {
        let directory = ScreenOCRService.makeDebugArtifactsDirectory()
        let normalizedDirectory = directory.standardizedFileURL.path
        let normalizedTemp = FileManager.default.temporaryDirectory.standardizedFileURL.path

        #expect(normalizedDirectory.hasPrefix(normalizedTemp))
        #expect(normalizedDirectory.contains("/SpokenAnyWhere/ocr-debug"))
        #expect(!normalizedDirectory.contains("/Users/bigdan/Workspace"))
    }
}
