import XCTest
@testable import NautiHuskyTemp

/// Tide-window preference logic.
final class TideAdvisorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testNoPreferenceReturnsNil() {
        let tides = TideState(events: [TideEvent(kind: .high, time: now.addingTimeInterval(3600), heightFt: 4)])
        XCTAssertNil(TideAdvisor.advise(tides, preference: .none, windowHours: 2, now: now))
    }

    func testWithinWindowHighTide() {
        let tides = TideState(events: [TideEvent(kind: .high, time: now.addingTimeInterval(3600), heightFt: 4)])
        let advice = TideAdvisor.advise(tides, preference: .high, windowHours: 2, now: now)
        XCTAssertNotNil(advice)
        XCTAssertTrue(advice!.inPreferredWindow)
        XCTAssertTrue(advice!.label.localizedCaseInsensitiveContains("good window"))
    }

    func testOutsideWindowHighTide() {
        let tides = TideState(events: [TideEvent(kind: .high, time: now.addingTimeInterval(5 * 3600), heightFt: 4)])
        let advice = TideAdvisor.advise(tides, preference: .high, windowHours: 2, now: now)
        XCTAssertNotNil(advice)
        XCTAssertFalse(advice!.inPreferredWindow)
        XCTAssertTrue(advice!.label.localizedCaseInsensitiveContains("outside window"))
    }

    /// Among several extremes, the nearest one of the wanted kind is chosen.
    func testPicksNearestExtremeOfWantedKind() {
        let near = TideEvent(kind: .high, time: now.addingTimeInterval(3600), heightFt: 4)
        let far  = TideEvent(kind: .high, time: now.addingTimeInterval(10 * 3600), heightFt: 4)
        let low  = TideEvent(kind: .low,  time: now.addingTimeInterval(600), heightFt: 0.5)
        let tides = TideState(events: [low, near, far])
        let advice = TideAdvisor.advise(tides, preference: .high, windowHours: 2, now: now)
        XCTAssertNotNil(advice)
        XCTAssertTrue(advice!.inPreferredWindow) // nearest high is 1h away, within the 2h window
    }

    func testLowPreferenceUsesLowEvents() {
        let lowSoon  = TideEvent(kind: .low,  time: now.addingTimeInterval(1800), heightFt: 0.3)
        let highSoon = TideEvent(kind: .high, time: now.addingTimeInterval(600), heightFt: 4)
        let tides = TideState(events: [highSoon, lowSoon])
        let advice = TideAdvisor.advise(tides, preference: .low, windowHours: 2, now: now)
        XCTAssertNotNil(advice)
        XCTAssertTrue(advice!.inPreferredWindow)
        XCTAssertTrue(advice!.label.localizedCaseInsensitiveContains("low"))
    }
}
