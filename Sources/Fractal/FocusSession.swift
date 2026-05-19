import Foundation

struct FocusSession: Identifiable, Codable, Equatable {
    let id: UUID
    let topic: String?
    let durationSeconds: Int
    let startedAt: Date
    let endedAt: Date

    init(
        id: UUID = UUID(),
        topic: String?,
        durationSeconds: Int,
        startedAt: Date,
        endedAt: Date
    ) {
        self.id = id
        self.topic = topic?.trimmedNonEmpty
        self.durationSeconds = durationSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    var topicDisplayName: String {
        topic ?? "No topic set"
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
