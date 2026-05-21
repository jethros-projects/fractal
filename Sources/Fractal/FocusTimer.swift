#if canImport(Combine)
import Combine
#endif
import Foundation

enum FocusTimerState: Equatable {
    case idle
    case running
    case paused
    case completed
}

@MainActor
final class FocusTimer: ObservableObject {
    @Published var state: FocusTimerState = .idle {
        didSet {
            notifyUpdate()
        }
    }

    @Published var topic: String = "" {
        didSet {
            notifyUpdate()
        }
    }

    @Published private(set) var remainingSeconds: Int {
        didSet {
            notifyUpdate()
        }
    }

    private let settings: AppSettings
    private let historyStore: HistoryStore
    private let timeSource: FractalTimeSource
    private let tickerScheduler: FractalTickerScheduling
    private var ticker: FractalTickerToken?
    private var deadline: Date?
    private var blockStartedAt: Date?
    private var activeBlockDurationSeconds: Int
    private var isFinishing = false

    var onUpdate: (() -> Void)?
    var onBlockCompleted: ((FocusSession) -> Void)?

    init(
        settings: AppSettings,
        historyStore: HistoryStore,
        timeSource: FractalTimeSource = SystemTimeSource(),
        tickerScheduler: FractalTickerScheduling = RunLoopTickerScheduler()
    ) {
        self.settings = settings
        self.historyStore = historyStore
        self.timeSource = timeSource
        self.tickerScheduler = tickerScheduler
        remainingSeconds = settings.blockLengthSeconds
        activeBlockDurationSeconds = settings.blockLengthSeconds

        settings.onBlockLengthMinutesChanged = { [weak self] in
            self?.syncDurationFromSettings()
        }
    }

    var isActive: Bool {
        state == .running || state == .paused || state == .completed
    }

    var canTerminateCurrentBlock: Bool {
        state == .running || state == .paused
    }

    var progress: Double {
        guard activeBlockDurationSeconds > 0 else {
            return 0
        }

        return 1 - (Double(remainingSeconds) / Double(activeBlockDurationSeconds))
    }

    var displayClock: String {
        Self.clockString(from: remainingSeconds, includeHoursWhenNeeded: true)
    }

    var topicDisplayName: String {
        topic.trimmedNonEmpty ?? "No topic set"
    }

    func currentBlockInterval(until date: Date = Date()) -> DateInterval? {
        guard canTerminateCurrentBlock, let blockStartedAt, date > blockStartedAt else {
            return nil
        }

        return DateInterval(start: blockStartedAt, end: date)
    }

    func startOrResume() {
        switch state {
        case .idle, .completed:
            startNewBlock(topic: topic, shouldStart: true)
        case .paused:
            resume()
        case .running:
            break
        }
    }

    func pause() {
        guard state == .running else {
            return
        }

        if let deadline {
            remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSince(timeSource.now))))
        }

        ticker?.invalidate()
        ticker = nil
        deadline = nil
        state = .paused
    }

    func reset() {
        terminateCurrentBlock()
    }

    func terminateCurrentBlock() {
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        blockStartedAt = nil
        activeBlockDurationSeconds = settings.blockLengthSeconds
        remainingSeconds = settings.blockLengthSeconds
        state = .idle
    }

    func startNewBlock(topic newTopic: String, shouldStart: Bool) {
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        blockStartedAt = nil
        activeBlockDurationSeconds = settings.blockLengthSeconds
        remainingSeconds = settings.blockLengthSeconds
        topic = newTopic
        state = .idle

        if shouldStart {
            beginRunning()
        }
    }

    func continueCurrentTopic(shouldStart: Bool) {
        startNewBlock(topic: topic, shouldStart: shouldStart)
    }

    func logOnlyAfterCompletion() {
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        blockStartedAt = nil
        activeBlockDurationSeconds = settings.blockLengthSeconds
        remainingSeconds = settings.blockLengthSeconds
        state = .idle
    }

    func menuBarTitle(showSeconds: Bool) -> String {
        if showSeconds {
            return Self.clockString(from: remainingSeconds, includeHoursWhenNeeded: false)
        }

        guard remainingSeconds > 0 else {
            return "0m"
        }

        let minutes = max(1, Int(ceil(Double(remainingSeconds) / 60.0)))
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }

        return "\(minutes)m"
    }

    private func resume() {
        guard remainingSeconds > 0 else {
            completeBlock()
            return
        }

        beginRunning()
    }

    private func beginRunning() {
        if blockStartedAt == nil {
            blockStartedAt = timeSource.now
        }

        state = .running
        deadline = timeSource.now.addingTimeInterval(TimeInterval(remainingSeconds))
        scheduleTicker()
        tick()
    }

    private func scheduleTicker() {
        ticker?.invalidate()
        ticker = tickerScheduler.schedule(repeatingEvery: 0.25) { [weak self] in
            self?.tick()
        }
    }

    private func tick() {
        guard state == .running, let deadline else {
            return
        }

        let secondsLeft = max(0, Int(ceil(deadline.timeIntervalSince(timeSource.now))))
        if secondsLeft != remainingSeconds {
            remainingSeconds = secondsLeft
        }

        if secondsLeft <= 0 {
            completeBlock()
        }
    }

    private func completeBlock() {
        guard !isFinishing else {
            return
        }

        isFinishing = true
        ticker?.invalidate()
        ticker = nil
        deadline = nil
        remainingSeconds = 0
        state = .completed

        let endedAt = timeSource.now
        let session = FocusSession(
            topic: topic,
            durationSeconds: activeBlockDurationSeconds,
            startedAt: blockStartedAt ?? endedAt.addingTimeInterval(-TimeInterval(activeBlockDurationSeconds)),
            endedAt: endedAt
        )

        historyStore.append(session)
        onBlockCompleted?(session)
        isFinishing = false
    }

    private func syncDurationFromSettings() {
        guard state == .idle else {
            return
        }

        activeBlockDurationSeconds = settings.blockLengthSeconds
        remainingSeconds = settings.blockLengthSeconds
    }

    private func notifyUpdate() {
        onUpdate?()
    }

    private static func clockString(from seconds: Int, includeHoursWhenNeeded: Bool) -> String {
        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remaining = clamped % 60

        if includeHoursWhenNeeded, hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remaining)
        }

        return String(format: "%02d:%02d", minutes + (hours * 60), remaining)
    }
}
