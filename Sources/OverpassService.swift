import Foundation

/// Looks up swimmable water bodies (beaches, lakes, swimming areas) from OpenStreetMap.
enum OverpassService {
    static let endpoint = "https://overpass-api.de/api/interpreter"

    static func spots(near center: Coordinate, radiusMiles: Double) async throws -> [SwimSpot] {
        let radiusMeters = Int(radiusMiles * 1609.34)
        let lat = center.latitude
        let lon = center.longitude
        let query = """
        [out:json][timeout:25];
        (
          node["natural"="beach"](around:\(radiusMeters),\(lat),\(lon));
          way["natural"="beach"](around:\(radiusMeters),\(lat),\(lon));
          node["leisure"="swimming_area"](around:\(radiusMeters),\(lat),\(lon));
          way["leisure"="swimming_area"](around:\(radiusMeters),\(lat),\(lon));
          way["natural"="water"]["water"~"lake|pond|reservoir"](around:\(radiusMeters),\(lat),\(lon));
        );
        out center 60;
        """

        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")"
            .data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: req)

        let env = try JSONDecoder().decode(OverpassEnvelope.self, from: data)
        var spots: [SwimSpot] = []
        var seenNames = Set<String>()
        for el in env.elements {
            guard let name = el.tags?["name"], !name.isEmpty else { continue }
            guard let lat = el.lat ?? el.center?.lat,
                  let lon = el.lon ?? el.center?.lon else { continue }
            let key = name.lowercased()
            if seenNames.contains(key) { continue }
            seenNames.insert(key)
            let coord = Coordinate(latitude: lat, longitude: lon)
            spots.append(SwimSpot(source: .osm(id: "\(el.type)/\(el.id)"),
                                  name: name,
                                  coordinate: coord,
                                  distanceMiles: center.miles(to: coord)))
        }
        return spots
    }

    private struct OverpassEnvelope: Decodable {
        let elements: [Element]
        struct Element: Decodable {
            let type: String
            let id: Int
            let lat: Double?
            let lon: Double?
            let center: Center?
            let tags: [String: String]?
            struct Center: Decodable { let lat: Double; let lon: Double }
        }
    }
}

private extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        var cs = CharacterSet.alphanumerics
        cs.insert(charactersIn: "-._~")
        return cs
    }()
}
