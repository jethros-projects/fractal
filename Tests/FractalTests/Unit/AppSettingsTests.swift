@testable import FractalCore
import Testing
import Foundation

struct AppSettingsTests {
    @MainActor
    @Test
    func testDefaultsMatchProductDefaults() {
        let (defaults, _) = isolatedDefaults()

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.blockLengthMinutes, 15)
        XCTAssertEqual(settings.blockLengthSeconds, 900)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.autoStartAfterContinue)
        XCTAssertTrue(settings.showSecondsInMenuBar)
    }

    @MainActor
    @Test
    func testStoredBlockLengthIsLoaded() {
        let (defaults, _) = isolatedDefaults()
        defaults.set(45, forKey: "blockLengthMinutes")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.blockLengthMinutes, 45)
        XCTAssertEqual(settings.blockLengthSeconds, 2_700)
    }

    @MainActor
    @Test
    func testStoredBooleanPreferencesAreLoaded() {
        let (defaults, _) = isolatedDefaults()
        defaults.set(false, forKey: "soundEnabled")
        defaults.set(false, forKey: "autoStartAfterContinue")
        defaults.set(false, forKey: "showSecondsInMenuBar")

        let settings = AppSettings(defaults: defaults)

        XCTAssertFalse(settings.soundEnabled)
        XCTAssertFalse(settings.autoStartAfterContinue)
        XCTAssertFalse(settings.showSecondsInMenuBar)
    }

    @MainActor
    @Test
    func testBlockLengthPersistsWhenChanged() {
        let (defaults, _) = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.blockLengthMinutes = 30

        XCTAssertEqual(defaults.integer(forKey: "blockLengthMinutes"), 30)
        XCTAssertEqual(AppSettings(defaults: defaults).blockLengthMinutes, 30)
    }

    @MainActor
    @Test
    func testBlockLengthClampsBelowRange() {
        let (defaults, _) = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.blockLengthMinutes = -10

        XCTAssertEqual(settings.blockLengthMinutes, 1)
        XCTAssertEqual(defaults.integer(forKey: "blockLengthMinutes"), 1)
    }

    @MainActor
    @Test
    func testBlockLengthClampsAboveRange() {
        let (defaults, _) = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.blockLengthMinutes = 999

        XCTAssertEqual(settings.blockLengthMinutes, 240)
        XCTAssertEqual(defaults.integer(forKey: "blockLengthMinutes"), 240)
    }

    @MainActor
    @Test
    func testStoredBlockLengthClampsBelowRangeOnInitialization() {
        let (defaults, _) = isolatedDefaults()
        defaults.set(-20, forKey: "blockLengthMinutes")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.blockLengthMinutes, 1)
    }

    @MainActor
    @Test
    func testStoredBlockLengthClampsAboveRangeOnInitialization() {
        let (defaults, _) = isolatedDefaults()
        defaults.set(999, forKey: "blockLengthMinutes")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.blockLengthMinutes, 240)
    }

    @MainActor
    @Test
    func testPresetRecognitionIsTrueForPresetLength() {
        let (defaults, _) = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.blockLengthMinutes = 25

        XCTAssertTrue(settings.isUsingPreset)
    }

    @MainActor
    @Test
    func testPresetRecognitionIsFalseForCustomLength() {
        let (defaults, _) = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.blockLengthMinutes = 17

        XCTAssertFalse(settings.isUsingPreset)
    }

    @MainActor
    @Test
    func testSoundPreferencePersists() {
        let (defaults, _) = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.soundEnabled = false

        XCTAssertFalse(AppSettings(defaults: defaults).soundEnabled)
    }

    @MainActor
    @Test
    func testAutoStartPreferencePersists() {
        let (defaults, _) = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.autoStartAfterContinue = false

        XCTAssertFalse(AppSettings(defaults: defaults).autoStartAfterContinue)
    }

    @MainActor
    @Test
    func testMenuBarSecondsPreferencePersists() {
        let (defaults, _) = isolatedDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.showSecondsInMenuBar = false

        XCTAssertFalse(AppSettings(defaults: defaults).showSecondsInMenuBar)
    }
}
