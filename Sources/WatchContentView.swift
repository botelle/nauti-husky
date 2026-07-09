import SwiftUI

struct WatchContentView: View {
    @Bindable var model: SpotsModel
    var prefs: Preferences

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    switch model.phase {
                    case .idle, .locating, .discovering:
                        ProgressView()
                            .padding(.top, 12)
                        Text(progressLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    case .failed(let message):
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                        retryButton
                    case .loading, .ready:
                        summary
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Nauti Husky")
        }
        .task {
            await model.refresh()
        }
    }

    @ViewBuilder
    private var summary: some View {
        if let spot = model.selected {
            Text(spot.name)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }

        if let verdict {
            Label(verdict.headline, systemImage: verdict.symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(verdict.color)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(verdict.color.opacity(0.2), in: Capsule())
        }

        if let window = bestWindow {
            Label("Best \(hourLabel(window.start))–\(hourLabel(window.end))",
                  systemImage: "clock")
                .font(.caption2)
                .foregroundStyle(.teal)
        }

        if let water = model.conditions?.water {
            Text(String(format: "%.1f°", water.waterF))
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
            WatchCoolingBand(waterF: water.waterF)
        } else {
            Text("No water sensor")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

        if let air = model.conditions?.airTempF {
            Text("Air \(String(format: "%.0f°F", air))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

        retryButton
    }

    private var verdict: SwimVerdict.Result? {
        guard let c = model.conditions else { return nil }
        return SwimVerdict.evaluate(c,
                                    tidePreference: prefs.tidePreference,
                                    tideWindowHours: prefs.tideWindowHours,
                                    avoidDawnDusk: prefs.avoidDawnDusk)
    }

    private var bestWindow: (start: Date, end: Date)? {
        guard let c = model.conditions else { return nil }
        let points = SwimOutlook.hours(c,
                                       tidePreference: prefs.tidePreference,
                                       tideWindowHours: prefs.tideWindowHours,
                                       avoidDawnDusk: prefs.avoidDawnDusk)
        guard points.count > 1 else { return nil }
        return SwimOutlook.bestWindow(points)
    }

    private func hourLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour())
    }

    private var retryButton: some View {
        Button {
            Task { await model.refresh() }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .padding(.top, 4)
    }

    private var progressLabel: String {
        switch model.phase {
        case .locating:    return "Locating…"
        case .discovering: return "Finding spots…"
        default:           return "Loading…"
        }
    }
}

private struct WatchCoolingBand: View {
    let waterF: Double

    var body: some View {
        let info = DogTemp.band(for: waterF)
        Text(info.shortLabel)
            .font(.footnote.weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(info.color.opacity(0.22),
                        in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(info.color)
    }
}
