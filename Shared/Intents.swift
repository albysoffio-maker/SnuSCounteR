import AppIntents
import WidgetKit

struct AddSnusIntent: AppIntent {
    static let title: LocalizedStringResource = "Aggiungi uno snus"

    func perform() async throws -> some IntentResult {
        CounterStore.add(1)
        WidgetCenter.shared.reloadAllTimelines()
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
