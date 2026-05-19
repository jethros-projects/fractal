@testable import FractalCore
import Foundation
import XCTest

final class TestTimeSource: FractalTimeSource {
    private(set) var now: Date

    init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}

@MainActor
final class ManualTickerScheduler: FractalTickerScheduling {
    private(set) var tokens: [ManualTickerToken] = []

    var activeTokenCount: Int {
        tokens.filter { !$0.isInvalidated }.count
    }

    func schedule(
        repeatingEvery interval: TimeInterval,
        _ handler: @escaping @MainActor () -> Void
    ) -> FractalTickerToken {
        let token = ManualTickerToken(interval: interval, handler: handler)
        tokens.append(token)
        return token
    }

    func fireAll() {
        for token in tokens where !token.isInvalidated {
            token.fire()
        }
    }
}

@MainActor
final class ManualTickerToken: FractalTickerToken {
    let interval: TimeInterval
    private let handler: @MainActor () -> Void
    private(set) var isInvalidated = false

    init(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        self.interval = interval
        self.handler = handler
    }

    func invalidate() {
        isInvalidated = true
    }

    func fire() {
        guard !isInvalidated else {
            return
        }

        handler()
    }
}

@MainActor
struct TestRig {
    let defaultsSuiteName: String
    let defaults: UserDefaults
    let historyFileURL: URL
    let settings: AppSettings
    let historyStore: HistoryStore
    let timeSource: TestTimeSource
    let tickerScheduler: ManualTickerScheduler
    let timer: FocusTimer
}

extension XCTestCase {
    func packageRootURL(filePath: String = #filePath) -> URL {
        var directory = URL(fileURLWithPath: filePath).deletingLastPathComponent()

        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: directory.appendingPathComponent("Package.swift").path) {
                return directory
            }
            directory.deleteLastPathComponent()
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    @MainActor
    func makeRig(
        blockLengthMinutes: Int = 15,
        now: Date = Date(timeIntervalSince1970: 1_700_000_000),
        function: String = #function
    ) -> TestRig {
        let suiteName = "app.fractal.tests.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(blockLengthMinutes, forKey: "blockLengthMinutes")

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FractalTests-\(UUID().uuidString)", isDirectory: true)
        let historyFileURL = tempDirectory.appendingPathComponent("sessions.json")

        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempDirectory)
        }

        let settings = AppSettings(defaults: defaults)
        let historyStore = HistoryStore(fileURL: historyFileURL)
        let timeSource = TestTimeSource(now: now)
        let tickerScheduler = ManualTickerScheduler()
        let timer = FocusTimer(
            settings: settings,
            historyStore: historyStore,
            timeSource: timeSource,
            tickerScheduler: tickerScheduler
        )

        return TestRig(
            defaultsSuiteName: suiteName,
            defaults: defaults,
            historyFileURL: historyFileURL,
            settings: settings,
            historyStore: historyStore,
            timeSource: timeSource,
            tickerScheduler: tickerScheduler,
            timer: timer
        )
    }

    func temporaryHistoryURL(function: String = #function) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FractalHistoryStoreTests-\(function)-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent("sessions.json")
    }

    func isolatedDefaults(function: String = #function) -> (UserDefaults, String) {
        let suiteName = "app.fractal.settings.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return (defaults, suiteName)
    }
}
