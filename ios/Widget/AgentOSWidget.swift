import SwiftUI
import WidgetKit

// A test widget: proves an extension signed on-device by Feather loads.
// It shows a fixed label and the time its timeline was made.

struct Entry: TimelineEntry {
    let date: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(Timeline(entries: [Entry(date: .now)], policy: .never))
    }
}

struct AgentOSWidgetView: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("AgentOS")
                .font(.headline)
            Text("Widget test")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.date, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct AgentOSWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AgentOSTest", provider: Provider()) { entry in
            AgentOSWidgetView(entry: entry)
        }
        .configurationDisplayName("AgentOS test")
        .description("Checks that a Feather-signed widget loads.")
        .supportedFamilies([.systemSmall])
    }
}
