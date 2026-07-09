import XCTest
@testable import NautiHuskyTemp

/// Great-circle distance (haversine) sanity checks.
final class GeoTests: XCTestCase {

    func testZeroDistanceForSamePoint() {
        let p = Coordinate(latitude: 41.5, longitude: -71.3)
        XCTAssertEqual(p.miles(to: p), 0, accuracy: 0.0001)
    }

    func testOneDegreeLongitudeAtEquator() {
        let d = Coordinate(latitude: 0, longitude: 0)
            .miles(to: Coordinate(latitude: 0, longitude: 1))
        XCTAssertEqual(d, 69.09, accuracy: 0.5)
    }

    func testOneDegreeLatitude() {
        let d = Coordinate(latitude: 0, longitude: 0)
            .miles(to: Coordinate(latitude: 1, longitude: 0))
        XCTAssertEqual(d, 69.09, accuracy: 0.5)
    }

    func testKnownCityDistanceNYCtoLA() {
        let nyc = Coordinate(latitude: 40.7128, longitude: -74.0060)
        let la  = Coordinate(latitude: 34.0522, longitude: -118.2437)
        XCTAssertEqual(nyc.miles(to: la), 2451, accuracy: 30)
    }

    func testDistanceIsSymmetric() {
        let a = Coordinate(latitude: 41.5, longitude: -71.3)
        let b = Coordinate(latitude: 42.0, longitude: -70.9)
        XCTAssertEqual(a.miles(to: b), b.miles(to: a), accuracy: 0.0001)
    }
}
