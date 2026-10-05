import Foundation

enum Mode: String, Codable, CaseIterable, Identifiable {
    case countdown, stopwatch, shift, pomodoro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countdown: "Geri sayım"
        case .stopwatch: "Kronometre"
        case .shift: "Mesai"
        case .pomodoro: "Pomodoro"
        }
    }

    var detail: String {
        switch self {
        case .countdown: "Süre dolunca bildirim gelir."
        case .stopwatch: "Sıfırdan yukarı sayar."
        case .shift: "Satranç saati gibi çalışma ve mola sürelerini ayrı sayar."
        case .pomodoro: "Odak ve mola aralıklarını sırayla, kendiliğinden sayar."
        }
    }

    static let enabledKey = "enabledModes"

    /// Panelde seçili mod; sayaç yokken menü çubuğunda bunun ikonu görünür.
    static var selected: Mode {
        let modes = enabled
        let last = UserDefaults.standard.string(forKey: "lastMode").flatMap(Mode.init(rawValue:))
        return last.flatMap { modes.contains($0) ? $0 : nil } ?? modes[0]
    }

    /// Ayarlar › Modlar'daki varsayılan süre (geri sayım ve mesai için).
    var defaultTarget: TimeInterval? {
        let d = UserDefaults.standard
        switch self {
        case .countdown:
            let m = d.object(forKey: "countdownMinutes") as? Int ?? 60
            return TimeInterval(max(m, 1) * 60)
        case .shift:
            let m = d.object(forKey: "shiftMinutes") as? Int ?? 480
            return m > 0 ? TimeInterval(m * 60) : nil
        case .stopwatch, .pomodoro:
            return nil
        }
    }

    /// Panelde gösterilen modlar (Ayarlar › Modlar). En az biri hep açık.
    static var enabled: [Mode] {
        let raw = UserDefaults.standard.string(forKey: enabledKey) ?? allCases.map(\.rawValue).joined(separator: ",")
        let set = Set(raw.split(separator: ",").map(String.init))
        let modes = allCases.filter { set.contains($0.rawValue) }
        return modes.isEmpty ? [.countdown] : modes
    }

    var symbol: String {
        switch self {
        case .countdown: "timer"
        case .stopwatch: "stopwatch"
        case .shift: "briefcase"
        case .pomodoro: Tomato.name
        }
    }
}

/// Mesai modunda saatin hangi tarafı işliyor.
enum Side: String, Codable { case work, away }

/// Pomodoro aşaması.
enum Phase: String, Codable {
    case focus, shortBreak, longBreak

    var side: Side { self == .focus ? .work : .away }

    var title: String {
        switch self {
        case .focus: "Odak"
        case .shortBreak: "Kısa mola"
        case .longBreak: "Uzun mola"
        }
    }
}

/// Pomodoro ayarları (Ayarlar › Modlar), dakika cinsinden.
enum PomodoroSettings {
    static var focus: Int { value("pomoFocus", 25) }
    static var shortBreak: Int { value("pomoShort", 5) }
    static var longBreak: Int { value("pomoLong", 15) }
    /// Kaç odakta bir uzun mola.
    static var rounds: Int { max(1, value("pomoRounds", 4)) }
    static var autoStart: Bool { UserDefaults.standard.object(forKey: "pomoAuto") as? Bool ?? true }

    static func length(_ phase: Phase) -> TimeInterval {
        TimeInterval(60 * {
            switch phase {
            case .focus: focus
            case .shortBreak: shortBreak
            case .longBreak: longBreak
            }
        }())
    }

    /// round: biten odak sayısı.
    static func next(after phase: Phase, round: Int) -> Phase {
        guard phase == .focus else { return .focus }
        return round % rounds == 0 ? .longBreak : .shortBreak
    }

    private static func value(_ key: String, _ fallback: Int) -> Int {
        let v = UserDefaults.standard.integer(forKey: key)
        return v > 0 ? v : fallback
    }
}

/// Saatin kesintisiz işlediği bir aralık. Bitişi yoksa hâlâ işliyor.
struct Segment: Codable, Equatable {
    var side: Side
    var start: Date
    var end: Date?

    func duration(at now: Date) -> TimeInterval { max(0, (end ?? now).timeIntervalSince(start)) }
}

/// Çalışan sayaç. Süreler saniye saniye azaltılmaz, aralıkların başlangıç ve bitiş
/// saatlerinden hesaplanır; Mac uykuya geçse ya da uygulama kapanıp açılsa da kaymaz.
struct Session: Codable, Equatable {
    var name: String
    var mode: Mode
    /// Geri sayımda toplam süre, mesaide hedef mesai süresi (nil: hedef yok).
    var target: TimeInterval?
    var startedAt: Date
    var segments: [Segment] = []
    /// Geri sayımın bittiği an.
    var finishedAt: Date?
    /// Mesai hedefi bildirimi gönderildi mi.
    var targetNotified = false
    // Pomodoro. Opsiyonel: eski sürümden kalan kayıtlı sayaç da açılabilsin.
    var phase: Phase?
    /// Biten odak sayısı.
    var round: Int?
    /// Aşamanın başladığı aralığın sırası.
    var phaseStart: Int?
    /// Aşama başladığında ayarlardan alınan süre; ortada ayar değişirse sayaç zıplamasın.
    var phaseLength: TimeInterval?

    var current: Segment? {
        guard let last = segments.last, last.end == nil else { return nil }
        return last
    }

    var isRunning: Bool { current != nil }
    var side: Side? { current?.side }

    func total(_ side: Side, at now: Date) -> TimeInterval {
        segments.filter { $0.side == side }.reduce(0) { $0 + $1.duration(at: now) }
    }

    /// Geri sayım ve kronometrede işleyen süre.
    func elapsed(at now: Date) -> TimeInterval { total(.work, at: now) }

    func remaining(at now: Date) -> TimeInterval { max(0, (target ?? 0) - elapsed(at: now)) }

    /// Mesainin başından beri geçen süre (duvar saati).
    func span(at now: Date) -> TimeInterval { now.timeIntervalSince(startedAt) }

    /// Şu anki kesintisiz aralığın süresi ("bu mola 12 dk").
    func currentStretch(at now: Date) -> TimeInterval { current?.duration(at: now) ?? 0 }

    func phaseElapsed(at now: Date) -> TimeInterval {
        let from = min(phaseStart ?? 0, segments.count)
        return segments[from...].reduce(0) { $0 + $1.duration(at: now) }
    }

    func phaseRemaining(at now: Date) -> TimeInterval { max(0, (phaseLength ?? 0) - phaseElapsed(at: now)) }

    /// Pomodoro'da bir sonraki aşamaya geçer. Bitişi "at" anına sabitler; running ise yeni aşama hemen işler.
    mutating func advancePhase(at date: Date, running: Bool) {
        close(at: date)
        let current = phase ?? .focus
        var done = round ?? 0
        if current == .focus { done += 1 }
        let next = PomodoroSettings.next(after: current, round: done)
        round = done
        phase = next
        phaseStart = segments.count
        phaseLength = PomodoroSettings.length(next)
        if running { segments.append(Segment(side: next.side, start: date)) }
    }

    mutating func open(_ side: Side, at now: Date) {
        close(at: now)
        segments.append(Segment(side: side, start: now))
    }

    mutating func close(at date: Date) {
        guard let i = segments.indices.last, segments[i].end == nil else { return }
        segments[i].end = max(date, segments[i].start)
    }
}

/// Son kullanılan sayaç ayarı; tek tıkla yeniden başlatmak için.
struct Preset: Codable, Equatable, Identifiable {
    var name: String
    var mode: Mode
    var target: TimeInterval?

    var id: String { "\(mode.rawValue)|\(name)|\(target ?? -1)" }

    var detail: String {
        if mode == .pomodoro { return "\(PomodoroSettings.focus)/\(PomodoroSettings.shortBreak) dk" }
        guard let target else { return mode == .shift ? "Hedefsiz" : mode.title }
        return TimeFormat.words(target)
    }
}

/// Biten mesainin özeti.
struct Summary: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var start: Date
    var end: Date
    var target: TimeInterval?
    var segments: [Segment]

    init(session: Session, end: Date) {
        name = session.name
        start = session.startedAt
        self.end = end
        target = session.target
        var s = session
        s.close(at: end)
        // Birkaç saniyelik yanlış basışlar istatistiği bozmasın: onları at, kalan aynı taraf bloklarını birleştir
        var merged: [Segment] = []
        for segment in s.segments where segment.duration(at: end) >= 5 {
            if let last = merged.last, last.side == segment.side {
                merged[merged.count - 1].end = segment.end
            } else {
                merged.append(segment)
            }
        }
        segments = merged
    }

    func total(_ side: Side) -> TimeInterval {
        segments.filter { $0.side == side }.reduce(0) { $0 + $1.duration(at: end) }
    }

    var span: TimeInterval { end.timeIntervalSince(start) }
    var breaks: [Segment] { segments.filter { $0.side == .away } }

    func longest(_ side: Side) -> TimeInterval {
        segments.filter { $0.side == side }.map { $0.duration(at: end) }.max() ?? 0
    }
}

enum TimeFormat {
    /// 1:05:00, 42:15
    static func clock(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        let h = s / 3600, m = s / 60 % 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// 1 sa 5 dk, 42 dk, 30 sn
    static func words(_ t: TimeInterval) -> String {
        let s = max(0, Int(t))
        if s < 60 { return "\(s) sn" }
        let h = s / 3600, m = s / 60 % 60
        if h == 0 { return "\(m) dk" }
        return m == 0 ? "\(h) sa" : "\(h) sa \(m) dk"
    }

    /// Menü çubuğu için "1 sa 5 dk" biçiminde, sadece dakika çözünürlüğünde.
    static func compact(_ t: TimeInterval, roundUp: Bool) -> String {
        let minutes = Int(roundUp ? (t / 60).rounded(.up) : (t / 60).rounded(.down))
        if minutes < 1 { return roundUp && t > 0 ? "<1 dk" : "0 dk" }
        return words(TimeInterval(minutes * 60))
    }

    static func hour(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}
