import Foundation

/// One labeled amenity for a spot (SF Symbol + short text).
struct Amenity: Sendable, Equatable {
    let symbol: String
    let text: String
}

/// Hand-seeded regional swim spots. OpenStreetMap misses big relation-mapped
/// lakes (Candlewood) and carries no dog/boat/parking rules, so we curate the
/// ones worth knowing. Rules are best-effort — verify before relying on them.
struct CuratedSpot: Sendable, Equatable {
    let id: String
    let name: String
    let coordinate: Coordinate
    let amenities: [Amenity]
    let infoURL: URL?
}

enum KnownSpots {
    /// Apple Maps link for directions + parking near a spot.
    static func directionsURL(for spot: SwimSpot) -> URL? {
        var c = URLComponents(string: "https://maps.apple.com/")!
        c.queryItems = [
            URLQueryItem(name: "ll", value: "\(spot.coordinate.latitude),\(spot.coordinate.longitude)"),
            URLQueryItem(name: "q", value: spot.name),
        ]
        return c.url
    }

    /// Curated details for a spot, matched by curated id or by name.
    static func info(for spot: SwimSpot) -> CuratedSpot? {
        if case .curated(let id) = spot.source {
            return all.first { $0.id == id }
        }
        return all.first { $0.name.localizedCaseInsensitiveCompare(spot.name) == .orderedSame }
    }

    static let all: [CuratedSpot] = [
        CuratedSpot(
            id: "jennings-beach",
            name: "Jennings Beach",
            coordinate: Coordinate(latitude: 41.1357, longitude: -73.2540),
            amenities: [
                Amenity(symbol: "pawprint.fill", text: "No dogs on the beach May 1–Sep 30"),
                Amenity(symbol: "figure.pool.swim", text: "Lifeguarded swimming in season"),
                Amenity(symbol: "parkingsign", text: "Large lot; beach sticker or fee in season"),
            ],
            infoURL: nil),
        CuratedSpot(
            id: "penfield-beach",
            name: "Penfield Beach",
            coordinate: Coordinate(latitude: 41.1390, longitude: -73.2680),
            amenities: [
                Amenity(symbol: "pawprint.fill", text: "No dogs on the beach May 1–Sep 30"),
                Amenity(symbol: "figure.pool.swim", text: "Lifeguarded swimming in season"),
                Amenity(symbol: "parkingsign", text: "Lot; beach sticker or fee in season"),
            ],
            infoURL: nil),
        CuratedSpot(
            id: "sherwood-island",
            name: "Sherwood Island State Park",
            coordinate: Coordinate(latitude: 41.1180, longitude: -73.3300),
            amenities: [
                Amenity(symbol: "pawprint.fill", text: "No pets in the park Apr 15–Sep 30"),
                Amenity(symbol: "figure.pool.swim", text: "Lifeguarded swimming in season"),
                Amenity(symbol: "parkingsign", text: "State park lot; entrance fee in season"),
            ],
            infoURL: nil),
        CuratedSpot(
            id: "candlewood-lake",
            name: "Candlewood Lake",
            coordinate: Coordinate(latitude: 41.4490, longitude: -73.4540),
            amenities: [
                Amenity(symbol: "sailboat.fill", text: "Powerboats permitted; CT's largest lake"),
                Amenity(symbol: "figure.pool.swim", text: "Public swimming at Squantz Pond State Park"),
                Amenity(symbol: "pawprint", text: "Dog rules vary by town/park — check locally"),
            ],
            infoURL: nil),
        CuratedSpot(
            id: "squantz-pond",
            name: "Squantz Pond State Park",
            coordinate: Coordinate(latitude: 41.4790, longitude: -73.4870),
            amenities: [
                Amenity(symbol: "pawprint.fill", text: "No pets in the park Apr 15–Sep 30"),
                Amenity(symbol: "figure.pool.swim", text: "Lifeguarded swimming; closes at capacity"),
                Amenity(symbol: "parkingsign", text: "State park lot; entrance fee in season"),
            ],
            infoURL: nil),
        CuratedSpot(
            id: "lake-zoar",
            name: "Lake Zoar",
            coordinate: Coordinate(latitude: 41.4070, longitude: -73.2760),
            amenities: [
                Amenity(symbol: "sailboat.fill", text: "Housatonic impoundment; boating allowed"),
                Amenity(symbol: "parkingsign", text: "State boat launch off Rte 34"),
            ],
            infoURL: nil),
        CuratedSpot(
            id: "lake-lillinonah",
            name: "Lake Lillinonah",
            coordinate: Coordinate(latitude: 41.4500, longitude: -73.3300),
            amenities: [
                Amenity(symbol: "sailboat.fill", text: "Housatonic impoundment; popular for boating"),
                Amenity(symbol: "parkingsign", text: "State boat launches; no formal swim beach"),
            ],
            infoURL: nil),
        CuratedSpot(
            id: "bantam-lake",
            name: "Bantam Lake",
            coordinate: Coordinate(latitude: 41.7100, longitude: -73.2200),
            amenities: [
                Amenity(symbol: "sailboat.fill", text: "Largest natural lake in CT; boating allowed"),
                Amenity(symbol: "figure.pool.swim", text: "Swimming at Sandy Beach (Morris)"),
            ],
            infoURL: nil),
    ]
}
