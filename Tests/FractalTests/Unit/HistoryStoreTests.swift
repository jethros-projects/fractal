@testable import FractalCore
import XCTest

final class HistoryStoreTests: XCTestCase {
    func testMissingHistoryFileLoadsEmptySessions() async {
        await MainActor.run {
            let store = HistoryStore(fileURL: temporaryHistoryURL())

            XCTAssertTrue(store.sessions.isEmpty)
            XCTAssertTrue(store.sessionsNewestFirst.isEmpty)
        }
    }

    func testAppendAddsSessionInMemory() async {
        await MainActor.run {
            let store = HistoryStore(fileURL: temporaryHistoryURL())
            let session = makeSession(topic: "Planning", start: 100, end: 1_000)

            store.append(session)

            XCTAssertEqual(store.sessions, [session])
        }
    }

    func testAppendPersistsSessionToDisk() async {
        await MainActor.run {
            let url = temporaryHistoryURL()
            let store = HistoryStore(fileURL: url)
            let session = makeSession(topic: "Writing", start: 100, end: 1_000)

            store.append(session)
            let reloaded = HistoryStore(fileURL: url)

            XCTAssertEqual(reloaded.sessions, [session])
        }
    }

    func testAppendSortsSessionsChronologicallyByStartTime() async {
        await MainActor.run {
            let store = HistoryStore(fileURL: temporaryHistoryURL())
            let latest = makeSession(topic: "Latest", start: 300, end: 400)
            let earliest = makeSession(topic: "Earliest", start: 100, end: 200)
            let middle = makeSession(topic: "Middle", start: 200, end: 300)

            store.append(latest)
            store.append(earliest)
            store.append(middle)

            XCTAssertEqual(store.sessions.map(\.topicDisplayName), ["Earliest", "Middle", "Latest"])
        }
    }

    func testSessionsNewestFirstSortsByEndTimeDescending() async {
        await MainActor.run {
            let store = HistoryStore(fileURL: temporaryHistoryURL())
            let firstEnded = makeSession(topic: "First", start: 100, end: 200)
            let lastEnded = makeSession(topic: "Last", start: 200, end: 500)
            let middleEnded = makeSession(topic: "Middle", start: 150, end: 300)

            store.append(firstEnded)
            store.append(lastEnded)
            store.append(middleEnded)

            XCTAssertEqual(store.sessionsNewestFirst.map(\.topicDisplayName), ["Last", "Middle", "First"])
        }
    }

    func testMalformedHistoryFileLoadsAsEmptyInsteadOfThrowing() async throws {
        try await MainActor.run {
            let url = temporaryHistoryURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("not json".utf8).write(to: url)

            let store = HistoryStore(fileURL: url)

            XCTAssertTrue(store.sessions.isEmpty)
        }
    }

    func testTodayTotalIncludesOnlySessionsStartingOnThatDay() async {
        await MainActor.run {
            let store = HistoryStore(fileURL: temporaryHistoryURL())
            let calendar = utcCalendar()
            let targetDay = date(year: 2026, month: 5, day: 19, hour: 12)

            store.append(FocusSession(
                topic: "Morning",
                durationSeconds: 900,
                startedAt: date(year: 2026, month: 5, day: 19, hour: 9),
                endedAt: date(year: 2026, month: 5, day: 19, hour: 9, minute: 15)
            ))
            store.append(FocusSession(
                topic: "Afternoon",
                durationSeconds: 1_500,
                startedAt: date(year: 2026, month: 5, day: 19, hour: 14),
                endedAt: date(year: 2026, month: 5, day: 19, hour: 14, minute: 25)
            ))
            store.append(FocusSession(
                topic: "Yesterday",
                durationSeconds: 3_600,
                startedAt: date(year: 2026, month: 5, day: 18, hour: 14),
                endedAt: date(year: 2026, month: 5, day: 18, hour: 15)
            ))

            XCTAssertEqual(store.totalFocusedSeconds(on: targetDay, calendar: calendar), 2_400)
        }
    }

    func testThisWeekTotalIncludesOnlyCurrentWeekSessions() async {
        await MainActor.run {
            let store = HistoryStore(fileURL: temporaryHistoryURL())
            let calendar = utcCalendar()

            store.append(FocusSession(
                topic: "Tuesday",
                durationSeconds: 900,
                startedAt: date(year: 2026, month: 5, day: 19, hour: 9),
                endedAt: date(year: 2026, month: 5, day: 19, hour: 9, minute: 15)
            ))
            store.append(FocusSession(
                topic: "Friday",
                durationSeconds: 1_800,
                startedAt: date(year: 2026, month: 5, day: 22, hour: 10),
                endedAt: date(year: 2026, month: 5, day: 22, hour: 10, minute: 30)
            ))
            store.append(FocusSession(
                topic: "Prior week",
                durationSeconds: 7_200,
                startedAt: date(year: 2026, month: 5, day: 12, hour: 10),
                endedAt: date(year: 2026, month: 5, day: 12, hour: 12)
            ))

            XCTAssertEqual(
                store.totalFocusedSecondsThisWeek(
                    now: date(year: 2026, month: 5, day: 20, hour: 12),
                    calendar: calendar
                ),
                2_700
            )
        }
    }

    func testAppendingAfterMalformedLoadOverwritesWithValidHistory() async {
        await MainActor.run {
            let url = temporaryHistoryURL()
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? Data("bad".utf8).write(to: url)

            let store = HistoryStore(fileURL: url)
            let session = makeSession(topic: "Recovered", start: 10, end: 910)
            store.append(session)

            XCTAssertEqual(HistoryStore(fileURL: url).sessions, [session])
        }
    }

    private func makeSession(topic: String, start: TimeInterval, end: TimeInterval) -> FocusSession {
        FocusSession(
            topic: topic,
            durationSeconds: Int(end - start),
            startedAt: Date(timeIntervalSince1970: start),
            endedAt: Date(timeIntervalSince1970: end)
        )
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.calendar = utcCalendar()
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}
