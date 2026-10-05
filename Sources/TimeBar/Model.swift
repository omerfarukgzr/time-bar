import AppKit
import Combine
import ServiceManagement

/// Sayacın durumu ve bütün eylemler. Menü çubuğu, panel, sağ tık menüsü ve kısayol hep buradan geçer.
@MainActor
final class Model: ObservableObject {
    @Published private(set) var session: Session? { didSet { save() } }
    @Published private(set) var now = Date()
    /// Geri sayım bitti, menü çubuğu kırmızı yanıp sönüyor.
    @Published private(set) var alertingSince: Date?
    /// Biten mesainin panelde gösterilen özeti.
    @Published var shownSummary: Summary?
    @Published private(set) var recents: [Preset] = []
    @Published private(set) var history: [Summary] = []
    @Published private(set) var update: AvailableUpdate?
    @Published private(set) var updateStatus: UpdateStatus = .idle

    enum UpdateStatus { case idle, installing, failed }

    private var ticker: Timer?
    private var updateTimer: Timer?
    /// Ekran kilitlenince molaya biz geçtiysek, kilit açılınca çalışmaya geri döneriz.
    private var autoAway = false
    private let defaults = UserDefaults.standard

    init() {
        session = load(Session.self, "session")
        recents = load([Preset].self, "recents") ?? []
        history = load([Summary].self, "history") ?? []
        restartTicker()

        update = UpdateChecker.stored
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in self?.checkForUpdate() }
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkForUpdate() }
        }

        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenLocked() }
        }
        center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenUnlocked() }
        }
    }

    // MARK: Eylemler

    func start(_ preset: Preset) {
        let now = Date()
        var s = Session(name: preset.name, mode: preset.mode, target: preset.target, startedAt: now)
        s.open(.work, at: now)
        alertingSince = nil
        shownSummary = nil
        autoAway = false
        session = s
        remember(preset)
        Notifier.shared.requestPermission()
        restartTicker()
    }

    /// Kısayolun ve sağ tık menüsündeki ilk satırın yaptığı iş.
    /// Sayaç yoksa son kullanılanı başlatır; başlatacak bir şey yoksa false döner.
    @discardableResult
    func primaryAction() -> Bool {
        guard let session else {
            guard let last = recents.first else { return false }
            start(last)
            return true
        }
        switch session.mode {
        case .shift:
            toggleSide()
        case .countdown where session.finishedAt != nil:
            dismiss()
        case .countdown, .stopwatch:
            session.isRunning ? pause() : resume()
        }
        return true
    }

    var primaryTitle: String {
        guard let session else { return recents.first.map { "\($0.name) başlat" } ?? "Başlat" }
        switch session.mode {
        case .shift: return session.side == .away ? "Çalışmaya dön" : "Molaya geç"
        case .countdown where session.finishedAt != nil: return "Tamam"
        default: return session.isRunning ? "Duraklat" : "Devam et"
        }
    }

    func pause() {
        modify { $0.close(at: Date()) }
    }

    func resume() {
        modify { $0.open(.work, at: Date()) }
    }

    func setSide(_ side: Side) {
        autoAway = false
        guard session?.mode == .shift, session?.side != side else { return }
        modify { $0.open(side, at: Date()) }
    }

    func toggleSide() {
        setSide(session?.side == .away ? .work : .away)
    }

    func addFiveMinutes() {
        guard session?.mode == .countdown else { return }
        let wasFinished = session?.finishedAt != nil
        modify { s in
            s.target = (s.target ?? 0) + 5 * 60
            if wasFinished {
                s.finishedAt = nil
                s.open(.work, at: Date())
            }
        }
        alertingSince = nil
        Notifier.shared.clear()
    }

    /// Aynı ayarla baştan başlatır.
    func restart() {
        guard let session else { return }
        start(Preset(name: session.name, mode: session.mode, target: session.target))
    }

    /// Sayacı kapatır. Mesai bittiyse özeti saklar ve panelde gösterir.
    func finish() {
        guard let session else { return }
        if session.mode == .shift {
            let summary = Summary(session: session, end: Date())
            history.insert(summary, at: 0)
            history = Array(history.prefix(60))
            store(history, "history")
            shownSummary = summary
        }
        dismiss()
    }

    func dismiss() {
        session = nil
        alertingSince = nil
        autoAway = false
        Notifier.shared.clear()
        restartTicker()
    }

    /// Kırmızı yanıp sönmeyi durdurur; "Bitti" yazısı kalır.
    func acknowledgeAlert() {
        alertingSince = nil
    }

    func clearHistory() {
        history = []
        store(history, "history")
    }

    func removeRecent(_ preset: Preset) {
        recents.removeAll { $0 == preset }
        store(recents, "recents")
    }

    private func remember(_ preset: Preset) {
        recents.removeAll { $0 == preset }
        recents.insert(preset, at: 0)
        recents = Array(recents.prefix(6))
        store(recents, "recents")
    }

    private func modify(_ change: (inout Session) -> Void) {
        guard var s = session else { return }
        change(&s)
        session = s
        restartTicker()
    }

    // MARK: Saat

    /// Saniye her değiştiğinde ekran güncellensin diye zamanlayıcıyı her durum değişikliğinde
    /// yeniden kurarız; böylece tikler o anki aralığın başlangıcıyla hizalı kalır.
    private func restartTicker() {
        ticker?.invalidate()
        ticker = nil
        now = Date()
        guard session != nil else { return }
        check()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common) // menü açıkken de işlesin
        ticker = timer
    }

    private func tick() {
        now = Date()
        check()
        // 30 saniye yanıp söndükten sonra sabit kırmızıda kal
        if let since = alertingSince, now.timeIntervalSince(since) > 30 { alertingSince = nil }
    }

    private func check() {
        guard var s = session else { return }
        switch s.mode {
        case .countdown:
            guard s.finishedAt == nil, s.isRunning, let target = s.target, s.elapsed(at: now) >= target else { return }
            // Bitişi tam hedefe denk gelen ana sabitle; tik gecikmesi süreye eklenmesin
            let end = now.addingTimeInterval(target - s.elapsed(at: now))
            s.close(at: end)
            s.finishedAt = end
            session = s
            alertingSince = now
            restartTicker()
            Sounds.play()
            Notifier.shared.post(.countdownFinished, title: "\(s.name) bitti",
                                 body: "\(TimeFormat.words(target)) doldu.")
        case .shift:
            guard let target = s.target, !s.targetNotified, s.span(at: now) >= target else { return }
            s.targetNotified = true
            session = s
            Sounds.play()
            let work = TimeFormat.words(s.total(.work, at: now))
            Notifier.shared.post(.shiftTarget, title: "\(TimeFormat.words(target)) doldu",
                                 body: "\(s.name): \(work) çalıştın. Bitirmek için dokun.")
        case .stopwatch:
            break
        }
    }

    // MARK: Ekran kilidi

    static let lockKey = "awayOnLock"

    private func screenLocked() {
        guard defaults.bool(forKey: Self.lockKey), session?.mode == .shift, session?.side == .work else { return }
        modify { $0.open(.away, at: Date()) }
        autoAway = true
    }

    private func screenUnlocked() {
        guard autoAway, session?.mode == .shift, session?.side == .away else { return }
        modify { $0.open(.work, at: Date()) }
        autoAway = false
    }

    // MARK: Kayıt

    private func save() {
        if let session { store(session, "session") } else { defaults.removeObject(forKey: "session") }
    }

    private func store<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    // MARK: Güncelleme

    func checkForUpdate() {
        guard UpdateChecker.isEnabled else {
            if update != nil { update = nil }
            return
        }
        Task {
            let found = await UpdateChecker.checkIfDue()
            if found != update { update = found }
        }
    }

    /// Yeni sürümü indirip kurar ve uygulamayı yeniden başlatır. Yerinde kurulamıyorsa Releases sayfasını açar.
    func installUpdate() {
        guard let update, updateStatus != .installing else { return }
        guard update.download != nil, Updater.canInstall else {
            NSWorkspace.shared.open(update.url)
            return
        }
        updateStatus = .installing
        Task {
            do {
                try await Task.detached { try await Updater.install(update) }.value
                Updater.relaunch()
            } catch {
                updateStatus = .failed
            }
        }
    }

    // MARK: Girişte başlat

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            if newValue { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        }
    }
}

enum Sounds {
    static let key = "finishSound"
    static let choices = ["Glass", "Hero", "Ping", "Purr", "Submarine", "Funk"]

    static func play() {
        let name = UserDefaults.standard.string(forKey: key) ?? "Glass"
        guard !name.isEmpty else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
