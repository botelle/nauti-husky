import Foundation

/// Hour-by-hour "should we get in?" outlook for the rest of today, built from
/// the NWS hourly forecast plus the spot's tide window. Mirrors SwimVerdict's
/// signals so a single hour reads the same way the current banner does.
enum SwimOutlook {
    struct HourPoint: Identifiable, Equatable {
        let time: Date
        let airTempF: Double?
        let thunderstormProbability: Int?
        let level: SwimVerdict.Level
        var id: Date { time }
    }

    static func hours(_ conditions: SpotConditions,
                      tidePreference: TidePreference,
                      tideWindowHours: Double,
                      avoidDawnDusk: Bool = false,
                      now: Date = Date()) -> [HourPoint] {
        guard let weather = conditions.weather else { return [] }
        // Keep the current hour and everything ahead; drop fully-past hours.
        let cutoff = now.addingTimeInterval(-1800)
        return weather.hours
            .filter { $0.time >= cutoff }
            .map { hour in
                HourPoint(time: hour.time,
                          airTempF: hour.airTempF,
                          thunderstormProbability: hour.thunderstormProbability,
                          level: level(for: hour,
                                       conditions: conditions,
                                       tidePreference: tidePreference,
                                       tideWindowHours: tideWindowHours,
                                       avoidDawnDusk: avoidDawnDusk))
            }
    }

    /// The soonest contiguous run of "good" hours, as a start/end span. End is
    /// the last good hour + 1h so a single good hour still reads as a range.
    static func bestWindow(_ points: [HourPoint]) -> (start: Date, end: Date)? {
        var start: Date?
        var end: Date?
        for p in points {
            if p.level == .good {
                if start == nil { start = p.time }
                end = p.time
            } else if start != nil {
                break   // soonest good run has ended
            }
        }
        guard let s = start, let e = end else { return nil }
        return (s, e.addingTimeInterval(3600))
    }

    private static func level(for hour: HourForecast,
                              conditions: SpotConditions,
                              tidePreference: TidePreference,
                              tideWindowHours: Double,
                              avoidDawnDusk: Bool) -> SwimVerdict.Level {
        var level: SwimVerdict.Level = .good

        if avoidDawnDusk,
           Solar.isLowLight(coord: conditions.spot.coordinate, at: hour.time) {
            level = max(level, .caution)
        }

        if let p = hour.thunderstormProbability {
            if p >= 50 { level = max(level, .avoid) }
            else if p >= 25 { level = max(level, .caution) }
        }

        // Active alerts span the whole window, so they color every hour.
        for alert in conditions.weather?.activeAlerts ?? [] {
            if alert.localizedCaseInsensitiveContains("thunderstorm")
                || alert.localizedCaseInsensitiveContains("marine")
                || alert.localizedCaseInsensitiveContains("tsunami") {
                level = max(level, .avoid)
            } else {
                level = max(level, .caution)
            }
        }

        if let tides = conditions.tides,
           let advice = TideAdvisor.advise(tides,
                                           preference: tidePreference,
                                           windowHours: tideWindowHours,
                                           now: hour.time),
           !advice.inPreferredWindow {
            level = max(level, .caution)
        }

        return level
    }
}
