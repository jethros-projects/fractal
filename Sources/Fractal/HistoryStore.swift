import Combine
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var sessions: [FocusSession] = []

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        self.fileURL = fileURL ?? supportDirectory
            .appendingPathComponent("Fractal", isDirectory: true)
            .appendingPathComponent("sessions.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
    }

    var sessionsNewestFirst: [FocusSession] {
        sessions.sorted { $0.endedAt > $1.endedAt }
    }

    func append(_ session: FocusSession) {
        sessions.append(session)
        sessions.sort { $0.startedAt < $1.startedAt }
        save()
    }

    func totalFocusedSeconds(on date: Date, calendar: Calendar = .current) -> Int {
        sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .map(\.durationSeconds)
            .reduce(0, +)
    }

    func totalFocusedSecondsThisWeek(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }

        return sessions
            .filter { week.contains($0.startedAt) }
            .map(\.durationSeconds)
            .reduce(0, +)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            sessions = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try decoder.decode([FocusSession].self, from: data)
                .sorted { $0.startedAt < $1.startedAt }
        } catch {
            sessions = []
            NSLog("Fractal could not load history: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Fractal could not save history: \(error.localizedDescription)")
        }
    }
}
