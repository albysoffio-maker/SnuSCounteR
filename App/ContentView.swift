import SwiftUI
import Charts
import UserNotifications

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var counts: [String: Int] = SyncStore.counts()
    @State private var lastSync: Date? = SyncStore.lastSync
    @State private var now = Date()
    @State private var range = 7
    @State private var syncToken = 0
    @State private var showToast = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var expiry: Date? = Provisioning.expirationDate()

    private static let italian = Locale(identifier: "it_IT")

    // MARK: Dati

    private var today: Int { counts[CounterStore.dayKey(now)] ?? 0 }

    private var yesterday: Int {
        guard let d = Calendar.current.date(byAdding: .day, value: -1, to: now) else { return 0 }
        return counts[CounterStore.dayKey(d)] ?? 0
    }

    /// Ultimi n giorni, dal più vecchio a oggi, con gli zeri dove non c'è nulla.
    private func days(_ n: Int) -> [DayCount] {
        let cal = Calendar.current
        return (0..<n).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            return DayCount(date: cal.startOfDay(for: d), count: counts[CounterStore.dayKey(d)] ?? 0)
        }
    }

    private var weekTotal: Int { days(7).reduce(0) { $0 + $1.count } }
    private var weekAverage: Double { Double(weekTotal) / 7.0 }
    private var record: Int { counts.values.max() ?? 0 }

    private var chartAverage: Double {
        Double(days(range).reduce(0) { $0 + $1.count }) / Double(range)
    }

    private var axisFormat: Date.FormatStyle {
        let style = range == 7 ? Date.FormatStyle().weekday(.narrow) : Date.FormatStyle().day()
        return style.locale(Self.italian)
    }

    private var delta: (text: String, icon: String, color: Color) {
        let diff = today - yesterday
        if diff == 0 { return ("Come ieri", "equal", Color.secondary) }
        if diff > 0 { return ("\(diff) in più di ieri", "arrow.up.right", Color.snusCoral) }
        return ("\(-diff) in meno di ieri", "arrow.down.right", Color.snusMint)
    }

    // MARK: Schermata

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.06, blue: 0.11), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    if lastSync != nil {
                        todayCard
                        statsGrid
                        chartCard
                        historyCard
                    } else {
                        emptyCard
                    }
                    notifCard
                    renewCard
                    howToCard
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            if showToast { toast }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, Self.italian)
        .onOpenURL { url in handle(url) }
        .onAppear(perform: refreshNotifStatus)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                now = Date()
                refreshNotifStatus()
            }
        }
        .sensoryFeedback(.success, trigger: syncToken)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Snus Counter")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(now, format: Date.FormatStyle().weekday(.wide).day().month(.wide).locale(Self.italian))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var todayCard: some View {
        card {
            VStack(alignment: .leading, spacing: 4) {
                Text("OGGI")
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Text("\(today)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.snusMint)
                Label(delta.text, systemImage: delta.icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(delta.color)
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            tile(title: "Media 7 giorni",
                 value: weekAverage.formatted(.number.precision(.fractionLength(1)).locale(Self.italian)),
                 icon: "chart.line.uptrend.xyaxis", tint: Color.snusMint)
            tile(title: "Totale 7 giorni", value: "\(weekTotal)", icon: "sum", tint: Color.white)
            tile(title: "Ieri", value: "\(yesterday)", icon: "clock.arrow.circlepath", tint: Color.snusCoral)
            tile(title: "Record giornaliero", value: "\(record)", icon: "trophy.fill", tint: Color.yellow)
        }
    }

    private func tile(title: String, value: String, icon: String, tint: Color) -> some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var chartCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Andamento")
                    .font(.headline)

                Picker("Periodo", selection: $range) {
                    Text("7 giorni").tag(7)
                    Text("14 giorni").tag(14)
                    Text("30 giorni").tag(30)
                }
                .pickerStyle(.segmented)

                Chart {
                    ForEach(days(range)) { day in
                        BarMark(
                            x: .value("Giorno", day.date, unit: .day),
                            y: .value("Snus", day.count)
                        )
                        .cornerRadius(4)
                        .foregroundStyle(
                            Calendar.current.isDateInToday(day.date)
                                ? Color.snusMint
                                : Color.white.opacity(0.3)
                        )
                    }
                    RuleMark(y: .value("Media", chartAverage))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.snusCoral.opacity(0.8))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == 30 ? 5 : 1)) { _ in
                        AxisValueLabel(format: axisFormat)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 190)

                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.snusCoral.opacity(0.8))
                        .frame(width: 16, height: 1)
                    Text("media del periodo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var historyCard: some View {
        let ordered = Array(days(14).reversed())
        let maxCount = max(ordered.map { $0.count }.max() ?? 1, 1)
        return card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ultimi 14 giorni")
                    .font(.headline)
                ForEach(ordered) { day in
                    HStack(spacing: 10) {
                        Text(day.date, format: Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated).locale(Self.italian))
                            .font(.subheadline)
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? Color.snusMint : Color.white)
                        Spacer()
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 90, height: 6)
                            Capsule()
                                .fill(Calendar.current.isDateInToday(day.date) ? Color.snusMint : Color.white.opacity(0.45))
                                .frame(width: max(4, 90 * CGFloat(day.count) / CGFloat(maxCount)), height: 6)
                        }
                        Text("\(day.count)")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var emptyCard: some View {
        card {
            VStack(spacing: 12) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.snusMint)
                Text("Nessun dato ancora")
                    .font(.headline)
                Text("Tocca il widget Snus Counter, fuori dai pulsanti + e −: l'app si apre e riceve il tuo storico.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var notifCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Avviso \"Va pian\"", systemImage: "bell.badge")
                    .font(.headline)
                Text("Ti arriva una notifica quando oggi superi il numero di ieri.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                switch notifStatus {
                case .authorized, .provisional, .ephemeral:
                    HStack {
                        Label("Attivo", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.snusMint)
                        Spacer()
                        Button("Prova") {
                            Task { await Notifier.sendTest() }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.snusMint)
                    }
                case .denied:
                    Text("Notifiche disattivate: abilitale da Impostazioni → Notifiche → Snus Counter.")
                        .font(.footnote)
                        .foregroundStyle(Color.snusCoral)
                default:
                    Button {
                        Task {
                            _ = await Notifier.requestPermission()
                            refreshNotifStatus()
                        }
                    } label: {
                        Text("Attiva le notifiche")
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.snusMint)
                }
            }
        }
    }

    private var notifAllowed: Bool {
        switch notifStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    private var renewCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Promemoria rinnovo", systemImage: "arrow.triangle.2.circlepath")
                    .font(.headline)

                if let expiry {
                    HStack(spacing: 4) {
                        Text("Scade:")
                            .foregroundStyle(.secondary)
                        Text(expiry, format: Date.FormatStyle().weekday(.wide).day().month(.wide).hour().minute().locale(Self.italian))
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    Text(remainingText(until: expiry))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(expiry.timeIntervalSince(now) < 86_400 ? Color.snusCoral : Color.snusMint)
                    Text("Ti avviso il giorno prima alle 18:00 e di nuovo 3 ore prima. Per rinnovare: collega l'iPhone e premi Start in Sideloadly, installando sopra l'app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if notifAllowed {
                        Button("Prova il promemoria") {
                            Task { await ExpiryReminder.sendTest() }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.snusMint)
                    } else {
                        Text("Attiva le notifiche qui sopra per ricevere il promemoria.")
                            .font(.footnote)
                            .foregroundStyle(Color.snusCoral)
                    }
                } else {
                    Text("Non riesco a leggere la data di scadenza dell'app: i promemoria di rinnovo non sono attivi.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func remainingText(until expiry: Date) -> String {
        if expiry <= now { return "Scaduta: rinnovala con Sideloadly." }
        let parts = Calendar.current.dateComponents([.day, .hour], from: now, to: expiry)
        let d = parts.day ?? 0
        let h = parts.hour ?? 0
        let hours = "\(h) \(h == 1 ? "ora" : "ore")"
        if d > 0 { return "Mancano \(d) \(d == 1 ? "giorno" : "giorni") e \(hours)." }
        return "Mancano \(hours)."
    }

    private func refreshNotifStatus() {
        expiry = Provisioning.expirationDate()
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notifStatus = settings.authorizationStatus
            }
        }
        // Riprogramma i promemoria: dopo un rinnovo la scadenza è cambiata.
        Task { await ExpiryReminder.schedule() }
    }

    private var howToCard: some View {
        card {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Schermata di blocco: tieni premuto, tocca Personalizza, scegli la riga dei widget e aggiungi Snus Counter.")
                    Text("Home: tieni premuto, tocca + in alto, cerca Snus Counter e scegli il formato medio per vedere lo storico.")
                    Text("Per aggiornare l'app, tocca il widget fuori dai pulsanti + e −.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            } label: {
                Label("Come si usa", systemImage: "questionmark.circle")
                    .font(.headline)
            }
            .tint(Color.snusMint)
        }
    }

    private var footer: some View {
        Group {
            if let lastSync {
                HStack(spacing: 0) {
                    Text("Ultimo aggiornamento: ")
                    Text(lastSync, format: Date.FormatStyle().day().month().hour().minute().locale(Self.italian))
                }
            } else {
                Text("Mai sincronizzata")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }

    private var toast: some View {
        Label("Dati sincronizzati", systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.snusMint))
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Azioni

    private func handle(_ url: URL) {
        guard SyncStore.importFrom(url: url) else { return }
        counts = SyncStore.counts()
        lastSync = SyncStore.lastSync
        now = Date()
        syncToken += 1
        withAnimation(.easeOut(duration: 0.25)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeIn(duration: 0.25)) { showToast = false }
        }
    }
}
