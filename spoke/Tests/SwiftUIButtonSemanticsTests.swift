import Foundation
import SwiftUI
import Testing
@testable import SpokenAnyWhere

@Suite("SwiftUI Button 语义测试")
@MainActor
struct SwiftUIButtonSemanticsTests {
    @Test("第一批明确动作点不再使用 onTapGesture 充当按钮")
    func firstBatchUsesButtons() throws {
        let tagBubbleSource = try loadSource(at: ["UI", "Components", "TagBubbleView.swift"])
        let workflowPickerSource = try loadSource(at: ["UI", "Workflow", "WorkflowPickerView.swift"])
        let cardAttachmentSource = try loadSource(at: ["UI", "Components", "CardAttachmentView.swift"])
        let messageCardSource = try loadSource(at: ["UI", "MessagePanel", "MessageCardView.swift"])
        let quickAskCapsuleSource = try loadSource(at: ["UI", "HUD", "QuickAskCapsuleView.swift"])

        #expect(
            tagBubbleSource.contains("Button {") && tagBubbleSource.contains("onFilterToggle?()"),
            "TagBubbleView 的筛选切换应改为 Button"
        )
        #expect(
            !tagBubbleSource.contains(".onTapGesture {"),
            "TagBubbleView 不应再用 onTapGesture 承担主动作"
        )

        #expect(
            workflowPickerSource.contains("Button {") && workflowPickerSource.contains("onSelect(workflow)"),
            "WorkflowPickerView 的选项点击应改为 Button"
        )
        #expect(
            !workflowPickerSource.contains(".onTapGesture {"),
            "WorkflowPickerView 不应再用 onTapGesture 承担主动作"
        )

        #expect(
            cardAttachmentSource.contains("Button {") && cardAttachmentSource.contains("showFullImage = true"),
            "CardAttachmentView 的图片预览打开应改为 Button"
        )
        #expect(
            !cardAttachmentSource.contains(".onTapGesture {"),
            "CardAttachmentView 不应再用 onTapGesture 承担主动作"
        )

        #expect(
            messageCardSource.contains("cardActionButton(icon: \"doc.on.doc\""),
            "MessageCardView 应提供显式复制按钮，而不是依赖整卡 onTapGesture"
        )
        #expect(
            messageCardSource.contains("isShowingOriginal.toggle()"),
            "MessageCardView 应通过显式动作切换摘要/原文"
        )
        #expect(
            !messageCardSource.contains(".onTapGesture {"),
            "MessageCardView 不应再用根级 onTapGesture 承担主动作"
        )

        #expect(
            !quickAskCapsuleSource.contains(".onTapGesture {"),
            "QuickAskCapsuleView 不应再用 onTapGesture 同步 Menu 打开状态"
        )
        #expect(
            quickAskCapsuleSource.contains("@State private var isAttachmentMenuPresented = false"),
            "QuickAskCapsuleView 应显式跟踪附件菜单打开状态"
        )
        #expect(
            quickAskCapsuleSource.contains("isIconHovering || isAttachmentMenuPresented"),
            "QuickAskCapsuleView 的加号显示应覆盖 hover 与菜单打开两种状态"
        )
        #expect(
            quickAskCapsuleSource.contains("showAttachmentMenu()"),
            "QuickAskCapsuleView 应通过显式 Button 动作拉起附件菜单"
        )
        #expect(
            !quickAskCapsuleSource.contains("Menu {"),
            "QuickAskCapsuleView 不应继续依赖 SwiftUI Menu 维护附件菜单状态"
        )

        let tag = CardTag(name: "Swift", color: .blue)
        let tagBubble = TagBubbleView(
            tag: tag,
            cardId: nil,
            dependencies: .preview,
            onFilterToggle: {}
        )
        #expect(
            containsRuntimeViewType(tagBubble.body, containing: "Button"),
            "TagBubbleView 注入筛选动作后，运行时 body 应包含 Button 语义"
        )

        let workflow = WorkflowAction.builtin(
            keyword: "sum",
            name: "总结",
            description: "总结输入",
            icon: "text.quote",
            iconColorHex: "#FFFFFF",
            promptTemplate: "总结"
        )
        let workflowPicker = WorkflowPickerView(
            filter: "sum",
            onSelect: { _ in },
            dependencies: WorkflowPickerViewDependencies(
                workflowState: .makePreview(),
                search: { _ in [workflow] },
                groupedWorkflows: { _ in [(title: "Test", workflows: [workflow])] }
            )
        )
        #expect(
            containsRuntimeViewType(workflowPicker.body, containing: "Button"),
            "WorkflowPickerView 有可选 workflow 时，运行时列表项应包含 Button 语义"
        )

        let attachment = CardAttachment(fileName: "missing.png", originalWidth: 120, originalHeight: 80)
        let attachmentThumbnail = CardAttachmentThumbnail(
            attachment: attachment,
            cardId: UUID(),
            fixedHeight: 60,
            dependencies: CardAttachmentViewDependencies(
                imageCache: .shared,
                removeAttachment: { _, _ in },
                copyImage: { _ in },
                saveImageToDesktop: { _, _ in }
            )
        )
        #expect(
            containsRuntimeViewType(attachmentThumbnail.body, containing: "Button"),
            "CardAttachmentView 展开图片时，运行时缩略图应包含 Button 语义"
        )

        let messageCard = MessageCard(stage: .asr(model: "Test"), content: String(repeating: "内容", count: 80))
        let messageCardView = MessageCardView(
            card: messageCard,
            activeFilterTagIds: [],
            dependencies: MessageCardViewDependencies(
                hoverState: .makePreview(),
                resolveTags: { _ in [] },
                setRecordType: { _, _ in },
                pasteImageFromClipboard: { _ in false },
                addAttachment: { _, _ in },
                generateSummary: { _, _ in }
            )
        )
        #expect(
            containsRuntimeViewType(messageCardView.body, containing: "Button"),
            "MessageCardView 需要折叠/上下文动作时，运行时树应包含显式 Button，而不是整卡点击手势"
        )
    }

    private func loadSource(at components: [String]) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = components.reduce(projectRoot) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func containsRuntimeViewType(_ value: Any, containing needle: String) -> Bool {
        containsRuntimeViewType(value, containing: needle, remainingDepth: 28)
    }

    private func containsRuntimeViewType(_ value: Any, containing needle: String, remainingDepth: Int) -> Bool {
        guard remainingDepth >= 0 else { return false }

        let mirror = Mirror(reflecting: value)
        if String(describing: mirror.subjectType).contains(needle) {
            return true
        }

        for child in mirror.children {
            if containsRuntimeViewType(child.value, containing: needle, remainingDepth: remainingDepth - 1) {
                return true
            }
        }

        return false
    }
}
