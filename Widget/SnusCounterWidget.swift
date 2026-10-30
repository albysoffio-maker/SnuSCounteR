import WidgetKit
import SwiftUI
import AppIntents

struct SnusEntry: TimelineEntry {
    let date: Date
    let count: Int
    /// Oggi + 6 giorni precedenti, dal più recente al più vecchio.
    let history: [DayCount]
    /// Link aperto quando si tocca il widget: porta lo storico all'app.
    let syncURL: URL?
}

struct SnusProvider: TimelineProvider {
    private func makeEntry() -> SnusEntry {
        SnusEntry(
            date: Date(),
            count: CounterStore.count(),
            history: CounterStore.lastDays(7),
            syncURL: CounterStore.syncURL()
        )
    }

    func placeholder(in context: Context) -> SnusEntry {
        let sample = [3, 5, 4, 6, 2, 5, 4]
        let days = (0..<7).map { offset in
            DayCount(date: Date().addingTimeInterval(Double(-offset) * 86400), count: sample[offset])
        }
        return SnusEntry(date: Date(), count: 3, history: days, syncURL: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnusEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnusEntry>) -> Void) {
        let now = Date()
        // Ricarica a mezzanotte così il contatore riparte da 0 ogni giorno.
        let midnight = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)
        let entry = makeEntry()
        Task {
            // Anche il widget aggiorna i promemoria di rinnovo ogni volta che si ricarica.
            await ExpiryReminder.schedule()
            completion(Timeline(entries: [entry], policy: .after(midnight)))
        }
    }
}

struct SnusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnusEntry

    var body: some View {
        content
            .widgetURL(entry.syncURL)
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            Text("Snus oggi: \(entry.count)")
        case .systemMedium:
            medium
        default:
            counterBlock
        }
    }

    // Nero semitrasparente sulla Home; nessuno sfondo sulla schermata di blocco.
    @ViewBuilder
    private var background: some View {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            Color.clear
        default:
            LinearGradient(
                colors: [
                    Color.black.opacity(0.78),
                    Color(red: 0.05, green: 0.07, blue: 0.12).opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: Schermata di blocco (iOS la mostra in monocromatico)

    private var circular: some View {
        Button(intent: AddSnusIntent()) {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("\(entry.count)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .widgetAccentable()
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SNUS OGGI")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(entry.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .widgetAccentable()
            }
            Spacer(minLength: 0)
            lockButton(systemName: "minus", intent: RemoveSnusIntent())
            lockButton(systemName: "plus", intent: AddSnusIntent())
        }
    }

    private func lockButton<I: AppIntent>(systemName: String, intent: I) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.primary.opacity(0.2)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Home

    private var medium: some View {
        HStack(spacing: 16) {
            counterBlock
                .frame(maxWidth: .infinity)
            historyBars
                .frame(maxWidth: .infinity)
        }
    }

    private var counterBlock: some View {
        VStack(spacing: 4) {
            Text("SNUS OGGI")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Color.white.opacity(0.6))
            Text("\(entry.count)")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            HStack(spacing: 14) {
                homeButton(systemName: "minus", color: .snusCoral, filled: false, intent: RemoveSnusIntent())
                homeButton(systemName: "plus", color: .snusMint, filled: true, intent: AddSnusIntent())
            }
        }
    }

    private func homeButton<I: AppIntent>(systemName: String, color: Color, filled: Bool, intent: I) -> some View {
        Button(intent: intent) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(filled ? Color.black : color)
                .frame(width: 40, height: 40)
                .background(Circle().fill(filled ? color : color.opacity(0.22)))
        }
        .buttonStyle(.plain)
    }

    private var historyBars: some View {
        let days = Array(entry.history.reversed())
        let maxCount = max(days.map { $0.count }.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(days) { day in
                let isToday = Calendar.current.isDateInToday(day.date)
                VStack(spacing: 3) {
                    Text("\(day.count)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(isToday ? Color.snusMint : Color.white.opacity(0.55))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isToday ? Color.snusMint : Color.white.opacity(0.25))
                        .frame(height: max(3, 56 * CGFloat(day.count) / CGFloat(maxCount)))
                    Text(dayInitial(day.date))
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }

    private func dayInitial(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "EEEEE"
        return f.string(from: date).uppercased()
    }
}

struct SnusCounterWidget: Widget {
    let kind = "SnusCounterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnusProvider()) { entry in
            SnusWidgetView(entry: entry)
        }
        .configurationDisplayName("Contatore snus")
        .description("Tocca + per aggiungere uno snus. Tocca il resto del widget per aprire l'app con lo storico.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .systemSmall,
            .systemMedium
        ])
    }
}

@main
struct SnusWidgetBundle: WidgetBundle {
    var body: some Widget {
        SnusCounterWidget()
    }
}
