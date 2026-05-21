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

    func testDefaultKindIsFocused() {
        let session = FocusSession(
            topic: "Writing",
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910)
        )

        XCTAssertEqual(session.kind, .focused)
        XCTAssertFalse(session.isUntracked)
    }

    func testUntrackedDisplayNameUsesUntrackedLabel() {
        let session = FocusSession(
            topic: nil,
            durationSeconds: 900,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 910),
            kind: .untracked
        )

        XCTAssertEqual(session.topicDisplayName, "Untracked")
        XCTAssertTrue(session.isUntracked)
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

    func testDecodingLegacySessionDefaultsToFocusedKind() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "topic": "Legacy",
          "durationSeconds": 900,
          "startedAt": "1970-01-01T00:00:10Z",
          "endedAt": "1970-01-01T00:15:10Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let session = try decoder.decode(FocusSession.self, from: Data(json.utf8))

        XCTAssertEqual(session.kind, .focused)
        XCTAssertEqual(session.topicDisplayName, "Legacy")
    }
}
