#if canImport(Combine)
import Combine
#endif
import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    nonisolated static let defaultDaySlotLengthSeconds = 15 * 60

    @Published private(set) var sessions: [FocusSession] = []
    @Published private(set) var activeDayStartedAt: Date?
    @Published private(set) var activeDaySlotLengthSeconds: Int?

    private let fileURL: URL
    private let dayStateURL: URL
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
        dayStateURL = self.fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("active-day.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        load()
        loadDayState()
    }

    var sessionsNewestFirst: [FocusSession] {
        sessions.sorted { $0.endedAt > $1.endedAt }
    }

    func activeDayPreviewSessions(
        until date: Date = Date(),
        calendar: Calendar = .current
    ) -> [FocusSession] {
        guard let startedAt = activeDayStartedAt else {
            return []
        }

        let finishedAt = minDate(date, activeDayEnd(for: startedAt, calendar: calendar) ?? date)
        guard finishedAt > startedAt else {
            return []
        }

        return untrackedSessions(
            from: startedAt,
            to: finishedAt,
            slotLengthSeconds: activeDaySlotLengthSeconds ?? Self.defaultDaySlotLengthSeconds,
            idProvider: deterministicSlotID
        )
    }

    func append(_ session: FocusSession) {
        sessions.append(session)
        sessions.sort { $0.startedAt < $1.startedAt }
        save()
    }

    func updateSession(
        id: UUID,
        topic: String?,
        startedAt: Date,
        endedAt: Date,
        kind: FocusSessionKind
    ) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else {
            return
        }

        let normalizedEnd = endedAt > startedAt ? endedAt : startedAt.addingTimeInterval(60)
        sessions[index] = FocusSession(
            id: id,
            topic: topic,
            startedAt: startedAt,
            endedAt: normalizedEnd,
            kind: kind
        )
        sessions.sort { $0.startedAt < $1.startedAt }
        save()
    }

    func startDay(
        at date: Date = Date(),
        slotLengthSeconds: Int = 15 * 60
    ) {
        finishExpiredActiveDay(now: date)

        guard activeDayStartedAt == nil else {
            return
        }

        activeDayStartedAt = date
        activeDaySlotLengthSeconds = max(1, slotLengthSeconds)
        saveDayState()
    }

    @discardableResult
    func finishDay(
        at finishedAt: Date = Date(),
        slotLengthSeconds: Int? = nil,
        additionalOccupiedIntervals: [DateInterval] = []
    ) -> Int {
        guard let startedAt = activeDayStartedAt else {
            return 0
        }
        let daySlotLengthSeconds = activeDaySlotLengthSeconds ?? slotLengthSeconds ?? Self.defaultDaySlotLengthSeconds

        activeDayStartedAt = nil
        activeDaySlotLengthSeconds = nil
        saveDayState()

        guard finishedAt > startedAt else {
            return 0
        }

        let generatedSessions = untrackedSessions(
            from: startedAt,
            to: finishedAt,
            slotLengthSeconds: daySlotLengthSeconds,
            additionalOccupiedIntervals: additionalOccupiedIntervals
        )

        guard !generatedSessions.isEmpty else {
            return 0
        }

        sessions.append(contentsOf: generatedSessions)
        sessions.sort { $0.startedAt < $1.startedAt }
        save()
        return generatedSessions.count
    }

    @discardableResult
    func finishExpiredActiveDay(
        now: Date = Date(),
        calendar: Calendar = .current,
        additionalOccupiedIntervals: [DateInterval] = []
    ) -> Int {
        guard
            let startedAt = activeDayStartedAt,
            let finishedAt = activeDayEnd(for: startedAt, calendar: calendar),
            now >= finishedAt
        else {
            return 0
        }

        return finishDay(
            at: finishedAt,
            additionalOccupiedIntervals: additionalOccupiedIntervals
        )
    }

    func totalFocusedSeconds(on date: Date, calendar: Calendar = .current) -> Int {
        sessions
            .filter { $0.kind == .focused && calendar.isDate($0.startedAt, inSameDayAs: date) }
            .map(\.durationSeconds)
            .reduce(0, +)
    }

    func totalFocusedSecondsThisWeek(now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }

        return sessions
            .filter { $0.kind == .focused && week.contains($0.startedAt) }
            .map(\.durationSeconds)
            .reduce(0, +)
    }

    private func untrackedSessions(
        from startedAt: Date,
        to finishedAt: Date,
        slotLengthSeconds: Int,
        idProvider: (Date, Date) -> UUID = { _, _ in UUID() },
        additionalOccupiedIntervals: [DateInterval] = []
    ) -> [FocusSession] {
        let slotLength = TimeInterval(max(1, slotLengthSeconds))
        let occupied = mergedOccupiedIntervals(
            from: startedAt,
            to: finishedAt,
            additionalOccupiedIntervals: additionalOccupiedIntervals
        )
        var generated: [FocusSession] = []
        var cursor = startedAt

        func appendSlots(from gapStart: Date, to gapEnd: Date) {
            var slotStart = gapStart
            while slotStart < gapEnd {
                let proposedEnd = slotStart.addingTimeInterval(slotLength)
                let slotEnd = minDate(proposedEnd, gapEnd)
                guard slotEnd > slotStart else {
                    break
                }

                generated.append(FocusSession(
                    id: idProvider(slotStart, slotEnd),
                    topic: nil,
                    startedAt: slotStart,
                    endedAt: slotEnd,
                    kind: .untracked
                ))
                slotStart = slotEnd
            }
        }

        for interval in occupied {
            if cursor < interval.start {
                appendSlots(from: cursor, to: interval.start)
            }

            if cursor < interval.end {
                cursor = interval.end
            }
        }

        if cursor < finishedAt {
            appendSlots(from: cursor, to: finishedAt)
        }

        return generated
    }

    private func deterministicSlotID(startedAt: Date, endedAt: Date) -> UUID {
        let startMillis = UInt64(bitPattern: Int64((startedAt.timeIntervalSince1970 * 1_000).rounded()))
        let endMillis = UInt64(bitPattern: Int64((endedAt.timeIntervalSince1970 * 1_000).rounded()))
        let uuidString = String(
            format: "%08llX-%04llX-%04llX-%04llX-%012llX",
            startMillis & 0xFFFF_FFFF,
            (startMillis >> 32) & 0xFFFF,
            (startMillis >> 48) & 0xFFFF,
            endMillis & 0xFFFF,
            (endMillis >> 16) & 0xFFFF_FFFF_FFFF
        )

        return UUID(uuidString: uuidString) ?? UUID()
    }

    private func mergedOccupiedIntervals(
        from startedAt: Date,
        to finishedAt: Date,
        additionalOccupiedIntervals: [DateInterval] = []
    ) -> [(start: Date, end: Date)] {
        let sessionIntervals = sessions.compactMap { session -> (start: Date, end: Date)? in
            let start = maxDate(session.startedAt, startedAt)
            let end = minDate(session.endedAt, finishedAt)
            guard end > start else {
                return nil
            }
            return (start, end)
        }

        let reservedIntervals = additionalOccupiedIntervals.compactMap { interval -> (start: Date, end: Date)? in
            let start = maxDate(interval.start, startedAt)
            let end = minDate(interval.end, finishedAt)
            guard end > start else {
                return nil
            }
            return (start, end)
        }

        let intervals = (sessionIntervals + reservedIntervals)
            .sorted { $0.start < $1.start }

        return intervals.reduce(into: []) { merged, interval in
            guard let last = merged.last else {
                merged.append(interval)
                return
            }

            if interval.start <= last.end {
                merged[merged.count - 1].end = maxDate(last.end, interval.end)
            } else {
                merged.append(interval)
            }
        }
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

    private func loadDayState() {
        guard FileManager.default.fileExists(atPath: dayStateURL.path) else {
            activeDayStartedAt = nil
            activeDaySlotLengthSeconds = nil
            return
        }

        do {
            let data = try Data(contentsOf: dayStateURL)
            let state = try decoder.decode(DayState.self, from: data)
            activeDayStartedAt = state.startedAt
            activeDaySlotLengthSeconds = state.slotLengthSeconds
        } catch {
            activeDayStartedAt = nil
            activeDaySlotLengthSeconds = nil
            NSLog("Fractal could not load active day state: \(error.localizedDescription)")
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

    private func saveDayState() {
        do {
            try FileManager.default.createDirectory(
                at: dayStateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            guard let activeDayStartedAt else {
                activeDaySlotLengthSeconds = nil
                if FileManager.default.fileExists(atPath: dayStateURL.path) {
                    try FileManager.default.removeItem(at: dayStateURL)
                }
                return
            }

            let data = try encoder.encode(DayState(
                startedAt: activeDayStartedAt,
                slotLengthSeconds: activeDaySlotLengthSeconds ?? Self.defaultDaySlotLengthSeconds
            ))
            try data.write(to: dayStateURL, options: .atomic)
        } catch {
            NSLog("Fractal could not save active day state: \(error.localizedDescription)")
        }
    }

    private func minDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs < rhs ? lhs : rhs
    }

    private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
        lhs > rhs ? lhs : rhs
    }

    private func activeDayEnd(for startedAt: Date, calendar: Calendar) -> Date? {
        calendar.dateInterval(of: .day, for: startedAt)?.end
    }

    private struct DayState: Codable {
        let startedAt: Date
        let slotLengthSeconds: Int?
    }
}
