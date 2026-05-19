import Foundation

protocol FractalTimeSource {
    var now: Date { get }
}

struct SystemTimeSource: FractalTimeSource {
    var now: Date {
        Date()
    }
}

protocol FractalTickerToken: AnyObject {
    @MainActor
    func invalidate()
}

protocol FractalTickerScheduling {
    @MainActor
    func schedule(
        repeatingEvery interval: TimeInterval,
        _ handler: @escaping @MainActor () -> Void
    ) -> FractalTickerToken
}

struct RunLoopTickerScheduler: FractalTickerScheduling {
    @MainActor
    func schedule(
        repeatingEvery interval: TimeInterval,
        _ handler: @escaping @MainActor () -> Void
    ) -> FractalTickerToken {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                handler()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        return RunLoopTickerToken(timer: timer)
    }
}

private final class RunLoopTickerToken: FractalTickerToken {
    private let timer: Timer

    init(timer: Timer) {
        self.timer = timer
    }

    @MainActor
    func invalidate() {
        timer.invalidate()
    }
}
