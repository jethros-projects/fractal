@testable import FractalCore
import Testing
import Foundation

struct FractalCopyTests {
    @Test
    func testDurationFormatsMinutes() {
        XCTAssertEqual(FractalCopy.duration(900), "15 min")
    }

    @Test
    func testDurationClampsSubMinuteValuesToOneMinute() {
        XCTAssertEqual(FractalCopy.duration(12), "1 min")
    }

    @Test
    func testSentenceDurationFormatsHyphenatedMinutes() {
        XCTAssertEqual(FractalCopy.sentenceDuration(1_500), "25-minute")
    }

    @Test
    func testCompactTimeFormatsMinutesOnly() {
        XCTAssertEqual(FractalCopy.compactTime(2_700), "45m")
    }

    @Test
    func testCompactTimeFormatsWholeHours() {
        XCTAssertEqual(FractalCopy.compactTime(7_200), "2h")
    }

    @Test
    func testCompactTimeFormatsHoursAndMinutes() {
        XCTAssertEqual(FractalCopy.compactTime(8_100), "2h 15m")
    }

    @Test
    func testCompactTimeFormatsZeroWhenUnderOneMinute() {
        XCTAssertEqual(FractalCopy.compactTime(59), "0m")
    }
}
