@testable import FractalCore
import Testing
import Foundation

struct FocusSessionTests {
    @Test
    func testTopicDisplayNameUsesTopicWhenPresent() {
        let session = FocusSession(
            topic: "Writing",
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910)
        )

        XCTAssertEqual(session.topicDisplayName, "Writing")
    }

    @Test
    func testTopicDisplayNameFallsBackWhenTopicIsNil() {
        let session = FocusSession(
            topic: nil,
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910)
        )

        XCTAssertEqual(session.topicDisplayName, "No topic set")
    }

    @Test
    func testTopicIsTrimmedOnInitialization() {
        let session = FocusSession(
            topic: "  Deep work  ",
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910)
        )

        XCTAssertEqual(session.topic, "Deep work")
    }

    @Test
    func testWhitespaceTopicIsStoredAsNil() {
        let session = FocusSession(
            topic: "   \n\t ",
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910)
        )

        XCTAssertNil(session.topic)
        XCTAssertEqual(session.topicDisplayName, "No topic set")
    }

    @Test
    func testTrimmedNonEmptyReturnsTrimmedValue() {
        XCTAssertEqual("  Plan launch  ".trimmedNonEmpty, "Plan launch")
    }

    @Test
    func testTrimmedNonEmptyReturnsNilForBlankString() {
        XCTAssertNil(" \n\t ".trimmedNonEmpty)
    }
}
