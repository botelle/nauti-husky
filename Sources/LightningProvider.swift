import Foundation

/// Seam for a real-time lightning-strike feed. No free source exists, so the
/// default implementation is a stub; wire a paid provider here later.
protocol LightningProvider: Sendable {
    func risk(at coordinate: Coordinate, radiusMiles: Double) async -> LightningRisk
}

struct StubLightningProvider: LightningProvider {
    func risk(at coordinate: Coordinate, radiusMiles: Double) async -> LightningRisk {
        .unknown
    }
}

/// Until a strike feed is wired, fall back to NWS thunderstorm signals so the
/// lightning indicator still shows something actionable.
enum LightningHeuristic {
    static func fromWeather(_ weather: WeatherSnapshot?) -> LightningRisk {
        guard let weather else { return .unknown }
        let stormAlert = weather.activeAlerts.contains {
            $0.localizedCaseInsensitiveContains("thunderstorm")
                || $0.localizedCaseInsensitiveContains("marine")
        }
        if stormAlert { return .nearbyStrikes(0) }      // warning active; treat as elevated
        if let p = weather.thunderstormProbability, p >= 50 { return .nearbyStrikes(0) }
        if weather.thunderstormProbability != nil { return .clear }
        return .unknown
    }
}
