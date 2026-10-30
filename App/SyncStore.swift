import Foundation

/// Copia locale dello storico nell'app, aggiornata ogni volta che dal widget si apre l'app.
enum SyncStore {
    private static let countsKey = "syncedCounts"
    private static let lastSyncKey = "lastSyncDate"

    private static var defaults: UserDefaults { .standard }

    static func counts() -> [String: Int] {
        defaults.dictionary(forKey: countsKey) as? [String: Int] ?? [:]
    }

    static var lastSync: Date? {
        defaults.object(forKey: lastSyncKey) as? Date
    }

    /// Importa i dati dal link aperto dal widget. Restituisce true se il link è valido.
    @discardableResult
    static func importFrom(url: URL) -> Bool {
        guard url.scheme == "snuscounter", url.host == "sync",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }

        let payload = comps.queryItems?.first(where: { $0.name == "d" })?.value ?? ""
        var merged = counts()
        for pair in payload.split(separator: ",") {
            let parts = pair.split(separator: ":")
            if parts.count == 2, let value = Int(parts[1]) {
                merged[String(parts[0])] = value
            }
        }
        defaults.set(merged, forKey: countsKey)
        defaults.set(Date(), forKey: lastSyncKey)
        return true
    }
}
