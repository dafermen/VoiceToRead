import XCTest
@testable import VoiceToRead

final class SessionClockTests: XCTestCase {
    func testSuggestedTitlesAndOptionalName() {
        let date = Date(timeIntervalSince1970: 0)
        let title = SessionTitle.suggested(at: date, locale: Locale(identifier: "en_US"), timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertTrue(title.hasPrefix("Session · "))
        XCTAssertTrue(title.contains("Jan"))
        XCTAssertNotEqual(title, SessionTitle.suggested(at: date.addingTimeInterval(86400), locale: Locale(identifier: "en_US"), timeZone: TimeZone(secondsFromGMT: 0)!))
        XCTAssertEqual(SessionTitle.resolved(" Meeting ", at: date), "Meeting")
        XCTAssertEqual(SessionTitle.resolved("  ", at: date), SessionTitle.suggested(at: date))
        XCTAssertEqual(SessionTitle.resolved(String(repeating: "a", count: 130), at: date).count, 120)
    }
    func testInvalidAndLongDurationsDoNotOverflow() {
        XCTAssertEqual(SessionClock.format(.nan), "00:00:00")
        XCTAssertEqual(SessionClock.format(-1), "00:00:00")
        XCTAssertEqual(SessionClock.format(7200), "02:00:00")
        XCTAssertFalse(SessionClock.format(Double.greatestFiniteMagnitude).isEmpty)
        XCTAssertEqual(SessionClock.seconds(.milliseconds(1500)), 1.5, accuracy: 0.0001)
    }
}
