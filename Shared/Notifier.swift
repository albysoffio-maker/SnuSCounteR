import UserNotifications

/// Notifiche locali (non servono server né account a pagamento).
enum Notifier {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Chiamata quando oggi supera il numero di ieri.
    static func notifyOverYesterday(today: Int, yesterday: Int) async {
        await post(id: "va-pian-\(CounterStore.dayKey())", title: "Va pian")
    }

    /// Notifica di prova dal pulsante nell'app.
    static func sendTest() async {
        await post(id: "va-pian-prova", title: "Va pian")
    }

    private static func post(id: String, title: String, body: String? = nil) async {
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
        if let body { content.body = body }
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
