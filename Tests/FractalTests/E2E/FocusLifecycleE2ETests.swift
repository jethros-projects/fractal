@testable import FractalCore
import Testing
import Foundation

struct FocusLifecycleE2ETests {
    @MainActor
    @Test
    func testE2ECompleteSingleBlockAndPersistHistory() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let rig = makeRig(blockLengthMinutes: 15, now: start)
        var completionPromptSessions: [FocusSession] = []
        rig.timer.onBlockCompleted = { completionPromptSessions.append($0) }

        rig.timer.topic = "Draft launch plan"
        rig.timer.startOrResume()
        rig.timeSource.advance(by: 15 * 60)
        rig.tickerScheduler.fireAll()

        XCTAssertEqual(rig.timer.state, .completed)
        XCTAssertEqual(rig.timer.remainingSeconds, 0)
        XCTAssertEqual(completionPromptSessions.count, 1)
        XCTAssertEqual(rig.historyStore.sessions.count, 1)

        let session = rig.historyStore.sessions[0]
        XCTAssertEqual(session.topic, "Draft launch plan")
        XCTAssertEqual(session.durationSeconds, 900)
        XCTAssertEqual(session.startedAt, start)
        XCTAssertEqual(session.endedAt, start.addingTimeInterval(900))

        let reloadedHistory = HistoryStore(fileURL: rig.historyFileURL)
        XCTAssertEqual(reloadedHistory.sessions, [session])
    }

    @MainActor
    @Test
    func testE2EContinueRestartsSameTopicAndLogsTwoBlocks() {
        let rig = makeRig(blockLengthMinutes: 10)

        rig.timer.topic = "Architecture"
        completeCurrentBlock(rig)

        rig.timer.continueCurrentTopic(shouldStart: true)
        XCTAssertEqual(rig.timer.topic, "Architecture")
        XCTAssertEqual(rig.timer.state, .running)
        XCTAssertEqual(rig.timer.remainingSeconds, 600)

        completeCurrentBlock(rig)

        XCTAssertEqual(rig.historyStore.sessions.count, 2)
        XCTAssertEqual(rig.historyStore.sessions.map(\.topicDisplayName), ["Architecture", "Architecture"])
        XCTAssertEqual(rig.historyStore.sessions.map(\.durationSeconds), [600, 600])
    }

    @MainActor
    @Test
    func testE2EContinueCanPrepareNextBlockWithoutAutoStarting() {
        let rig = makeRig(blockLengthMinutes: 25)
        rig.settings.autoStartAfterContinue = false

        rig.timer.topic = "Strategy"
        completeCurrentBlock(rig)
        rig.timer.continueCurrentTopic(shouldStart: rig.settings.autoStartAfterContinue)

        XCTAssertEqual(rig.historyStore.sessions.count, 1)
        XCTAssertEqual(rig.timer.topic, "Strategy")
        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 1_500)
        XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
    }

    @MainActor
    @Test
    func testE2ESwitchStartsNewTopicAndLogsDistinctSessions() {
        let rig = makeRig(blockLengthMinutes: 5)

        rig.timer.topic = "Inbox triage"
        completeCurrentBlock(rig)
        rig.timer.startNewBlock(topic: "Deep writing", shouldStart: true)
        completeCurrentBlock(rig)

        XCTAssertEqual(rig.historyStore.sessions.count, 2)
        XCTAssertEqual(rig.historyStore.sessions[0].topic, "Inbox triage")
        XCTAssertEqual(rig.historyStore.sessions[1].topic, "Deep writing")
        XCTAssertEqual(rig.historyStore.sessions.map(\.durationSeconds), [300, 300])
    }

    @MainActor
    @Test
    func testE2ESwitchCanSetTopicWithoutStartingNextBlock() {
        let rig = makeRig(blockLengthMinutes: 15)

        rig.timer.topic = "Design review"
        completeCurrentBlock(rig)
        rig.timer.startNewBlock(topic: "Implementation", shouldStart: false)

        XCTAssertEqual(rig.historyStore.sessions.count, 1)
        XCTAssertEqual(rig.historyStore.sessions[0].topic, "Design review")
        XCTAssertEqual(rig.timer.topic, "Implementation")
        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 900)
    }

    @MainActor
    @Test
    func testE2ELogOnlyKeepsCompletedSessionAndStopsThere() {
        let rig = makeRig(blockLengthMinutes: 15)

        rig.timer.topic = "Planning"
        completeCurrentBlock(rig)
        rig.timer.logOnlyAfterCompletion()

        XCTAssertEqual(rig.historyStore.sessions.count, 1)
        XCTAssertEqual(rig.historyStore.sessions[0].topic, "Planning")
        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 900)
        XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
    }

    @MainActor
    @Test
    func testE2EPauseResumeCompletesOnlyAfterRemainingActiveTime() {
        let start = Date(timeIntervalSince1970: 3_000_000)
        let rig = makeRig(blockLengthMinutes: 1, now: start)

        rig.timer.topic = "Careful work"
        rig.timer.startOrResume()
        rig.timeSource.advance(by: 20)
        rig.tickerScheduler.fireAll()
        rig.timer.pause()

        rig.timeSource.advance(by: 600)
        rig.tickerScheduler.fireAll()
        XCTAssertEqual(rig.timer.state, .paused)
        XCTAssertEqual(rig.historyStore.sessions.count, 0)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 39)
        rig.tickerScheduler.fireAll()
        XCTAssertEqual(rig.timer.state, .running)
        XCTAssertEqual(rig.historyStore.sessions.count, 0)

        rig.timeSource.advance(by: 1)
        rig.tickerScheduler.fireAll()

        XCTAssertEqual(rig.timer.state, .completed)
        XCTAssertEqual(rig.historyStore.sessions.count, 1)
        XCTAssertEqual(rig.historyStore.sessions[0].durationSeconds, 60)
        XCTAssertEqual(rig.historyStore.sessions[0].startedAt, start)
        XCTAssertEqual(rig.historyStore.sessions[0].endedAt, start.addingTimeInterval(660))
    }

    @MainActor
    @Test
    func testE2EHistoryTotalsUpdateAcrossTodayAndThisWeek() {
        let calendar = utcCalendar()
        let rig = makeRig(
            blockLengthMinutes: 15,
            now: date(year: 2026, month: 5, day: 19, hour: 9)
        )

        rig.timer.topic = "Morning"
        completeCurrentBlock(rig)

        rig.timeSource.advance(by: 3 * 60 * 60)
        rig.timer.startNewBlock(topic: "Midday", shouldStart: true)
        completeCurrentBlock(rig)

        XCTAssertEqual(
            rig.historyStore.totalFocusedSeconds(
                on: date(year: 2026, month: 5, day: 19, hour: 18),
                calendar: calendar
            ),
            1_800
        )
        XCTAssertEqual(
            rig.historyStore.totalFocusedSecondsThisWeek(
                now: date(year: 2026, month: 5, day: 20, hour: 12),
                calendar: calendar
            ),
            1_800
        )
    }

    @MainActor
    @Test
    func testE2EChangingBlockLengthAffectsNextBlockAfterCurrentCompletion() async {
        let rig = makeRig(blockLengthMinutes: 15)

        rig.timer.topic = "Original length"
        rig.timer.startOrResume()
        rig.settings.blockLengthMinutes = 30
        await Task.yield()

        completeCurrentBlock(rig)
        rig.timer.continueCurrentTopic(shouldStart: true)

        XCTAssertEqual(rig.historyStore.sessions[0].durationSeconds, 900)
        XCTAssertEqual(rig.timer.remainingSeconds, 1_800)
    }

    @MainActor
    @Test
    func testE2EBlankTopicIsSavedAsNoTopicSession() {
        let rig = makeRig(blockLengthMinutes: 5)

        rig.timer.topic = "  "
        completeCurrentBlock(rig)

        XCTAssertEqual(rig.historyStore.sessions.count, 1)
        XCTAssertNil(rig.historyStore.sessions[0].topic)
        XCTAssertEqual(rig.historyStore.sessions[0].topicDisplayName, "No topic set")
    }

    @MainActor
    private func completeCurrentBlock(_ rig: TestRig) {
        if rig.timer.state != .running {
            rig.timer.startOrResume()
        }

        rig.timeSource.advance(by: TimeInterval(rig.timer.remainingSeconds))
        rig.tickerScheduler.fireAll()
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
