import Foundation
import Testing
@testable import SpokenAnyWhere

@Suite("快捷键设置页源码契约测试")
struct ShortcutsSettingsContentTests {
    @Test("设置页会暴露全部六个全局快捷键入口")
    func shortcutsSettingsExposesAllGlobalShortcutRows() throws {
        let source = try shortcutsSettingsSource()

        #expect(source.contains("appSettings.shortcutDisplayString"))
        #expect(source.contains("appSettings.quickAskShortcutDisplayString"))
        #expect(source.contains("appSettings.messagePanelShortcutDisplayString"))
        #expect(source.contains("appSettings.liveCaptionShortcutDisplayString"))
        #expect(source.contains("appSettings.clipboardPipelineShortcutDisplayString"))
        #expect(source.contains("appSettings.screenshotShortcutDisplayString"))

        #expect(source.contains("appSettings.updateShortcut"))
        #expect(source.contains("appSettings.updateQuickAskShortcut"))
        #expect(source.contains("appSettings.updateMessagePanelShortcut"))
        #expect(source.contains("appSettings.updateLiveCaptionShortcut"))
        #expect(source.contains("appSettings.updateClipboardPipelineShortcut"))
        #expect(source.contains("appSettings.updateScreenshotShortcut"))
    }

    @Test("clipboard pipeline 热键处理器改为走设置模型，不再在 handler 里写死默认值")
    func clipboardPipelineHandlerUsesSettingsBinding() throws {
        let handlerSource = try screenshotHandlerSource()
        let dependenciesSource = try screenshotHandlerDependenciesSource()

        #expect(dependenciesSource.contains("func clipboardPipelineHandlerSettings() -> AppSettings"))
        #expect(dependenciesSource.contains("func makeClipboardPipelineHandlerBinding() -> HotKeyBinding"))
        #expect(handlerSource.contains("self.binding = makeClipboardPipelineHandlerBinding()"))
        #expect(handlerSource.contains("binding = makeClipboardPipelineHandlerBinding()"))
        #expect(!handlerSource.contains("UInt32(kVK_ANSI_V)"))
    }
}

private func shortcutsSettingsSource(filePath: String = #filePath) throws -> String {
    try sourceFile(
        filePath: filePath,
        relativePathComponents: ["UI", "Settings", "ShortcutsSettingsContent.swift"]
    )
}

private func screenshotHandlerSource(filePath: String = #filePath) throws -> String {
    try sourceFile(
        filePath: filePath,
        relativePathComponents: ["Services", "HotKey", "Handlers", "ScreenshotHandler.swift"]
    )
}

private func screenshotHandlerDependenciesSource(filePath: String = #filePath) throws -> String {
    try sourceFile(
        filePath: filePath,
        relativePathComponents: ["Services", "HotKey", "Handlers", "ScreenshotHandlerLiveDependencies.swift"]
    )
}

private func sourceFile(filePath: String, relativePathComponents: [String]) throws -> String {
    let testsFileURL = URL(fileURLWithPath: filePath)
    let repoRootURL = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
    let sourceURL = relativePathComponents.reduce(repoRootURL) { partial, component in
        partial.appendingPathComponent(component)
    }

    return try String(contentsOf: sourceURL, encoding: .utf8)
}
