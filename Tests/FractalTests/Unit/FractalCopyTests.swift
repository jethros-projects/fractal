@testable import FractalCore
import XCTest

final class FractalCopyTests: XCTestCase {
    func testDurationFormatsMinutes() {
        XCTAssertEqual(FractalCopy.duration(900), "15 min")
    }

    func testDurationClampsSubMinuteValuesToOneMinute() {
        XCTAssertEqual(FractalCopy.duration(12), "1 min")
    }

    func testSentenceDurationFormatsHyphenatedMinutes() {
        XCTAssertEqual(FractalCopy.sentenceDuration(1_500), "25-minute")
    }

    func testCompactTimeFormatsMinutesOnly() {
        XCTAssertEqual(FractalCopy.compactTime(2_700), "45m")
    }

    func testCompactTimeFormatsWholeHours() {
        XCTAssertEqual(FractalCopy.compactTime(7_200), "2h")
    }

    func testCompactTimeFormatsHoursAndMinutes() {
        XCTAssertEqual(FractalCopy.compactTime(8_100), "2h 15m")
    }

    func testCompactTimeFormatsZeroWhenUnderOneMinute() {
        XCTAssertEqual(FractalCopy.compactTime(59), "0m")
    }
}
