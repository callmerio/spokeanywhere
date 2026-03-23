import AppKit
import Foundation

struct ClipboardPipelinePayload {
    let content: String
    let sourceApp: SourceAppInfo?
    let wasTruncated: Bool
}

func makeClipboardPipelinePayload(
    maxContentLength: Int,
    pasteboardText: () -> String?,
    currentSourceApp: () -> SourceAppInfo?
) -> ClipboardPipelinePayload? {
    guard let content = pasteboardText() else {
        return nil
    }

    let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedContent.isEmpty else {
        return nil
    }

    let wasTruncated = trimmedContent.count > maxContentLength
    let finalContent: String
    if wasTruncated {
        finalContent = String(trimmedContent.prefix(maxContentLength)) + "..."
    } else {
        finalContent = trimmedContent
    }

    return ClipboardPipelinePayload(
        content: finalContent,
        sourceApp: currentSourceApp(),
        wasTruncated: wasTruncated
    )
}

