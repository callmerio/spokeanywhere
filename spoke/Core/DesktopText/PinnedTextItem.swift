import CoreGraphics
import Foundation
import Observation

// MARK: - Pinned Text Source

enum PinnedTextSource: String, Codable, CaseIterable {
    case clipboard
    case voice
    case manual
}

// MARK: - Pinned Text Item

@Observable
@MainActor
final class PinnedTextItem: Identifiable {
    let id: UUID
    let createdAt: Date

    var text: String
    var frame: CGRect
    var opacity: Double
    var zoomLevel: Double
    var isPinned: Bool
    var isLocked: Bool
    var isMarked: Bool
    var screenLocalizedName: String?
    var source: PinnedTextSource

    init(
        id: UUID = UUID(),
        text: String,
        frame: CGRect,
        opacity: Double = 1.0,
        zoomLevel: Double = 1.0,
        isPinned: Bool = true,
        isLocked: Bool = false,
        isMarked: Bool = false,
        screenLocalizedName: String? = nil,
        source: PinnedTextSource = .clipboard,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.frame = frame
        self.opacity = opacity
        self.zoomLevel = zoomLevel
        self.isPinned = isPinned
        self.isLocked = isLocked
        self.isMarked = isMarked
        self.screenLocalizedName = screenLocalizedName
        self.source = source
        self.createdAt = createdAt
    }
}

// MARK: - Codable

extension PinnedTextItem: @preconcurrency Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case text
        case frame
        case opacity
        case zoomLevel
        case isPinned
        case isLocked
        case isMarked
        case screenLocalizedName
        case source
        case createdAt
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let text = try container.decode(String.self, forKey: .text)
        let frame = try container.decode(CGRect.self, forKey: .frame)
        let opacity = try container.decode(Double.self, forKey: .opacity)
        let zoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        let isPinned = try container.decode(Bool.self, forKey: .isPinned)
        let isLocked = try container.decode(Bool.self, forKey: .isLocked)
        let isMarked = try container.decodeIfPresent(Bool.self, forKey: .isMarked) ?? false
        let screenLocalizedName = try container.decodeIfPresent(String.self, forKey: .screenLocalizedName)
        let source = try container.decode(PinnedTextSource.self, forKey: .source)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)

        self.init(
            id: id,
            text: text,
            frame: frame,
            opacity: opacity,
            zoomLevel: zoomLevel,
            isPinned: isPinned,
            isLocked: isLocked,
            isMarked: isMarked,
            screenLocalizedName: screenLocalizedName,
            source: source,
            createdAt: createdAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encode(frame, forKey: .frame)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(zoomLevel, forKey: .zoomLevel)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(isLocked, forKey: .isLocked)
        try container.encode(isMarked, forKey: .isMarked)
        try container.encodeIfPresent(screenLocalizedName, forKey: .screenLocalizedName)
        try container.encode(source, forKey: .source)
        try container.encode(createdAt, forKey: .createdAt)
    }
}
