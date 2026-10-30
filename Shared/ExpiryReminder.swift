import Foundation
import UserNotifications

/// Promemoria locali per rinnovare l'app prima che scada la firma.
enum ExpiryReminder {
    private static let idDay = "rinnovo-giorno"
    private static let idHours = "rinnovo-ore"

    /// (Ri)programma i promemoria in base alla scadenza attuale.
    /// Sicuro da chiamare più volte: gli stessi identificativi sostituiscono i precedenti,
    /// così dopo un rinnovo le date vecchie spariscono.
    static func schedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [idDay, idHours])

        guard let expiry = Provisioning.expirationDate(), expiry > Date() else { return }

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }

        let calendar = Calendar.current

        // 1) Il giorno prima della scadenza, alle 18:00
        if let dayBefore = calendar.date(byAdding: .day, value: -1, to: expiry),
           let at18 = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: dayBefore),
           at18 > Date().addingTimeInterval(60) {
            await post(
                id: idDay,
                title: "Rinnova Snus Counter",
                body: "L'app scade domani. Collega l'iPhone e premi Start in Sideloadly.",
                trigger: calendarTrigger(at18)
            )
        }

        // 2) Tre ore prima della scadenza
        let threeHoursBefore = expiry.addingTimeInterval(-3 * 3600)
        if threeHoursBefore > Date().addingTimeInterval(60) {
            await post(
                id: idHours,
                title: "Snus Counter sta per scadere",
                body: "Rinnovala ora con Sideloadly: tra poche ore smette di funzionare.",
                trigger: calendarTrigger(threeHoursBefore)
            )
        }
    }

    /// Notifica di prova dal pulsante nell'app.
    static func sendTest() async {
        await post(
            id: "rinnovo-prova",
            title: "Rinnova Snus Counter",
            body: "L'app scade domani. Collega l'iPhone e premi Start in Sideloadly.",
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
    }

    private static func calendarTrigger(_ date: Date) -> UNNotificationTrigger {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date
        )
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private static func post(id: String, title: String, body: String, trigger: UNNotificationTrigger) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
