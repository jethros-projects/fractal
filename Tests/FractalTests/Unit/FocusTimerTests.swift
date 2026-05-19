@testable import FractalCore
import XCTest

final class FocusTimerTests: XCTestCase {
    @MainActor
    func testInitialStateUsesConfiguredDuration() {
        let rig = makeRig(blockLengthMinutes: 20)

        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 1_200)
        XCTAssertEqual(rig.timer.displayClock, "20:00")
        XCTAssertEqual(rig.timer.progress, 0)
        XCTAssertFalse(rig.timer.isActive)
    }

    @MainActor
    func testTopicDisplayNameFallsBackWhenEmpty() {
        let rig = makeRig()

        rig.timer.topic = "   "

        XCTAssertEqual(rig.timer.topicDisplayName, "No topic set")
    }

    @MainActor
    func testTopicDisplayNameTrimsWhitespace() {
        let rig = makeRig()

        rig.timer.topic = "  Research  "

        XCTAssertEqual(rig.timer.topicDisplayName, "Research")
    }

    @MainActor
    func testStartBeginsRunningAndSchedulesTicker() {
        let rig = makeRig(blockLengthMinutes: 15)

        rig.timer.topic = "Writing"
        rig.timer.startOrResume()

        XCTAssertEqual(rig.timer.state, .running)
        XCTAssertEqual(rig.timer.remainingSeconds, 900)
        XCTAssertTrue(rig.timer.isActive)
        XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 1)
        XCTAssertEqual(rig.tickerScheduler.tokens.first?.interval, 0.25)
    }

    @MainActor
    func testStartWhileRunningIsNoOp() {
        let rig = makeRig(blockLengthMinutes: 15)

        rig.timer.startOrResume()
        rig.timer.startOrResume()

        XCTAssertEqual(rig.tickerScheduler.tokens.count, 1)
        XCTAssertEqual(rig.timer.state, .running)
    }

    @MainActor
    func testManualTickUpdatesRemainingSeconds() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 17.2)
        rig.tickerScheduler.fireAll()

        XCTAssertEqual(rig.timer.remainingSeconds, 43)
        XCTAssertEqual(rig.timer.displayClock, "00:43")
        XCTAssertEqual(rig.timer.state, .running)
    }

    @MainActor
    func testPauseCapturesRemainingTimeAndInvalidatesTicker() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 22.1)
        rig.timer.pause()

        XCTAssertEqual(rig.timer.state, .paused)
        XCTAssertEqual(rig.timer.remainingSeconds, 38)
        XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
    }

    @MainActor
    func testPauseWhenIdleIsNoOp() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.pause()

        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 60)
    }

    @MainActor
    func testResumeAfterPauseCreatesFreshTicker() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 10)
        rig.timer.pause()
        rig.timer.startOrResume()

        XCTAssertEqual(rig.timer.state, .running)
        XCTAssertEqual(rig.timer.remainingSeconds, 50)
        XCTAssertEqual(rig.tickerScheduler.tokens.count, 2)
        XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 1)
    }

    @MainActor
    func testResetReturnsToIdleAndConfiguredDuration() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 10)
        rig.tickerScheduler.fireAll()
        rig.timer.reset()

        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 60)
        XCTAssertEqual(rig.timer.progress, 0)
        XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
    }

    @MainActor
    func testStartNewBlockCanPrepareWithoutStarting() {
        let rig = makeRig(blockLengthMinutes: 10)

        rig.timer.startNewBlock(topic: "Planning", shouldStart: false)

        XCTAssertEqual(rig.timer.topic, "Planning")
        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 600)
        XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
    }

    @MainActor
    func testStartNewBlockCanStartImmediately() {
        let rig = makeRig(blockLengthMinutes: 10)

        rig.timer.startNewBlock(topic: "Planning", shouldStart: true)

        XCTAssertEqual(rig.timer.topic, "Planning")
        XCTAssertEqual(rig.timer.state, .running)
        XCTAssertEqual(rig.timer.remainingSeconds, 600)
        XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 1)
    }

    @MainActor
    func testCompletionCreatesHistorySessionAndCallback() {
        let rig = makeRig(blockLengthMinutes: 1)
        var completedSessions: [FocusSession] = []
        rig.timer.onBlockCompleted = { completedSessions.append($0) }

        rig.timer.topic = "Ship tests"
        rig.timer.startOrResume()
        rig.timeSource.advance(by: 60)
        rig.tickerScheduler.fireAll()

        XCTAssertEqual(rig.timer.state, .completed)
        XCTAssertEqual(rig.timer.remainingSeconds, 0)
        XCTAssertEqual(rig.historyStore.sessions.count, 1)
        XCTAssertEqual(completedSessions.count, 1)
        XCTAssertEqual(rig.historyStore.sessions.first?.topic, "Ship tests")
        XCTAssertEqual(rig.historyStore.sessions.first?.durationSeconds, 60)
    }

    @MainActor
    func testCompletionUsesConfiguredStartAndEndTimes() {
        let start = Date(timeIntervalSince1970: 123_456)
        let rig = makeRig(blockLengthMinutes: 1, now: start)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 60)
        rig.tickerScheduler.fireAll()

        let session = rig.historyStore.sessions.first
        XCTAssertEqual(session?.startedAt, start)
        XCTAssertEqual(session?.endedAt, start.addingTimeInterval(60))
    }

    @MainActor
    func testCompletionOnlyHappensOnceWhenTickerFiresAgain() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 60)
        rig.tickerScheduler.fireAll()
        rig.timeSource.advance(by: 60)
        rig.tickerScheduler.fireAll()

        XCTAssertEqual(rig.historyStore.sessions.count, 1)
        XCTAssertEqual(rig.timer.state, .completed)
    }

    @MainActor
    func testLogOnlyAfterCompletionReturnsToIdleWithoutAddingSession() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 60)
        rig.tickerScheduler.fireAll()
        rig.timer.logOnlyAfterCompletion()

        XCTAssertEqual(rig.historyStore.sessions.count, 1)
        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 60)
    }

    @MainActor
    func testMenuBarTitleShowsSecondsWhenEnabled() {
        let rig = makeRig(blockLengthMinutes: 15)

        XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: true), "15:00")
    }

    @MainActor
    func testMenuBarTitleRoundsUpMinutesWhenSecondsAreHidden() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 1)
        rig.tickerScheduler.fireAll()

        XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: false), "1m")
    }

    @MainActor
    func testMenuBarTitleShowsZeroMinutesAtCompletionWhenSecondsAreHidden() {
        let rig = makeRig(blockLengthMinutes: 1)

        rig.timer.startOrResume()
        rig.timeSource.advance(by: 60)
        rig.tickerScheduler.fireAll()

        XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: false), "0m")
    }

    @MainActor
    func testMenuBarTitleFormatsHoursWhenSecondsAreHidden() {
        let rig = makeRig(blockLengthMinutes: 75)

        XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: false), "1h 15m")
    }

    @MainActor
    func testMenuBarTitleFormatsWholeHoursWhenSecondsAreHidden() {
        let rig = makeRig(blockLengthMinutes: 60)

        XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: false), "1h")
    }

    @MainActor
    func testSettingsChangeWhileIdleUpdatesRemainingDuration() async {
        let rig = makeRig(blockLengthMinutes: 15)

        rig.settings.blockLengthMinutes = 25
        await Task.yield()

        XCTAssertEqual(rig.timer.state, .idle)
        XCTAssertEqual(rig.timer.remainingSeconds, 1_500)
    }

    @MainActor
    func testSettingsChangeWhileRunningDoesNotMutateActiveBlock() async {
        let rig = makeRig(blockLengthMinutes: 15)

        rig.timer.startOrResume()
        rig.settings.blockLengthMinutes = 25
        await Task.yield()

        XCTAssertEqual(rig.timer.state, .running)
        XCTAssertEqual(rig.timer.remainingSeconds, 900)
    }

    @MainActor
    func testUpdateCallbackFiresForObservableChanges() {
        let rig = makeRig()
        var updateCount = 0
        rig.timer.onUpdate = { updateCount += 1 }

        rig.timer.topic = "Design"
        rig.timer.startOrResume()
        rig.timeSource.advance(by: 10)
        rig.tickerScheduler.fireAll()

        XCTAssertGreaterThanOrEqual(updateCount, 3)
    }
}
