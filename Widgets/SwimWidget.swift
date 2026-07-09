import WidgetKit
import SwiftUI

struct SwimProvider: TimelineProvider {
    func placeholder(in context: Context) -> SwimWidgetEntry {
        SwimWidgetEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SwimWidgetEntry) -> Void) {
        completion(SwimWidgetEntry(date: Date(), snapshot: SwimWidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SwimWidgetEntry>) -> Void) {
        let entry = SwimWidgetEntry(date: Date(), snapshot: SwimWidgetSnapshot.load())
        // Data only changes when the app runs; refresh the display hourly so the
        // "as of" freshness and time-of-day styling stay roughly current.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SwimWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SwimWidget", provider: SwimProvider()) { entry in
            SwimWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Swim conditions")
        .description("Current verdict and water temp for your spot.")
        .supportedFamilies(families)
    }

    private var families: [WidgetFamily] {
        #if os(watchOS)
        [.accessoryInline, .accessoryCircular, .accessoryRectangular]
        #else
        [.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular]
        #endif
    }
}

@main
struct SwimWidgetBundle: WidgetBundle {
    var body: some Widget {
        SwimWidget()
    }
}
