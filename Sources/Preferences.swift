import SwiftUI

enum TidePreference: String, Sendable, CaseIterable, Identifiable {
    case none = "No preference"
    case high = "Prefer near high tide"
    case low  = "Prefer near low tide"

    var id: String { rawValue }
}

/// User-tunable settings, persisted in UserDefaults.
@MainActor
@Observable
final class Preferences {
    var radiusMiles: Double {
        didSet { defaults.set(radiusMiles, forKey: Keys.radius) }
    }
    var tidePreference: TidePreference {
        didSet { defaults.set(tidePreference.rawValue, forKey: Keys.tidePref) }
    }
    var tideWindowHours: Double {
        didSet { defaults.set(tideWindowHours, forKey: Keys.tideWindow) }
    }
    var notifyOnGoodWindow: Bool {
        didSet { defaults.set(notifyOnGoodWindow, forKey: Keys.notify) }
    }
    var avoidDawnDusk: Bool {
        didSet { defaults.set(avoidDawnDusk, forKey: Keys.avoidDawnDusk) }
    }
    /// Spots the user pinned. Stored whole so they stay selectable even when
    /// outside the current search radius.
    private(set) var favorites: [SwimSpot]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.radiusMiles = defaults.object(forKey: Keys.radius) as? Double ?? 30
        self.tideWindowHours = defaults.object(forKey: Keys.tideWindow) as? Double ?? 2
        self.notifyOnGoodWindow = defaults.bool(forKey: Keys.notify)
        self.avoidDawnDusk = defaults.bool(forKey: Keys.avoidDawnDusk)
        if let raw = defaults.string(forKey: Keys.tidePref),
           let pref = TidePreference(rawValue: raw) {
            self.tidePreference = pref
        } else {
            self.tidePreference = .none
        }
        if let data = defaults.data(forKey: Keys.favorites),
           let favs = try? JSONDecoder().decode([SwimSpot].self, from: data) {
            self.favorites = favs
        } else {
            self.favorites = []
        }
    }

    // MARK: - Last-result cache (for instant startup)

    struct SpotsCache: Codable {
        var spots: [SwimSpot]
        var selectedID: String?
        var conditions: SpotConditions?
        var coordinate: Coordinate?
    }

    func loadCache() -> SpotsCache? {
        guard let data = defaults.data(forKey: Keys.cache) else { return nil }
        return try? JSONDecoder().decode(SpotsCache.self, from: data)
    }

    func saveCache(_ cache: SpotsCache) {
        if let data = try? JSONEncoder().encode(cache) {
            defaults.set(data, forKey: Keys.cache)
        }
    }

    func isFavorite(_ spot: SwimSpot) -> Bool {
        favorites.contains { $0.id == spot.id }
    }

    func toggleFavorite(_ spot: SwimSpot) {
        if let idx = favorites.firstIndex(where: { $0.id == spot.id }) {
            favorites.remove(at: idx)
        } else {
            favorites.append(spot)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: Keys.favorites)
        }
    }

    private enum Keys {
        static let radius = "pref.radiusMiles"
        static let tidePref = "pref.tidePreference"
        static let tideWindow = "pref.tideWindowHours"
        static let notify = "pref.notifyOnGoodWindow"
        static let avoidDawnDusk = "pref.avoidDawnDusk"
        static let favorites = "pref.favorites"
        static let cache = "pref.spotsCache"
    }
}
