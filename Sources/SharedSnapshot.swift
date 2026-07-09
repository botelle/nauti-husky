import Foundation

/// Minimal, self-contained view of the current conditions, shared from the app
/// to its widgets through an App Group. Widgets have no network, so they render
/// this last-known state and show how fresh it is.
struct SwimWidgetSnapshot: Codable {
    var spotName: String
    var waterF: Double?
    var verdictLevel: Int       // 0 good, 1 caution, 2 avoid
    var verdictHeadline: String
    var verdictSymbol: String
    var bestWindow: String?     // e.g. "2–5 PM", or nil if none
    var updatedAt: Date

    static let appGroup = "group.org.botelle.SwimTime"
    private static let key = "widget.snapshot"

    static func load() -> SwimWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(SwimWidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: SwimWidgetSnapshot.appGroup),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: SwimWidgetSnapshot.key)
    }
}
