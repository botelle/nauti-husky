import XCTest
@testable import NautiHuskyTemp

/// Water-temperature comfort bands for the dogs.
final class CoolingBandsTests: XCTestCase {

    func testCoolWaterIsGreatHeatSink() {
        XCTAssertEqual(DogTemp.band(for: 65).label, "Great heat sink")
    }

    func testMidWaterManagesShade() {
        XCTAssertEqual(DogTemp.band(for: 72).shortLabel, "Manage shade")
    }

    func testWarmWaterKeepItShort() {
        XCTAssertEqual(DogTemp.band(for: 78).shortLabel, "Keep it short")
    }

    /// coolMaxF is the inclusive start of the "manage shade" band.
    func testCoolBoundaryBelongsToManageShade() {
        XCTAssertEqual(DogTemp.band(for: DogTemp.coolMaxF).shortLabel, "Manage shade")
    }

    /// warmMaxF is the inclusive start of the "keep it short" band.
    func testWarmBoundaryBelongsToKeepItShort() {
        XCTAssertEqual(DogTemp.band(for: DogTemp.warmMaxF).shortLabel, "Keep it short")
    }

    func testJustBelowCoolIsGreatHeatSink() {
        XCTAssertEqual(DogTemp.band(for: DogTemp.coolMaxF - 0.01).label, "Great heat sink")
    }
}
