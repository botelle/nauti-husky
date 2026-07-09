import SwiftUI

/// Lumy-inspired look: a warm sky gradient that tracks the actual daylight
/// phase at the selected spot (Solar sunrise/sunset), with soft glass cards
/// floating on top. Light and airy by day, dimming through golden hour into
/// a deep night palette.
enum Sky {
    enum Phase {
        case night, dawn, day, golden, dusk
    }

    /// Screenshot/UI-test hook: launch with `-SkyPhase day|dawn|golden|dusk|night`
    /// to pin the palette regardless of the clock.
    static var debugOverride: Phase? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-SkyPhase"), args.indices.contains(i + 1) else { return nil }
        switch args[i + 1] {
        case "dawn": return .dawn
        case "day": return .day
        case "golden": return .golden
        case "dusk": return .dusk
        case "night": return .night
        default: return nil
        }
    }

    /// Daylight phase at `coord` right now; falls back to clock-hour bands
    /// when there's no coordinate (or the sun never rises/sets).
    static func phase(now: Date = .now,
                      coord: Coordinate?,
                      calendar: Calendar = .current) -> Phase {
        if let override = debugOverride { return override }
        if let coord,
           let rise = Solar.sunrise(coord: coord, date: now, calendar: calendar),
           let set = Solar.sunset(coord: coord, date: now, calendar: calendar) {
            if now < rise.addingTimeInterval(-45 * 60) { return .night }
            if now < rise.addingTimeInterval(60 * 60) { return .dawn }
            if now > set.addingTimeInterval(45 * 60) { return .night }
            if now > set.addingTimeInterval(-75 * 60) { return .dusk }
            if now > set.addingTimeInterval(-3 * 3600) { return .golden }
            return .day
        }
        switch calendar.component(.hour, from: now) {
        case 5..<8: return .dawn
        case 8..<17: return .day
        case 17..<19: return .golden
        case 19..<21: return .dusk
        default: return .night
        }
    }

    static func gradient(_ phase: Phase) -> LinearGradient {
        let colors: [Color]
        switch phase {
        case .dawn:   colors = [c(255, 214, 165), c(255, 183, 168), c(191, 205, 255)]
        case .day:    colors = [c(132, 199, 255), c(186, 226, 255), c(255, 243, 214)]
        case .golden: colors = [c(255, 205, 120), c(255, 159, 122), c(187, 164, 255)]
        case .dusk:   colors = [c(249, 140, 121), c(178, 120, 199), c(59, 69, 140)]
        case .night:  colors = [c(30, 34, 70), c(46, 42, 90), c(18, 21, 40)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    /// Phases where light text reads better than dark.
    static func isDark(_ phase: Phase) -> Bool {
        phase == .night || phase == .dusk
    }

    private static func c(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }
}

/// A soft floating card over the sky gradient.
private struct SkyCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
    }
}

extension View {
    func skyCard() -> some View { modifier(SkyCard()) }
}
