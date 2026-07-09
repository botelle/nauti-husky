import SwiftUI
import Charts

/// Cosine-interpolated tide height between the NOAA hi/lo predictions — real
/// tides swing roughly sinusoidally between consecutive extremes.
struct TideCurve {
    let events: [TideEvent]   // chronological

    func height(at t: Date) -> Double? {
        guard let first = events.first, let last = events.last else { return nil }
        if t <= first.time { return first.heightFt }
        if t >= last.time { return last.heightFt }
        for i in 0..<(events.count - 1) where events[i].time <= t && t <= events[i + 1].time {
            let lo = events[i], hi = events[i + 1]
            let span = hi.time.timeIntervalSince(lo.time)
            guard span > 0 else { return lo.heightFt }
            let frac = t.timeIntervalSince(lo.time) / span
            let mid = (lo.heightFt + hi.heightFt) / 2
            let amp = (lo.heightFt - hi.heightFt) / 2
            return mid + amp * cos(.pi * frac)   // frac 0 → lo, frac 1 → hi
        }
        return nil
    }
}

struct TideCurveView: View {
    let tides: TideState
    var now: Date = Date()

    private struct Sample: Identifiable {
        let id = UUID()
        let date: Date
        let height: Double
    }

    var body: some View {
        let events = tides.events.sorted { $0.time < $1.time }
        let curve = TideCurve(events: events)
        let start = now.addingTimeInterval(-2 * 3600)
        let end = now.addingTimeInterval(16 * 3600)
        let samples = stride(from: start.timeIntervalSince1970,
                             through: end.timeIntervalSince1970, by: 900)
            .compactMap { ts -> Sample? in
                let d = Date(timeIntervalSince1970: ts)
                return curve.height(at: d).map { Sample(date: d, height: $0) }
            }
        let extremes = events.filter { $0.time >= start && $0.time <= end }
        let floor = (samples.map(\.height).min() ?? 0) - 0.4

        if samples.count > 2 {
            Chart {
                ForEach(samples) { s in
                    AreaMark(x: .value("Time", s.date),
                             yStart: .value("ft", floor),
                             yEnd: .value("ft", s.height))
                        .foregroundStyle(.blue.opacity(0.12))
                        .interpolationMethod(.catmullRom)
                }
                ForEach(samples) { s in
                    LineMark(x: .value("Time", s.date), y: .value("ft", s.height))
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)
                }
                RuleMark(x: .value("Now", now))
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                ForEach(extremes, id: \.time) { e in
                    PointMark(x: .value("Time", e.time), y: .value("ft", e.heightFt))
                        .foregroundStyle(e.kind == .high ? .blue : .teal)
                        .symbolSize(36)
                        .annotation(position: e.kind == .high ? .top : .bottom, spacing: 1) {
                            Text("\(e.kind == .high ? "H" : "L") \(String(format: "%.1f", e.heightFt))")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 110)
        }
    }
}
