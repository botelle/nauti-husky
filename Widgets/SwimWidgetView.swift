import SwiftUI
import WidgetKit

/// Maps the stored verdict level (0/1/2) to its glanceable color.
func verdictColor(_ level: Int) -> Color {
    switch level {
    case 0:  return .teal
    case 1:  return .orange
    default: return .red
    }
}

struct SwimWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SwimWidgetSnapshot?
}

/// One view that adapts across every widget family it's offered in — small/medium
/// home-screen tiles on iOS and the accessory (lock-screen / watch) families.
struct SwimWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SwimWidgetEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            tile
        }
    }

    private var snapshot: SwimWidgetSnapshot? { entry.snapshot }

    // MARK: - Home-screen tile (systemSmall / systemMedium)

    private var tile: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let s = snapshot {
                Label(s.verdictHeadline, systemImage: s.verdictSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(verdictColor(s.verdictLevel))
                    .lineLimit(1)
                Text(s.spotName)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let w = s.waterF {
                        Text("\(Int(w.rounded()))°")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("water").font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("No sensor").font(.callout).foregroundStyle(.secondary)
                    }
                }
                if let window = s.bestWindow {
                    Label("Best \(window)", systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                placeholderText
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Accessory families (lock screen / watch complication)

    private var inline: some View {
        if let s = snapshot {
            Label(s.waterF.map { "\(Int($0.rounded()))° · \(shortVerdict(s.verdictLevel))" } ?? shortVerdict(s.verdictLevel),
                  systemImage: s.verdictSymbol)
        } else {
            Label("Tap to load", systemImage: "drop")
        }
    }

    private var circular: some View {
        Gauge(value: 1) {
            Image(systemName: snapshot?.verdictSymbol ?? "drop")
        } currentValueLabel: {
            if let w = snapshot?.waterF {
                Text("\(Int(w.rounded()))°")
            } else {
                Image(systemName: snapshot?.verdictSymbol ?? "drop")
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(verdictColor(snapshot?.verdictLevel ?? 0))
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let s = snapshot {
                Label(s.verdictHeadline, systemImage: s.verdictSymbol)
                    .font(.headline)
                    .widgetAccentable()
                Text(s.spotName).lineLimit(1)
                if let w = s.waterF {
                    Text("Water \(Int(w.rounded()))°" + (s.bestWindow.map { " · best \($0)" } ?? ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let window = s.bestWindow {
                    Text("Best \(window)").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Nauti Husky")
                Text("Open to load conditions").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var placeholderText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nauti Husky").font(.footnote.weight(.semibold))
            Text("Open the app to load nearby conditions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func shortVerdict(_ level: Int) -> String {
        switch level {
        case 0:  return "Go"
        case 1:  return "Caution"
        default: return "Stay out"
        }
    }
}
