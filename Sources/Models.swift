import Foundation

enum SpotSource: Sendable, Equatable, Hashable, Codable {
    case noaaStation(id: String)   // has water temp + (usually) tides
    case osm(id: String)           // beach / lake from OpenStreetMap, no native sensors
    case curated(id: String)       // hand-seeded regional spot with notes
}

struct SwimSpot: Sendable, Equatable, Identifiable, Hashable, Codable {
    let source: SpotSource
    let name: String
    let coordinate: Coordinate
    let distanceMiles: Double

    var id: String {
        switch source {
        case .noaaStation(let id): return "noaa:\(id)"
        case .osm(let id):         return "osm:\(id)"
        case .curated(let id):     return "curated:\(id)"
        }
    }

    var stationID: String? {
        if case .noaaStation(let id) = source { return id }
        return nil
    }

    var kindLabel: String {
        switch source {
        case .noaaStation: return "Water-temp station"
        case .curated:     return "Lake / beach"
        case .osm:         return "Open water"
        }
    }

    var kindSymbol: String {
        switch source {
        case .noaaStation: return "thermometer.medium"
        case .curated:     return "star.circle"
        case .osm:         return "water.waves"
        }
    }
}

// MARK: - Tides

enum TideKind: String, Sendable, Codable { case high = "H", low = "L" }

struct TideEvent: Sendable, Equatable, Codable {
    let kind: TideKind
    let time: Date
    let heightFt: Double
}

struct TideState: Sendable, Equatable, Codable {
    let events: [TideEvent]          // chronological hi/lo for ~next 48h

    func nextEvent(after now: Date = Date()) -> TideEvent? {
        events.first { $0.time > now }
    }

    func lastEvent(before now: Date = Date()) -> TideEvent? {
        events.last { $0.time <= now }
    }
}

// MARK: - Weather

struct HourForecast: Sendable, Equatable, Codable {
    let time: Date
    let airTempF: Double?
    let thunderstormProbability: Int?   // 0–100, storm-boosted from NWS hourly
    let shortForecast: String?
}

struct WeatherSnapshot: Sendable, Equatable, Codable {
    let airTempF: Double?
    let shortForecast: String?
    let thunderstormProbability: Int?   // 0–100, derived from NWS hourly
    let activeAlerts: [String]          // e.g. "Severe Thunderstorm Warning"
    let hours: [HourForecast]           // chronological hourly forecast, ~next 12h
}

// MARK: - Lightning (strike data stubbed pending a paid feed)

enum LightningRisk: Sendable, Equatable, Codable {
    case unknown               // no provider wired yet
    case clear
    case nearbyStrikes(Int)    // count within range (future paid feed)
}

// MARK: - Aggregate

struct SpotConditions: Sendable, Equatable, Codable {
    let spot: SwimSpot
    let water: Reading?         // water (+air) temp from NOAA, if station-backed
    let tides: TideState?
    let weather: WeatherSnapshot?
    let lightning: LightningRisk

    /// Best-effort air temp: prefer the NOAA station reading, fall back to NWS.
    var airTempF: Double? {
        water?.airF ?? weather?.airTempF
    }
}
