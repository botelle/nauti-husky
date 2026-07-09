import SwiftUI

/// One glanceable "should we get in?" call, composed from the conditions we
/// already gather. Safety signals (lightning/storms) outrank comfort ones.
enum SwimVerdict {
    enum Level: Int, Comparable {
        case good = 0, caution, avoid
        static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    struct Result: Equatable {
        let level: Level
        let headline: String
        let reasons: [String]   // short supporting bullets, most important first

        var color: Color {
            switch level {
            case .good:    return .teal
            case .caution: return .orange
            case .avoid:   return .red
            }
        }

        var symbol: String {
            switch level {
            case .good:    return "checkmark.seal.fill"
            case .caution: return "exclamationmark.triangle.fill"
            case .avoid:   return "hand.raised.fill"
            }
        }
    }

    static func evaluate(_ conditions: SpotConditions,
                         tidePreference: TidePreference,
                         tideWindowHours: Double,
                         avoidDawnDusk: Bool = false,
                         now: Date = Date()) -> Result {
        var level: Level = .good
        var reasons: [String] = []
        func escalate(to l: Level) { level = max(level, l) }

        // 1. Lightning / storms — the only hard "stay out" signals.
        switch conditions.lightning {
        case .nearbyStrikes(let n):
            escalate(to: .avoid)
            reasons.append(n > 0
                ? "\(n) lightning strike\(n == 1 ? "" : "s") nearby"
                : "Thunderstorms in the area")
        case .clear, .unknown:
            break
        }

        // 2. Active NWS alerts (thunderstorm/marine → stay out, others → heads up).
        if let weather = conditions.weather {
            for alert in weather.activeAlerts {
                if alert.localizedCaseInsensitiveContains("thunderstorm")
                    || alert.localizedCaseInsensitiveContains("marine")
                    || alert.localizedCaseInsensitiveContains("tsunami") {
                    escalate(to: .avoid)
                } else {
                    escalate(to: .caution)
                }
                reasons.append(alert)
            }
            if level < .avoid, let p = weather.thunderstormProbability, p >= 40 {
                escalate(to: .caution)
                reasons.append("Thunderstorm chance \(p)%")
            }
        }

        // 3. Water comfort for the dogs.
        if let water = conditions.water, water.waterF >= DogTemp.warmMaxF {
            escalate(to: .caution)
            reasons.append("Water \(fahrenheit(water.waterF)) — limited cooling, keep it short")
        }

        // 4. Dawn/dusk low-light (opt-in) — neutral at night, flagged near the
        //    sun's edges where visibility drops and fish tend to feed.
        if avoidDawnDusk,
           Solar.isLowLight(coord: conditions.spot.coordinate, at: now) {
            escalate(to: .caution)
            reasons.append("Low light — dawn/dusk")
        }

        // 5. Tide preference window.
        if let tides = conditions.tides,
           let advice = TideAdvisor.advise(tides,
                                           preference: tidePreference,
                                           windowHours: tideWindowHours,
                                           now: now),
           !advice.inPreferredWindow {
            escalate(to: .caution)
            reasons.append(advice.label)
        }

        return Result(level: level, headline: headline(for: level), reasons: reasons)
    }

    private static func headline(for level: Level) -> String {
        switch level {
        case .good:    return "Good to go"
        case .caution: return "Go, but heads up"
        case .avoid:   return "Wait — stay out"
        }
    }

    private static func fahrenheit(_ v: Double) -> String {
        String(format: "%.0f°F", v)
    }
}
