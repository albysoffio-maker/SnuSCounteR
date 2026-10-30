import AppIntents
import WidgetKit

struct AddSnusIntent: AppIntent {
    static let title: LocalizedStringResource = "Aggiungi uno snus"

    func perform() async throws -> some IntentResult {
        let yesterday = CounterStore.yesterdayCount()
        let today = CounterStore.add(1)
        WidgetCenter.shared.reloadAllTimelines()
        // Avviso solo nel momento in cui superi ieri (e se ieri c'erano dati).
        if yesterday > 0 && today == yesterday + 1 {
            await Notifier.notifyOverYesterday(today: today, yesterday: yesterday)
        }
        return .result()
    }
}

struct RemoveSnusIntent: AppIntent {
    static let title: LocalizedStringResource = "Togli uno snus"

    func perform() async throws -> some IntentResult {
        CounterStore.add(-1)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
