@testable import FractalCore
import XCTest

final class FocusTimerTests: XCTestCase {
    func testInitialStateUsesConfiguredDuration() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 20)

            XCTAssertEqual(rig.timer.state, .idle)
            XCTAssertEqual(rig.timer.remainingSeconds, 1_200)
            XCTAssertEqual(rig.timer.displayClock, "20:00")
            XCTAssertEqual(rig.timer.progress, 0)
            XCTAssertFalse(rig.timer.isActive)
        }
    }

    func testTopicDisplayNameFallsBackWhenEmpty() async {
        await MainActor.run {
            let rig = makeRig()

            rig.timer.topic = "   "

            XCTAssertEqual(rig.timer.topicDisplayName, "No topic set")
        }
    }

    func testTopicDisplayNameTrimsWhitespace() async {
        await MainActor.run {
            let rig = makeRig()

            rig.timer.topic = "  Research  "

            XCTAssertEqual(rig.timer.topicDisplayName, "Research")
        }
    }

    func testStartBeginsRunningAndSchedulesTicker() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 15)

            rig.timer.topic = "Writing"
            rig.timer.startOrResume()

            XCTAssertEqual(rig.timer.state, .running)
            XCTAssertEqual(rig.timer.remainingSeconds, 900)
            XCTAssertTrue(rig.timer.isActive)
            XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 1)
            XCTAssertEqual(rig.tickerScheduler.tokens.first?.interval, 0.25)
        }
    }

    func testStartWhileRunningIsNoOp() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 15)

            rig.timer.startOrResume()
            rig.timer.startOrResume()

            XCTAssertEqual(rig.tickerScheduler.tokens.count, 1)
            XCTAssertEqual(rig.timer.state, .running)
        }
    }

    func testManualTickUpdatesRemainingSeconds() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.startOrResume()
            rig.timeSource.advance(by: 17.2)
            rig.tickerScheduler.fireAll()

            XCTAssertEqual(rig.timer.remainingSeconds, 43)
            XCTAssertEqual(rig.timer.displayClock, "00:43")
            XCTAssertEqual(rig.timer.state, .running)
        }
    }

    func testPauseCapturesRemainingTimeAndInvalidatesTicker() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.startOrResume()
            rig.timeSource.advance(by: 22.1)
            rig.timer.pause()

            XCTAssertEqual(rig.timer.state, .paused)
            XCTAssertEqual(rig.timer.remainingSeconds, 38)
            XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
        }
    }

    func testPauseWhenIdleIsNoOp() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.pause()

            XCTAssertEqual(rig.timer.state, .idle)
            XCTAssertEqual(rig.timer.remainingSeconds, 60)
        }
    }

    func testResumeAfterPauseCreatesFreshTicker() async {
        await MainActor.run {
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
    }

    func testResetReturnsToIdleAndConfiguredDuration() async {
        await MainActor.run {
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
    }

    func testTerminateCurrentBlockCancelsRunningBlockWithoutHistory() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.topic = "Wrong thing"
            rig.timer.startOrResume()
            rig.timeSource.advance(by: 20)
            rig.timer.terminateCurrentBlock()

            XCTAssertEqual(rig.timer.state, .idle)
            XCTAssertEqual(rig.timer.remainingSeconds, 60)
            XCTAssertEqual(rig.timer.progress, 0)
            XCTAssertFalse(rig.timer.canTerminateCurrentBlock)
            XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
            XCTAssertTrue(rig.historyStore.sessions.isEmpty)
        }
    }

    func testTerminateCurrentBlockCancelsPausedBlockWithoutHistory() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.startOrResume()
            rig.timeSource.advance(by: 20)
            rig.timer.pause()
            rig.timer.terminateCurrentBlock()

            XCTAssertEqual(rig.timer.state, .idle)
            XCTAssertEqual(rig.timer.remainingSeconds, 60)
            XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
            XCTAssertTrue(rig.historyStore.sessions.isEmpty)
        }
    }

    func testStartNewBlockCanPrepareWithoutStarting() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 10)

            rig.timer.startNewBlock(topic: "Planning", shouldStart: false)

            XCTAssertEqual(rig.timer.topic, "Planning")
            XCTAssertEqual(rig.timer.state, .idle)
            XCTAssertEqual(rig.timer.remainingSeconds, 600)
            XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 0)
        }
    }

    func testStartNewBlockCanStartImmediately() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 10)

            rig.timer.startNewBlock(topic: "Planning", shouldStart: true)

            XCTAssertEqual(rig.timer.topic, "Planning")
            XCTAssertEqual(rig.timer.state, .running)
            XCTAssertEqual(rig.timer.remainingSeconds, 600)
            XCTAssertEqual(rig.tickerScheduler.activeTokenCount, 1)
        }
    }

    func testCompletionCreatesHistorySessionAndCallback() async {
        await MainActor.run {
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
    }

    func testCompletionUsesConfiguredStartAndEndTimes() async {
        await MainActor.run {
            let start = Date(timeIntervalSince1970: 123_456)
            let rig = makeRig(blockLengthMinutes: 1, now: start)

            rig.timer.startOrResume()
            rig.timeSource.advance(by: 60)
            rig.tickerScheduler.fireAll()

            let session = rig.historyStore.sessions.first
            XCTAssertEqual(session?.startedAt, start)
            XCTAssertEqual(session?.endedAt, start.addingTimeInterval(60))
        }
    }

    func testCompletionOnlyHappensOnceWhenTickerFiresAgain() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.startOrResume()
            rig.timeSource.advance(by: 60)
            rig.tickerScheduler.fireAll()
            rig.timeSource.advance(by: 60)
            rig.tickerScheduler.fireAll()

            XCTAssertEqual(rig.historyStore.sessions.count, 1)
            XCTAssertEqual(rig.timer.state, .completed)
        }
    }

    func testLogOnlyAfterCompletionReturnsToIdleWithoutAddingSession() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.startOrResume()
            rig.timeSource.advance(by: 60)
            rig.tickerScheduler.fireAll()
            rig.timer.logOnlyAfterCompletion()

            XCTAssertEqual(rig.historyStore.sessions.count, 1)
            XCTAssertEqual(rig.timer.state, .idle)
            XCTAssertEqual(rig.timer.remainingSeconds, 60)
        }
    }

    func testMenuBarTitleShowsSecondsWhenEnabled() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 15)

            XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: true), "15:00")
        }
    }

    func testMenuBarTitleRoundsUpMinutesWhenSecondsAreHidden() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.startOrResume()
            rig.timeSource.advance(by: 1)
            rig.tickerScheduler.fireAll()

            XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: false), "1m")
        }
    }

    func testMenuBarTitleShowsZeroMinutesAtCompletionWhenSecondsAreHidden() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 1)

            rig.timer.startOrResume()
            rig.timeSource.advance(by: 60)
            rig.tickerScheduler.fireAll()

            XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: false), "0m")
        }
    }

    func testMenuBarTitleFormatsHoursWhenSecondsAreHidden() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 75)

            XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: false), "1h 15m")
        }
    }

    func testMenuBarTitleFormatsWholeHoursWhenSecondsAreHidden() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 60)

            XCTAssertEqual(rig.timer.menuBarTitle(showSeconds: false), "1h")
        }
    }

    func testSettingsChangeWhileIdleUpdatesRemainingDuration() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 15)

            rig.settings.blockLengthMinutes = 25

            XCTAssertEqual(rig.timer.state, .idle)
            XCTAssertEqual(rig.timer.remainingSeconds, 1_500)
        }
    }

    func testSettingsChangeWhileRunningDoesNotMutateActiveBlock() async {
        await MainActor.run {
            let rig = makeRig(blockLengthMinutes: 15)

            rig.timer.startOrResume()
            rig.settings.blockLengthMinutes = 25

            XCTAssertEqual(rig.timer.state, .running)
            XCTAssertEqual(rig.timer.remainingSeconds, 900)
        }
    }

    func testUpdateCallbackFiresForObservableChanges() async {
        await MainActor.run {
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
}
