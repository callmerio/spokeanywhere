import Foundation

struct PromptSection {
    let title: String?
    let body: String

    init(title: String? = nil, body: String) {
        self.title = title
        self.body = body
    }

    var rendered: String {
        guard let title, !title.isEmpty else {
            return body
        }
        return "\(title)\n\(body)"
    }
}

enum PromptRenderer {
    static func section(title: String? = nil, body: String?) -> PromptSection? {
        guard let body else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return PromptSection(title: title, body: trimmed)
    }

    static func renderSections(_ sections: [PromptSection], separator: String = "\n\n") -> String {
        sections.map(\.rendered).joined(separator: separator)
    }

    static func renderBulletSection(
        title: String,
        intro: String? = nil,
        items: [String],
        outro: String? = nil
    ) -> String? {
        let trimmedItems = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmedItems.isEmpty else { return nil }

        var lines: [String] = []
        if let intro, !intro.isEmpty {
            lines.append(intro)
        }
        lines.append(contentsOf: trimmedItems.map { "- \($0)" })
        if let outro, !outro.isEmpty {
            lines.append("")
            lines.append(outro)
        }
        return renderSections([PromptSection(title: title, body: lines.joined(separator: "\n"))])
    }

    static func replacingPlaceholders(
        in template: String,
        replacements: [(placeholder: String, value: String)]
    ) -> String {
        let rendered = replacements.reduce(template) { partial, pair in
            partial.replacingOccurrences(of: pair.placeholder, with: pair.value)
        }
        return rendered.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func singleLine(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
    }
}
