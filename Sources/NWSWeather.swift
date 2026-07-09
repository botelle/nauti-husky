import Foundation

/// National Weather Service (api.weather.gov) — free, no key. Requires a User-Agent.
enum NWSWeather {
    static let userAgent = "NautiHuskyTemp (justin@botelle.net)"

    static func snapshot(at coord: Coordinate) async throws -> WeatherSnapshot {
        async let forecast = hourly(at: coord)
        async let alerts = activeAlerts(at: coord)
        let (hours, alertNames) = try await (forecast, alerts)
        let now = hours.first
        return WeatherSnapshot(airTempF: now?.airTempF,
                               shortForecast: now?.shortForecast,
                               thunderstormProbability: now?.thunderstormProbability,
                               activeAlerts: alertNames,
                               hours: hours)
    }

    // MARK: - Hourly forecast (next ~12 periods)

    private static func hourly(at coord: Coordinate, limit: Int = 12) async throws -> [HourForecast] {
        let point = try await points(at: coord)
        guard let urlString = point.properties.forecastHourly,
              let url = URL(string: urlString) else { return [] }
        let data = try await get(url)
        let env = try JSONDecoder().decode(ForecastEnvelope.self, from: data)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return env.properties.periods.prefix(limit).compactMap { p -> HourForecast? in
            guard let time = p.startTime.flatMap(iso.date(from:)) else { return nil }
            // Boost storm probability when the forecast text mentions thunder —
            // NWS often pairs a modest precip % with a real thunderstorm call.
            let thunder = (p.shortForecast?.localizedCaseInsensitiveContains("thunder") ?? false)
                ? max(p.probabilityOfPrecipitation?.value ?? 0, 50)
                : p.probabilityOfPrecipitation?.value
            return HourForecast(time: time,
                                airTempF: p.temperature.map(Double.init),
                                thunderstormProbability: thunder,
                                shortForecast: p.shortForecast)
        }
    }

    // MARK: - Active alerts

    private static func activeAlerts(at coord: Coordinate) async throws -> [String] {
        var comp = URLComponents(string: "https://api.weather.gov/alerts/active")!
        comp.queryItems = [URLQueryItem(name: "point", value: "\(coord.latitude),\(coord.longitude)")]
        let data = try await get(comp.url!)
        let env = try JSONDecoder().decode(AlertEnvelope.self, from: data)
        return env.features.compactMap { $0.properties.event }
    }

    // MARK: - Points lookup

    private static func points(at coord: Coordinate) async throws -> PointEnvelope {
        let lat = (coord.latitude * 10000).rounded() / 10000
        let lon = (coord.longitude * 10000).rounded() / 10000
        let url = URL(string: "https://api.weather.gov/points/\(lat),\(lon)")!
        let data = try await get(url)
        return try JSONDecoder().decode(PointEnvelope.self, from: data)
    }

    private static func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 20
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    // MARK: - Decodables

    private struct PointEnvelope: Decodable {
        let properties: Props
        struct Props: Decodable { let forecastHourly: String? }
    }
    private struct ForecastEnvelope: Decodable {
        let properties: Props
        struct Props: Decodable { let periods: [Period] }
        struct Period: Decodable {
            let startTime: String?
            let temperature: Int?
            let shortForecast: String?
            let probabilityOfPrecipitation: UnitValue?
        }
        struct UnitValue: Decodable { let value: Int? }
    }
    private struct AlertEnvelope: Decodable {
        let features: [Feature]
        struct Feature: Decodable { let properties: Props }
        struct Props: Decodable { let event: String? }
    }
}
