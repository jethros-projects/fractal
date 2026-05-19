import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let presetMinutes = [5, 10, 15, 20, 25, 30, 45, 60]

    @Published var blockLengthMinutes: Int {
        didSet {
            let clampedValue = Self.clampedBlockLength(blockLengthMinutes)
            if blockLengthMinutes != clampedValue {
                blockLengthMinutes = clampedValue
            }
            defaults.set(blockLengthMinutes, forKey: Keys.blockLengthMinutes)
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: Keys.soundEnabled)
        }
    }

    @Published var autoStartAfterContinue: Bool {
        didSet {
            defaults.set(autoStartAfterContinue, forKey: Keys.autoStartAfterContinue)
        }
    }

    @Published var showSecondsInMenuBar: Bool {
        didSet {
            defaults.set(showSecondsInMenuBar, forKey: Keys.showSecondsInMenuBar)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedMinutes = defaults.integer(forKey: Keys.blockLengthMinutes)
        blockLengthMinutes = storedMinutes == 0 ? 15 : Self.clampedBlockLength(storedMinutes)

        if defaults.object(forKey: Keys.soundEnabled) == nil {
            soundEnabled = true
        } else {
            soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        }

        if defaults.object(forKey: Keys.autoStartAfterContinue) == nil {
            autoStartAfterContinue = true
        } else {
            autoStartAfterContinue = defaults.bool(forKey: Keys.autoStartAfterContinue)
        }

        if defaults.object(forKey: Keys.showSecondsInMenuBar) == nil {
            showSecondsInMenuBar = true
        } else {
            showSecondsInMenuBar = defaults.bool(forKey: Keys.showSecondsInMenuBar)
        }
    }

    var blockLengthSeconds: Int {
        max(1, blockLengthMinutes) * 60
    }

    var isUsingPreset: Bool {
        Self.presetMinutes.contains(blockLengthMinutes)
    }

    private enum Keys {
        static let blockLengthMinutes = "blockLengthMinutes"
        static let soundEnabled = "soundEnabled"
        static let autoStartAfterContinue = "autoStartAfterContinue"
        static let showSecondsInMenuBar = "showSecondsInMenuBar"
    }

    private static func clampedBlockLength(_ minutes: Int) -> Int {
        max(1, min(minutes, 240))
    }
}
