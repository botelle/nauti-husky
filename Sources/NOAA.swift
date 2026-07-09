import Foundation

struct Reading: Sendable, Equatable, Codable {
    let waterF: Double
    let airF: Double?
    let timestamp: Date
}

enum NOAAError: LocalizedError {
    case api(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .api(let msg): return "NOAA: \(msg)"
        case .empty:       return "NOAA returned no data."
        }
    }
}

enum NOAA {
    static let application = "NautiHusky"
    static let dataEndpoint = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
    static let metaEndpoint = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi"

    private static let stationTZ = TimeZone(identifier: "America/New_York")

    // MARK: - Temperature

    static func reading(station: String) async throws -> Reading {
        async let waterTask = sample(station: station, product: "water_temperature")
        async let airTask: Sample? = {
            do { return try await sample(station: station, product: "air_temperature") }
            catch { return nil }
        }()
        let water = try await waterTask
        let air = await airTask
        return Reading(waterF: water.value, airF: air?.value, timestamp: water.timestamp)
    }

    private struct Sample: Sendable {
        let value: Double
        let timestamp: Date
    }

    private static func sample(station: String, product: String) async throws -> Sample {
        var comp = URLComponents(string: dataEndpoint)!
        comp.queryItems = [
            URLQueryItem(name: "station",     value: station),
            URLQueryItem(name: "product",     value: product),
            URLQueryItem(name: "date",        value: "latest"),
            URLQueryItem(name: "units",       value: "english"),
            URLQueryItem(name: "time_zone",   value: "lst_ldt"),
            URLQueryItem(name: "format",      value: "json"),
            URLQueryItem(name: "application", value: application),
        ]
        let data = try await get(comp.url!)

        let decoder = JSONDecoder()
        if let env = try? decoder.decode(ErrorEnvelope.self, from: data),
           let msg = env.error?.message {
            throw NOAAError.api(msg)
        }
        let envelope = try decoder.decode(DataEnvelope.self, from: data)
        guard let first = envelope.data.first, let value = Double(first.v) else {
            throw NOAAError.empty
        }
        return Sample(value: value, timestamp: parse(first.t))
    }

    // MARK: - Tides

    static func tides(station: String) async throws -> TideState {
        var comp = URLComponents(string: dataEndpoint)!
        comp.queryItems = [
            URLQueryItem(name: "station",     value: station),
            URLQueryItem(name: "product",     value: "predictions"),
            URLQueryItem(name: "datum",       value: "MLLW"),
            URLQueryItem(name: "interval",    value: "hilo"),
            URLQueryItem(name: "date",        value: "today"),
            URLQueryItem(name: "range",       value: "48"),
            URLQueryItem(name: "units",       value: "english"),
            URLQueryItem(name: "time_zone",   value: "lst_ldt"),
            URLQueryItem(name: "format",      value: "json"),
            URLQueryItem(name: "application", value: application),
        ]
        let data = try await get(comp.url!)

        let decoder = JSONDecoder()
        if let env = try? decoder.decode(ErrorEnvelope.self, from: data),
           let msg = env.error?.message {
            throw NOAAError.api(msg)
        }
        let envelope = try decoder.decode(PredictionEnvelope.self, from: data)
        let events: [TideEvent] = envelope.predictions.compactMap { p in
            guard let kind = TideKind(rawValue: p.type), let h = Double(p.v) else { return nil }
            return TideEvent(kind: kind, time: parse(p.t), heightFt: h)
        }
        guard !events.isEmpty else { throw NOAAError.empty }
        return TideState(events: events)
    }

    // MARK: - Station catalog

    struct CatalogStation: Sendable {
        let id: String
        let name: String
        let coordinate: Coordinate
    }

    /// All stations that report water temperature, with coordinates.
    static func waterTempStations() async throws -> [CatalogStation] {
        let url = URL(string: "\(metaEndpoint)/stations.json?type=watertemp")!
        let data = try await get(url)
        let env = try JSONDecoder().decode(StationsEnvelope.self, from: data)
        return env.stations.map {
            CatalogStation(id: $0.id, name: $0.name,
                           coordinate: Coordinate(latitude: $0.lat, longitude: $0.lng))
        }
    }

    // MARK: - Helpers

    private static func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        req.timeoutInterval = 20
        let (data, _) = try await URLSession.shared.data(for: req)
        return data
    }

    private static func parse(_ s: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = stationTZ
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: s) ?? Date()
    }

    // MARK: - Decodables

    private struct DataEnvelope: Decodable {
        let data: [Point]
        struct Point: Decodable { let t: String; let v: String }
    }
    private struct PredictionEnvelope: Decodable {
        let predictions: [Prediction]
        struct Prediction: Decodable { let t: String; let v: String; let type: String }
    }
    private struct StationsEnvelope: Decodable {
        let stations: [Station]
        struct Station: Decodable { let id: String; let name: String; let lat: Double; let lng: Double }
    }
    private struct ErrorEnvelope: Decodable {
        let error: Body?
        struct Body: Decodable { let message: String }
    }
}
