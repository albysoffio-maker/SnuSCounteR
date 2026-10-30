import Foundation

/// Legge il profilo di firma che Sideloadly incorpora nell'app (embedded.mobileprovision).
enum Provisioning {
    private static func profile() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>") else { return nil }
        let xml = String(text[start.lowerBound..<end.upperBound])
        guard let xmlData = xml.data(using: .isoLatin1) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: xmlData, options: [], format: nil)) as? [String: Any]
    }

    /// Quando la firma scade (con l'Apple ID gratuito: 7 giorni dopo l'installazione).
    static func expirationDate() -> Date? {
        profile()?["ExpirationDate"] as? Date
    }
}
