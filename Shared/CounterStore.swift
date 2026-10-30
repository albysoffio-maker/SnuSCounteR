import Foundation

struct DayCount: Identifiable {
    let date: Date
    let count: Int
    var id: Date { date }
}

/// Salva i conteggi giornalieri. Usa l'App Group se disponibile,
/// altrimenti UserDefaults normale dell'app/estensione.
enum CounterStore {
    static let groupID = "group.com.alby.snuscounter"
    private static let key = "dailyCounts"

    /// Sideloadly/AltStore riscrivono bundle ID e App Group quando firmano,
    /// quindi il nome scritto nel codice può non corrispondere. Leggo i gruppi
    /// realmente presenti nel profilo di provisioning incorporato nell'app.
    private static func provisionedGroups() -> [String] {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>") else { return [] }
        let xml = String(text[start.lowerBound..<end.upperBound])
        guard let xmlData = xml.data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else { return [] }
        return groups
    }

    /// Primo gruppo il cui container è davvero accessibile, altrimenti nil.
    private static let resolvedGroup: String? = {
        let candidates = CounterStore.provisionedGroups() + [CounterStore.groupID]
        for id in candidates {
            if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil {
                return id
            }
        }
        return nil
    }()

    static var isShared: Bool { resolvedGroup != nil }

    static var diagnostics: String {
        let bundle = Bundle.main.bundleIdentifier ?? "?"
        let groups = provisionedGroups()
        return """
        Bundle ID: \(bundle)
        Gruppi nel profilo: \(groups.isEmpty ? "nessuno" : groups.joined(separator: ", "))
        Gruppo in uso: \(resolvedGroup ?? "nessuno (dati separati da widget)")
        """
    }

    private static var defaults: UserDefaults {
        if let group = resolvedGroup, let shared = UserDefaults(suiteName: group) {
            return shared
        }
        return .standard
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date = Date()) -> String {
        formatter.string(from: date)
    }

    static func date(fromKey key: String) -> Date? {
        formatter.date(from: key)
    }

    /// Link che il widget apre quando lo tocchi: porta all'app lo storico (ultimi giorni).
    static func syncURL(maxDays: Int = 120) -> URL? {
        let counts = all()
        let keys = counts.keys.sorted(by: >).prefix(maxDays)
        let payload = keys.map { "\($0):\(counts[$0] ?? 0)" }.joined(separator: ",")
        var components = URLComponents()
        components.scheme = "snuscounter"
        components.host = "sync"
        components.queryItems = [URLQueryItem(name: "d", value: payload)]
        return components.url
    }

    static func all() -> [String: Int] {
        defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    static func count(on date: Date = Date()) -> Int {
        all()[dayKey(date)] ?? 0
    }

    static func yesterdayCount() -> Int {
        guard let d = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return 0 }
        return count(on: d)
    }

    /// Aggiunge (o toglie, con delta negativo) e restituisce il nuovo totale. Mai sotto zero.
    @discardableResult
    static func add(_ delta: Int, on date: Date = Date()) -> Int {
        var counts = all()
        let k = dayKey(date)
        let newValue = max(0, (counts[k] ?? 0) + delta)
        counts[k] = newValue
        defaults.set(counts, forKey: key)
        return newValue
    }

    /// Oggi + i giorni precedenti, dal più recente al più vecchio.
    static func lastDays(_ n: Int) -> [DayCount] {
        let calendar = Calendar.current
        let counts = all()
        var result: [DayCount] = []
        for offset in 0..<n {
            if let d = calendar.date(byAdding: .day, value: -offset, to: Date()) {
                result.append(DayCount(date: d, count: counts[dayKey(d)] ?? 0))
            }
        }
        return result
    }
}
