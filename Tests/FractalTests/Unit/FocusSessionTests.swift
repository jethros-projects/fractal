@testable import FractalCore
import XCTest

final class FocusSessionTests: XCTestCase {
    func testTopicDisplayNameUsesTopicWhenPresent() {
        let session = FocusSession(
            topic: "Writing",
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910)
        )

        XCTAssertEqual(session.topicDisplayName, "Writing")
    }

    func testTopicDisplayNameFallsBackWhenTopicIsNil() {
        let session = FocusSession(
            topic: nil,
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910)
        )

        XCTAssertEqual(session.topicDisplayName, "No topic set")
    }

    func testTopicIsTrimmedOnInitialization() {
        let session = FocusSession(
            topic: "  Deep work  ",
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910)
        )

        XCTAssertEqual(session.topic, "Deep work")
    }

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

    func testTrimmedNonEmptyReturnsTrimmedValue() {
        XCTAssertEqual("  Plan launch  ".trimmedNonEmpty, "Plan launch")
    }

    func testTrimmedNonEmptyReturnsNilForBlankString() {
        XCTAssertNil(" \n\t ".trimmedNonEmpty)
    }
}
