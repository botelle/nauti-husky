import Foundation

/// UI-test / preview "demo mode". When active the app loads fixed, offline data
/// instead of hitting location + the network, so UI tests and screenshots are
/// deterministic. Enable with the `-UITestDemo` launch argument (or `UITEST_DEMO=1`).
enum DemoMode {
    static let isActive: Bool = {
        let p = ProcessInfo.processInfo
        return p.arguments.contains("-UITestDemo") || p.environment["UITEST_DEMO"] == "1"
    }()
}

/// A fixed, network-free spot + conditions used by demo mode. Cool, clear water
/// with no storms → a "Good to go" verdict.
enum DemoData {
    static var spot: SwimSpot {
        SwimSpot(source: .curated(id: "demo"),
                 name: "Demo Beach",
                 coordinate: Coordinate(latitude: 41.49, longitude: -71.31),
                 distanceMiles: 1.2)
    }

    static var conditions: SpotConditions {
        SpotConditions(
            spot: spot,
            water: Reading(waterF: 68, airF: 74, timestamp: Date()),
            tides: nil,
            weather: WeatherSnapshot(airTempF: 74,
                                     shortForecast: "Sunny",
                                     thunderstormProbability: 0,
                                     activeAlerts: [],
                                     hours: []),
            lightning: .clear)
    }
}
