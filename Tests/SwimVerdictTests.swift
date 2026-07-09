import XCTest
@testable import NautiHuskyTemp

/// Logic tests for the glanceable go/wait verdict. Shared by the iOS and
/// watchOS unit-test targets (the engine is platform-agnostic).
final class SwimVerdictTests: XCTestCase {

    private let spot = SwimSpot(source: .curated(id: "test"),
                                name: "Test Spot",
                                coordinate: Coordinate(latitude: 41.5, longitude: -71.3),
                                distanceMiles: 0)

    /// A fixed instant so tide math is deterministic.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func conditions(water: Reading? = nil,
                            tides: TideState? = nil,
                            weather: WeatherSnapshot? = nil,
                            lightning: LightningRisk = .clear) -> SpotConditions {
        SpotConditions(spot: spot, water: water, tides: tides, weather: weather, lightning: lightning)
    }

    func testCalmConditionsAreGood() {
        let r = SwimVerdict.evaluate(conditions(), tidePreference: .none, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .good)
        XCTAssertEqual(r.headline, "Good to go")
        XCTAssertTrue(r.reasons.isEmpty)
    }

    func testNearbyLightningForcesAvoid() {
        let r = SwimVerdict.evaluate(conditions(lightning: .nearbyStrikes(3)),
                                     tidePreference: .none, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .avoid)
        XCTAssertEqual(r.headline, "Wait — stay out")
        XCTAssertTrue(r.reasons.contains { $0.contains("3 lightning strikes nearby") })
    }

    func testZeroStrikeStormReportsThunderstorms() {
        let r = SwimVerdict.evaluate(conditions(lightning: .nearbyStrikes(0)),
                                     tidePreference: .none, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .avoid)
        XCTAssertTrue(r.reasons.contains { $0.contains("Thunderstorms in the area") })
    }

    func testThunderstormAlertIsAvoid() {
        let w = WeatherSnapshot(airTempF: 80, shortForecast: nil,
                                thunderstormProbability: nil,
                                activeAlerts: ["Severe Thunderstorm Warning"],
                                hours: [])
        let r = SwimVerdict.evaluate(conditions(weather: w),
                                     tidePreference: .none, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .avoid)
        XCTAssertTrue(r.reasons.contains("Severe Thunderstorm Warning"))
    }

    func testGenericAlertIsCaution() {
        let w = WeatherSnapshot(airTempF: 90, shortForecast: nil,
                                thunderstormProbability: nil,
                                activeAlerts: ["Heat Advisory"],
                                hours: [])
        let r = SwimVerdict.evaluate(conditions(weather: w),
                                     tidePreference: .none, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .caution)
        XCTAssertTrue(r.reasons.contains("Heat Advisory"))
    }

    func testHighThunderstormProbabilityIsCaution() {
        let w = WeatherSnapshot(airTempF: 80, shortForecast: nil,
                                thunderstormProbability: 60, activeAlerts: [], hours: [])
        let r = SwimVerdict.evaluate(conditions(weather: w),
                                     tidePreference: .none, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .caution)
        XCTAssertTrue(r.reasons.contains { $0.contains("Thunderstorm chance 60%") })
    }

    func testWarmWaterIsCaution() {
        let water = Reading(waterF: DogTemp.warmMaxF + 3, airF: nil, timestamp: now)
        let r = SwimVerdict.evaluate(conditions(water: water),
                                     tidePreference: .none, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .caution)
        XCTAssertTrue(r.reasons.contains { $0.localizedCaseInsensitiveContains("limited cooling") })
    }

    /// Safety signals must outrank comfort ones: lightning (avoid) wins over warm water (caution).
    func testSafetyOutranksComfort() {
        let water = Reading(waterF: 82, airF: nil, timestamp: now)
        let r = SwimVerdict.evaluate(conditions(water: water, lightning: .nearbyStrikes(1)),
                                     tidePreference: .none, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .avoid)
    }

    func testTideOutsideWindowIsCaution() {
        let tides = TideState(events: [TideEvent(kind: .high,
                                                 time: now.addingTimeInterval(6 * 3600),
                                                 heightFt: 4)])
        let r = SwimVerdict.evaluate(conditions(tides: tides),
                                     tidePreference: .high, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .caution)
        XCTAssertTrue(r.reasons.contains { $0.contains("Outside window") })
    }

    func testTideInsideWindowStaysGood() {
        let tides = TideState(events: [TideEvent(kind: .high,
                                                 time: now.addingTimeInterval(3600),
                                                 heightFt: 4)])
        let r = SwimVerdict.evaluate(conditions(tides: tides),
                                     tidePreference: .high, tideWindowHours: 2, now: now)
        XCTAssertEqual(r.level, .good)
    }
}
