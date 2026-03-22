import AppKit
import Foundation

@MainActor
extension QuickAskHUDManagerDependencies {
    static func makeLive(answerPanelManager: AnswerPanelManager) -> Self {
        let hotKeyService = HotKeyService.shared
        return .init(
            hotKeyService: hotKeyService,
            workflowState: .shared,
            attachmentManager: .shared,
            notificationCenter: .default,
            windowRuntime: QuickAskHUDWindowRuntime(
                setQuickAskActive: { hotKeyService.setQuickAskActive($0) },
                setDebugKeyEvents: { hotKeyService.debugKeyEvents = $0 },
                setActivationPolicy: { NSApp.setActivationPolicy($0) },
                activateApp: { NSApp.activate(ignoringOtherApps: true) },
                promotePanel: { panel in
                    panel.makeKeyAndOrderFront(nil)
                    panel.makeMain()
                }
            ),
            clipboardText: { NSPasteboard.general.string(forType: .string) },
            showAnswerPanel: { answerPanelManager.show(question: $0, attachments: $1) },
            updateAnswer: { answerPanelManager.updateAnswer($0, for: $1) },
            showAnswerError: { answerPanelManager.showError($0, for: $1) },
            executeWorkflow: { workflow, context in
                await WorkflowExecutor.shared.execute(workflow, context: context)
            },
            openSettings: {
                _ = NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
            }
        )
    }
}

@MainActor
extension QuickAskServiceDependencies {
    static func makeLive() -> Self {
        .init(
            hudManager: .shared,
            contextService: .shared,
            audioService: .shared,
            llmPipeline: .shared,
            llmSettings: .shared,
            screenOCRService: .shared,
            answerPanelManager: .shared,
            hotKeyService: .shared,
            clipboardHistoryService: .shared,
            liveCaptionManager: .shared,
            notificationCenter: .default
        )
    }
}
