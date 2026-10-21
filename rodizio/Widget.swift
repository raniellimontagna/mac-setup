// Widget.swift — extensão WidgetKit do Rodízio. Lê o arquivo que o app grava
// (WidgetPayload, em ~/Library/Application Support/Rodizio) e desenha os
// widgets pequeno, médio e grande. O app pede para redesenhar quando algo
// importante muda; a linha do tempo também vira sozinha quando uma conta
// libera ou uma janela zera, e no máximo a cada 15 min.

import SwiftUI
import WidgetKit

struct RodizioEntry: TimelineEntry {
    let date: Date
    let payload: WidgetPayload?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RodizioEntry {
        RodizioEntry(date: .now, payload: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (RodizioEntry) -> Void) {
        completion(RodizioEntry(date: .now, payload: WidgetPayload.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RodizioEntry>) -> Void) {
        let now = Date()
        let payload = WidgetPayload.load()
        var dates = [now]
        if let snap = payload?.snapshot {
            let t = now.timeIntervalSince1970
            let flips = snap.accounts.flatMap { a -> [Double] in
                [a.free_at, a.usage?.rate_limits?.five_hour?.resets_at ?? 0, a.usage?.rate_limits?.seven_day?.resets_at ?? 0]
            }
            dates += Set(flips.filter { $0 > t && $0 < t + 6 * 3600 }).sorted().prefix(10)
                .map { Date(timeIntervalSince1970: $0 + 1) }
        }
        let entries = dates.map { RodizioEntry(date: $0, payload: payload) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }
}

struct RodizioWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RodizioEntry

    var body: some View {
        if let payload = entry.payload {
            switch family {
            case .systemSmall: SmallWidgetView(payload: payload, now: entry.date)
            case .systemMedium: MediumWidgetView(payload: payload, now: entry.date)
            default: LargeWidgetView(payload: payload, now: entry.date)
            }
        } else {
            EmptyWidgetView()
        }
    }
}

struct RodizioWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RodizioWidget", provider: Provider()) { entry in
            RodizioWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(URL(string: "rodizio://abrir"))
        }
        .configurationDisplayName("Rodízio")
        .description("As contas Claude: quais têm folga, a próxima da fila e o uso de cada uma.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct RodizioWidgets: WidgetBundle {
    var body: some Widget {
        RodizioWidget()
    }
}
