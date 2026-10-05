import Foundation

enum Mode: String, Codable, CaseIterable, Identifiable {
    case countdown, stopwatch, shift

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countdown: "Geri sayım"
        case .stopwatch: "Kronometre"
        case .shift: "Mesai"
        }
    }

    var symbol: String {
        switch self {
        case .countdown: "timer"
        case .stopwatch: "stopwatch"
        case .shift: "briefcase"
        }
    }
}

/// Mesai modunda saatin hangi tarafı işliyor.
enum Side: String, Codable { case work, away }

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
