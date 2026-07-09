import Foundation

struct Coordinate: Sendable, Equatable, Hashable, Codable {
    let latitude: Double
    let longitude: Double
}

extension Coordinate {
    /// Great-circle distance in statute miles.
    func miles(to other: Coordinate) -> Double {
        let earthRadiusMiles = 3958.7613
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2)
        return earthRadiusMiles * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
