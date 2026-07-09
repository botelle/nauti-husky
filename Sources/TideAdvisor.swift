import SwiftUI

enum TideAdvisor {
    struct Advice: Sendable, Equatable {
        let inPreferredWindow: Bool
        let label: String          // e.g. "Near high tide" / "High tide in 1h 20m"
        let color: Color
    }

    /// Evaluate whether `now` falls within ±windowHours of a preferred tide extreme.
    static func advise(_ tides: TideState,
                       preference: TidePreference,
                       windowHours: Double,
                       now: Date = Date()) -> Advice? {
        guard preference != .none else { return nil }
        let wantedKind: TideKind = preference == .high ? .high : .low

        let extremes = tides.events.filter { $0.kind == wantedKind }
        guard let nearest = extremes.min(by: {
            abs($0.time.timeIntervalSince(now)) < abs($1.time.timeIntervalSince(now))
        }) else { return nil }

        let deltaSeconds = nearest.time.timeIntervalSince(now)
        let withinWindow = abs(deltaSeconds) <= windowHours * 3600
        let kindWord = wantedKind == .high ? "high" : "low"

        if withinWindow {
            return Advice(inPreferredWindow: true,
                          label: "Good window — near \(kindWord) tide",
                          color: .teal)
        } else {
            let rel = nearest.time.formatted(.relative(presentation: .named))
            let when = deltaSeconds > 0 ? "next \(kindWord) tide \(rel)" : "last \(kindWord) tide \(rel)"
            return Advice(inPreferredWindow: false,
                          label: "Outside window — \(when)",
                          color: .orange)
        }
    }
}
