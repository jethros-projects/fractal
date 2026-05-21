@testable import FractalCore
import XCTest

final class AppSettingsTests: XCTestCase {
    func testDefaultsMatchProductDefaults() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()

            let settings = AppSettings(defaults: defaults)

            XCTAssertEqual(settings.blockLengthMinutes, 15)
            XCTAssertEqual(settings.blockLengthSeconds, 900)
            XCTAssertTrue(settings.soundEnabled)
            XCTAssertTrue(settings.autoStartAfterContinue)
            XCTAssertTrue(settings.showSecondsInMenuBar)
        }
    }

    func testStoredBlockLengthIsLoaded() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            defaults.set(45, forKey: "blockLengthMinutes")

            let settings = AppSettings(defaults: defaults)

            XCTAssertEqual(settings.blockLengthMinutes, 45)
            XCTAssertEqual(settings.blockLengthSeconds, 2_700)
        }
    }

    func testStoredBooleanPreferencesAreLoaded() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            defaults.set(false, forKey: "soundEnabled")
            defaults.set(false, forKey: "autoStartAfterContinue")
            defaults.set(false, forKey: "showSecondsInMenuBar")

            let settings = AppSettings(defaults: defaults)

            XCTAssertFalse(settings.soundEnabled)
            XCTAssertFalse(settings.autoStartAfterContinue)
            XCTAssertFalse(settings.showSecondsInMenuBar)
        }
    }

    func testBlockLengthPersistsWhenChanged() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            let settings = AppSettings(defaults: defaults)

            settings.blockLengthMinutes = 30

            XCTAssertEqual(defaults.integer(forKey: "blockLengthMinutes"), 30)
            XCTAssertEqual(AppSettings(defaults: defaults).blockLengthMinutes, 30)
        }
    }

    func testBlockLengthClampsBelowRange() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            let settings = AppSettings(defaults: defaults)

            settings.blockLengthMinutes = -10

            XCTAssertEqual(settings.blockLengthMinutes, 1)
            XCTAssertEqual(defaults.integer(forKey: "blockLengthMinutes"), 1)
        }
    }

    func testBlockLengthClampsAboveRange() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            let settings = AppSettings(defaults: defaults)

            settings.blockLengthMinutes = 999

            XCTAssertEqual(settings.blockLengthMinutes, 240)
            XCTAssertEqual(defaults.integer(forKey: "blockLengthMinutes"), 240)
        }
    }

    func testStoredBlockLengthClampsBelowRangeOnInitialization() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            defaults.set(-20, forKey: "blockLengthMinutes")

            let settings = AppSettings(defaults: defaults)

            XCTAssertEqual(settings.blockLengthMinutes, 1)
        }
    }

    func testStoredBlockLengthClampsAboveRangeOnInitialization() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            defaults.set(999, forKey: "blockLengthMinutes")

            let settings = AppSettings(defaults: defaults)

            XCTAssertEqual(settings.blockLengthMinutes, 240)
        }
    }

    func testPresetRecognitionIsTrueForPresetLength() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            let settings = AppSettings(defaults: defaults)

            settings.blockLengthMinutes = 30

            XCTAssertTrue(settings.isUsingPreset)
        }
    }

    func testPresetRecognitionIsFalseForCustomLength() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            let settings = AppSettings(defaults: defaults)

            settings.blockLengthMinutes = 17

            XCTAssertFalse(settings.isUsingPreset)
        }
    }

    func testSoundPreferencePersists() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            let settings = AppSettings(defaults: defaults)

            settings.soundEnabled = false

            XCTAssertFalse(AppSettings(defaults: defaults).soundEnabled)
        }
    }

    func testAutoStartPreferencePersists() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            let settings = AppSettings(defaults: defaults)

            settings.autoStartAfterContinue = false

            XCTAssertFalse(AppSettings(defaults: defaults).autoStartAfterContinue)
        }
    }

    func testMenuBarSecondsPreferencePersists() async {
        await MainActor.run {
            let (defaults, _) = isolatedDefaults()
            let settings = AppSettings(defaults: defaults)

            settings.showSecondsInMenuBar = false

            XCTAssertFalse(AppSettings(defaults: defaults).showSecondsInMenuBar)
        }
    }
}
