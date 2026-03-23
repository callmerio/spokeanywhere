import AppKit
import Foundation

@MainActor
extension WorkflowExecutorDependencies {
    static let live = makeLive(
        from: .shared,
        dateProvider: Date.init,
        localeProvider: { .current }
    )

    static func makeLive(
        from services: WorkflowExecutorLiveServices,
        dateProvider: @escaping () -> Date,
        localeProvider: @escaping () -> Locale
    ) -> WorkflowExecutorDependencies {
        makeLive(
            settings: services.settings,
            pipeline: services.pipeline,
            workflowConfigService: services.workflowConfigService,
            pasteboard: services.pasteboard,
            dateProvider: dateProvider,
            localeProvider: localeProvider
        )
    }

    static func makeLive(
        settings: LLMSettings,
        pipeline: LLMPipeline,
        workflowConfigService: WorkflowConfigService,
        pasteboard: NSPasteboard,
        dateProvider: @escaping () -> Date,
        localeProvider: @escaping () -> Locale
    ) -> WorkflowExecutorDependencies {
        WorkflowExecutorDependencies(
            availableProfiles: { settings.profiles },
            chatProfileId: { settings.chatProfileId },
            summaryProfileId: { settings.summaryProfileId },
            selectedProfileId: { settings.selectedProfileId },
            executeChat: { prompt, profile in
                await pipeline.chat(prompt, profile: profile)
            },
            markAsRecent: { workflowId in
                workflowConfigService.markAsRecent(workflowId)
            },
            currentDateString: { dateProvider().formatted() },
            currentLocaleIdentifier: { localeProvider().identifier },
            copyText: { text in
                copyTextToPasteboard(text, pasteboard: pasteboard)
            }
        )
    }

    private static func copyTextToPasteboard(_ text: String, pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
