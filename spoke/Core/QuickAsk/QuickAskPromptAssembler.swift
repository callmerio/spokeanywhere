import AppKit
import Foundation

struct QuickAskPromptRequest {
    let userInput: String
    let voiceText: String
    let ocrContext: String?
    let clipboardHistory: [String]
    let liveCaptionText: String
    let liveCaptionLimit: Int
    let attachments: [Attachment]
    let includeOCR: Bool
    let includeClipboard: Bool
    let includeLiveCaption: Bool
}

struct QuickAskPromptBuildResult {
    let prompt: String
    let usedClipboard: Bool
    let usedCaption: Bool
}

private struct QuickAskAttachmentSummary {
    let summaryLine: String
    let textBundleContents: [String]
}

enum QuickAskPromptAssembler {
    static func build(_ request: QuickAskPromptRequest) -> QuickAskPromptBuildResult {
        var sections: [PromptSection] = []

        let userInput = trimmedText(request.userInput)
        let voiceText = trimmedText(request.voiceText)

        appendUserInput(userInput, to: &sections)
        appendVoiceText(voiceText, userInput: userInput, to: &sections)
        appendOCRContextIfNeeded(request, to: &sections)

        let usedClipboard = appendClipboardIfNeeded(request, to: &sections)
        let usedCaption = appendLiveCaptionIfNeeded(request, to: &sections)
        appendAttachments(request.attachments, to: &sections)

        return QuickAskPromptBuildResult(
            prompt: PromptRenderer.renderSections(sections),
            usedClipboard: usedClipboard,
            usedCaption: usedCaption
        )
    }

    private static func trimmedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func appendUserInput(_ userInput: String, to sections: inout [PromptSection]) {
        if let section = PromptRenderer.section(title: "## 用户输入", body: userInput) {
            sections.append(section)
        }
    }

    private static func appendVoiceText(
        _ voiceText: String,
        userInput: String,
        to sections: inout [PromptSection]
    ) {
        guard let voiceSection = PromptRenderer.section(title: "## 语音转写", body: voiceText) else {
            return
        }
        sections.append(voiceSection)
        if !userInput.isEmpty {
            sections.append(
                PromptSection(
                    body: "> 注意：语音转写可能存在偏差（如专业术语、人名等），请结合用户输入理解真实意图。"
                )
            )
        }
    }

    private static func appendOCRContextIfNeeded(
        _ request: QuickAskPromptRequest,
        to sections: inout [PromptSection]
    ) {
        guard request.includeOCR else { return }
        if let section = PromptRenderer.section(title: "## 当前屏幕内容（OCR）", body: request.ocrContext) {
            sections.append(section)
        }
    }

    private static func appendClipboardIfNeeded(
        _ request: QuickAskPromptRequest,
        to sections: inout [PromptSection]
    ) -> Bool {
        guard request.includeClipboard else { return false }
        guard !request.clipboardHistory.isEmpty else { return false }
        let historyText = request.clipboardHistory
            .map { "- \(String($0.prefix(200)))" }
            .joined(separator: "\n")
        if let section = PromptRenderer.section(title: "## 剪贴板历史", body: historyText) {
            sections.append(section)
        }
        return true
    }

    private static func appendLiveCaptionIfNeeded(
        _ request: QuickAskPromptRequest,
        to sections: inout [PromptSection]
    ) -> Bool {
        guard request.includeLiveCaption else { return false }
        guard !request.liveCaptionText.isEmpty else { return false }
        let limitDesc = request.liveCaptionLimit == 0 ? "全量" : "最近\(request.liveCaptionLimit)条"
        if let section = PromptRenderer.section(
            title: "## 实时字幕历史（\(limitDesc)）",
            body: request.liveCaptionText
        ) {
            sections.append(section)
        }
        return true
    }

    private static func appendAttachments(_ attachments: [Attachment], to sections: inout [PromptSection]) {
        guard !attachments.isEmpty else { return }
        let summary = buildAttachmentSummary(from: attachments)
        if let summarySection = PromptRenderer.section(title: "## 附件", body: summary.summaryLine) {
            sections.append(summarySection)
        }

        guard !summary.textBundleContents.isEmpty else { return }
        let bundleText = summary.textBundleContents.joined(separator: "\n\n---\n\n")
        if let bundleSection = PromptRenderer.section(title: "## 代码/文档内容", body: bundleText) {
            sections.append(bundleSection)
        }
    }

    private static func buildAttachmentSummary(from attachments: [Attachment]) -> QuickAskAttachmentSummary {
        var attachmentParts: [String] = []
        var textBundleContents: [String] = []

        for attachment in attachments {
            switch attachment {
            case .image:
                attachmentParts.append("[图片]")
            case .screenshot:
                attachmentParts.append("[截图]")
            case .file(let url, _):
                attachmentParts.append("[文件: \(url.lastPathComponent)]")
            case .textBundle(let content, let source, let count, _):
                attachmentParts.append("[代码包: \(source) (\(count) 文件)]")
                textBundleContents.append("### \(source)\n\(content)")
            }
        }

        return QuickAskAttachmentSummary(
            summaryLine: attachmentParts.joined(separator: ", "),
            textBundleContents: textBundleContents
        )
    }
}
