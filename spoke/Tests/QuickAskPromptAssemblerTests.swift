import AppKit
import Testing
@testable import SpokenAnyWhere

@Suite("QuickAskPromptAssembler 测试")
struct QuickAskPromptAssemblerTests {

    @Test("仅在启用时拼入 OCR 上下文，且禁用的剪贴板不会进入 prompt")
    func contextSectionsRespectFlags() {
        let request = QuickAskPromptRequest(
            userInput: "总结一下",
            voiceText: "",
            ocrContext: "窗口文本",
            clipboardHistory: ["剪贴板内容"],
            liveCaptionText: "",
            liveCaptionLimit: 0,
            attachments: [],
            includeOCR: true,
            includeClipboard: false,
            includeLiveCaption: false
        )

        let result = QuickAskPromptAssembler.build(request)

        #expect(result.prompt.contains("## 用户输入"))
        #expect(result.prompt.contains("窗口文本"))
        #expect(!result.prompt.contains("剪贴板内容"))
        #expect(!result.usedClipboard)
        #expect(!result.usedCaption)
    }

    @Test("语音提示、字幕历史和附件摘要保持现有渲染语义")
    func rendersVoiceCaptionAndAttachments() {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        let request = QuickAskPromptRequest(
            userInput: "请帮我解释",
            voiceText: "这段代码做什么",
            ocrContext: nil,
            clipboardHistory: ["最近复制的片段"],
            liveCaptionText: "第一句\n第二句",
            liveCaptionLimit: 3,
            attachments: [
                .screenshot(image, nil, UUID()),
                .textBundle("let value = 42", "demo.swift", 1, UUID())
            ],
            includeOCR: false,
            includeClipboard: true,
            includeLiveCaption: true
        )

        let result = QuickAskPromptAssembler.build(request)

        #expect(result.prompt.contains("## 语音转写"))
        #expect(result.prompt.contains("语音转写可能存在偏差"))
        #expect(result.prompt.contains("## 剪贴板历史"))
        #expect(result.prompt.contains("## 实时字幕历史（最近3条）"))
        #expect(result.prompt.contains("## 附件"))
        #expect(result.prompt.contains("[截图]"))
        #expect(result.prompt.contains("[代码包: demo.swift (1 文件)]"))
        #expect(result.prompt.contains("## 代码/文档内容"))
        #expect(result.prompt.contains("### demo.swift"))
        #expect(result.usedClipboard)
        #expect(result.usedCaption)
    }
}
