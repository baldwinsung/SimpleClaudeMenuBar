import XCTest
@testable import SimpleClaudeMenuBar

final class UsageParserTests: XCTestCase {
    let sample = """
    You are currently using your subscription to power your Claude Code usage

    Current session: 22% used · resets Jun 25 at 9:59pm (America/New_York)
    Current week (all models): 73% used · resets Jun 28 at 1:59pm (America/New_York)

    What's contributing to your limits usage?
    """

    func testParsesSession() {
        let s = UsageParser.parse(sample).session
        XCTAssertEqual(s?.percent, 22)
        XCTAssertEqual(s?.resetFull, "Jun 25 at 9:59pm")
        XCTAssertEqual(s?.resetShort, "9:59p")
    }

    func testParsesWeek() {
        let w = UsageParser.parse(sample).week
        XCTAssertEqual(w?.percent, 73)
        XCTAssertEqual(w?.resetFull, "Jun 28 at 1:59pm")
        XCTAssertEqual(w?.resetShort, "1:59p")
    }

    func testHandlesEmptyOutput() {
        let snap = UsageParser.parse("nothing useful here")
        XCTAssertNil(snap.session)
        XCTAssertNil(snap.week)
    }

    func testHandlesMorningTime() {
        let line = "Current session: 5% used · resets Jun 26 at 10:30am (America/New_York)"
        let s = UsageParser.parse(line).session
        XCTAssertEqual(s?.percent, 5)
        XCTAssertEqual(s?.resetShort, "10:30a")
    }

    func testHandlesOnTheHourTime() {
        let line = "Current session: 86% used · resets Jun 25 at 10pm (America/New_York)"
        let s = UsageParser.parse(line).session
        XCTAssertEqual(s?.percent, 86)
        XCTAssertEqual(s?.resetFull, "Jun 25 at 10pm")
        XCTAssertEqual(s?.resetShort, "10p")
    }

    func testParsesResetDate() {
        let line = "Current session: 5% used · resets Jun 26 at 10:30am (America/New_York)"
        guard let date = UsageParser.parse(line).session?.resetDate else {
            return XCTFail("no reset date parsed")
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 26)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 30)
    }

    func testParsesOnTheHourResetDate() {
        let line = "Current week (all models): 5% used · resets Aug 23 at 2pm (America/New_York)"
        guard let date = UsageParser.parse(line).week?.resetDate else {
            return XCTFail("no reset date parsed")
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let components = calendar.dateComponents([.hour, .minute], from: date)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 0)
    }

    // MARK: - Throttled 0/0 readings

    private func snapshot(session: Int, week: Int, resetIn hours: Double) -> UsageSnapshot {
        let reset = Date().addingTimeInterval(hours * 3600)
        return UsageSnapshot(
            session: UsageLine(percent: session, resetFull: "", resetShort: "", resetDate: reset),
            week: UsageLine(percent: week, resetFull: "", resetShort: "", resetDate: reset)
        )
    }

    func testZeroReadingIsSuspectWhileTheWindowIsStillOpen() {
        let previous = snapshot(session: 42, week: 5, resetIn: 1)
        let new = snapshot(session: 0, week: 0, resetIn: 1)
        XCTAssertTrue(ZeroReadingGuard.isSuspect(new: new, previous: previous))
    }

    func testZeroReadingIsAcceptedAfterTheWindowResets() {
        let previous = snapshot(session: 42, week: 5, resetIn: -1)
        let new = snapshot(session: 0, week: 0, resetIn: 5)
        XCTAssertFalse(ZeroReadingGuard.isSuspect(new: new, previous: previous))
    }

    func testZeroReadingIsAcceptedWithNothingToContradictIt() {
        let new = snapshot(session: 0, week: 0, resetIn: 5)
        XCTAssertFalse(ZeroReadingGuard.isSuspect(new: new, previous: UsageSnapshot()))
        XCTAssertFalse(
            ZeroReadingGuard.isSuspect(new: new, previous: snapshot(session: 0, week: 0, resetIn: 1))
        )
    }

    func testNonZeroReadingIsNeverSuspect() {
        let previous = snapshot(session: 42, week: 5, resetIn: 1)
        let new = snapshot(session: 1, week: 0, resetIn: 1)
        XCTAssertFalse(ZeroReadingGuard.isSuspect(new: new, previous: previous))
    }

    /// Regression: assigning `refreshMinutes` used to self-assign inside its own
    /// `didSet`, which re-enters the `@Published` setter and recurses until the
    /// stack overflows (the SIGSEGV crash on macOS 26). A crash here fails the
    /// test; otherwise the value must be clamped to [1, 120].
    @MainActor
    func testRefreshMinutesClampsWithoutRecursing() {
        let model = UsageModel()
        model.refreshMinutes = 999
        XCTAssertEqual(model.refreshMinutes, 120)
        model.refreshMinutes = 0
        XCTAssertEqual(model.refreshMinutes, 1)
        model.refreshMinutes = 15
        XCTAssertEqual(model.refreshMinutes, 15)
    }
}
