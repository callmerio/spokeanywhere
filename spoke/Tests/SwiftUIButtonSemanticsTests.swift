import Foundation
import Testing

@Suite("SwiftUI Button 语义测试")
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
    }

    private func loadSource(at components: [String]) throws -> String {
        let testsFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testsFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let sourceURL = components.reduce(projectRoot) { partial, component in
            partial.appendingPathComponent(component, isDirectory: false)
        }

        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
