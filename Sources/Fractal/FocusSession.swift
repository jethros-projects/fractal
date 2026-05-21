import Foundation

enum FocusSessionKind: String, Codable, Equatable {
    case focused
    case untracked
}

struct FocusSession: Identifiable, Codable, Equatable {
    let id: UUID
    let topic: String?
    let durationSeconds: Int
    let startedAt: Date
    let endedAt: Date
    let kind: FocusSessionKind

    init(
        id: UUID = UUID(),
        topic: String?,
        durationSeconds: Int,
        startedAt: Date,
        endedAt: Date,
        kind: FocusSessionKind = .focused
    ) {
        self.id = id
        self.topic = topic?.trimmedNonEmpty
        self.durationSeconds = max(0, durationSeconds)
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.kind = kind
    }

    init(
        id: UUID = UUID(),
        topic: String?,
        startedAt: Date,
        endedAt: Date,
        kind: FocusSessionKind = .focused
    ) {
        self.init(
            id: id,
            topic: topic,
            durationSeconds: max(0, Int(endedAt.timeIntervalSince(startedAt).rounded())),
            startedAt: startedAt,
            endedAt: endedAt,
            kind: kind
        )
    }

    var topicDisplayName: String {
        if kind == .untracked, topic == nil {
            return "Untracked"
        }

        return topic ?? "No topic set"
    }

    var isUntracked: Bool {
        kind == .untracked
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case topic
        case durationSeconds
        case startedAt
        case endedAt
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)?.trimmedNonEmpty
        durationSeconds = max(0, try container.decode(Int.self, forKey: .durationSeconds))
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        kind = try container.decodeIfPresent(FocusSessionKind.self, forKey: .kind) ?? .focused
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(topic, forKey: .topic)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(kind, forKey: .kind)
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
