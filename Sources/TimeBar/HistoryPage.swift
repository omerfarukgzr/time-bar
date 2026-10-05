import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

extension Mode {
    /// Geçmiş grafiğinde modun rengi.
    var color: Color {
        switch self {
        case .countdown: .blue
        case .stopwatch: .teal
        case .shift: .indigo
        case .pomodoro: .red
        }
    }
}

/// Ayarlar'daki Geçmiş sayfası: mod filtresi, haftalık grafik, haftanın özeti ve o haftanın kayıtları.
struct HistoryPage: View {
    @EnvironmentObject var model: Model
    @State private var weekStart: Date
    /// nil: bütün modlar.
    @State private var filter: Mode?
    @State private var confirmClear = false

    init(initialOffset: Int = 0) {
        let c = HistoryPage.calendar
        let thisWeek = c.dateInterval(of: .weekOfYear, for: Date())!.start
        _weekStart = State(initialValue: c.date(byAdding: .weekOfYear, value: initialOffset, to: thisWeek)!)
    }

    /// Hafta pazartesi başlar.
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "tr_TR")
        c.firstWeekday = 2
        return c
    }

    private var calendar: Calendar { Self.calendar }
    private var weekEnd: Date { calendar.date(byAdding: .day, value: 7, to: weekStart)! }
    private var isCurrentWeek: Bool { weekEnd > Date() }

    /// Bu haftanın, filtreye uyan kayıtları; gece yarısını geçen kayıt başladığı güne yazılır.
    private var entries: [Summary] {
        model.history
            .filter { $0.start >= weekStart && $0.start < weekEnd && (filter == nil || $0.kind == filter) }
            .sorted { $0.start > $1.start }
    }

    var body: some View {
        let entries = self.entries
        if model.history.isEmpty {
            Card {
                InfoRow("chart.bar.xaxis", "Henüz kayıt yok",
                        "Bir sayacı bitirdiğinde burada görünür. Dört modun hepsi kaydedilir.")
            }
        } else {
            filterBar
            weekBar
            Card { chart(entries).padding(14) }
            stats(entries)
            SectionLabel(entries.isEmpty ? "Bu hafta kayıt yok" : "Kayıtlar")
            if !entries.isEmpty {
                VStack(spacing: 10) {
                    ForEach(entries) { HistoryCard(summary: $0) }
                }
            }
        }
    }

    // MARK: Filtre ve hafta

    private var filterBar: some View {
        Picker("", selection: $filter) {
            Text("Tümü").tag(Mode?.none)
            ForEach(Mode.allCases) { Text($0.title).tag(Mode?.some($0)) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var weekBar: some View {
        HStack(spacing: 8) {
            Button { move(-1) } label: { Image(systemName: "chevron.left") }
                .help("Önceki hafta")
            Text(weekTitle)
                .font(.system(size: 13, weight: .semibold))
                .frame(minWidth: 170)
            Button { move(1) } label: { Image(systemName: "chevron.right") }
                .disabled(isCurrentWeek)
                .help("Sonraki hafta")
            if !isCurrentWeek {
                Button("Bu hafta") {
                    weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            }
            Spacer()
            Menu {
                Button("CSV olarak kaydet…", action: exportCSV)
                Divider()
                Button("Bütün geçmişi sil…", role: .destructive) { confirmClear = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .confirmationDialog("Bütün geçmiş silinsin mi?", isPresented: $confirmClear) {
                Button("Sil", role: .destructive) { model.clearHistory() }
            } message: {
                Text("\(model.history.count) kayıt silinir. Bu geri alınamaz. Önce CSV olarak kaydedebilirsin.")
            }
        }
    }

    private var weekTitle: String {
        let last = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        let start = weekStart.formatted(.dateTime.day().month(.abbreviated).locale(calendar.locale!))
        let end = last.formatted(.dateTime.day().month(.abbreviated).year().locale(calendar.locale!))
        return "\(start) – \(end)"
    }

    private func move(_ weeks: Int) {
        weekStart = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart)!
    }

    // MARK: Grafik

    private struct DayBar: Identifiable {
        let day: Date
        let kind: String
        let hours: Double
        var id: String { "\(day.timeIntervalSince1970)\(kind)" }
    }

    /// Tümü seçiliyken modlara göre, bir mod seçiliyken çalışma ve mola olarak bölünmüş günlük süreler.
    private func bars(_ entries: [Summary]) -> [DayBar] {
        (0..<7).flatMap { offset -> [DayBar] in
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            let todays = entries.filter { $0.start >= day && $0.start < next }
            if let filter {
                let (work, away) = Self.sideNames(filter)
                return [
                    DayBar(day: day, kind: work, hours: todays.reduce(0) { $0 + $1.total(.work) } / 3600),
                    DayBar(day: day, kind: away, hours: todays.reduce(0) { $0 + $1.total(.away) } / 3600),
                ]
            }
            return Mode.allCases.map { mode in
                DayBar(day: day, kind: mode.title, hours: todays.filter { $0.kind == mode }.reduce(0) { $0 + $1.active } / 3600)
            }
        }
    }

    /// Çalışma ve mola tarafının o moddaki adı.
    static func sideNames(_ mode: Mode) -> (String, String) {
        switch mode {
        case .shift: ("Çalışma", "Mola")
        case .pomodoro: ("Odak", "Mola")
        case .countdown, .stopwatch: ("Süre", "Mola")
        }
    }

    private var colorScale: KeyValuePairs<String, Color> {
        guard let filter else {
            return ["Geri sayım": Mode.countdown.color, "Kronometre": Mode.stopwatch.color,
                    "Mesai": Mode.shift.color, "Pomodoro": Mode.pomodoro.color]
        }
        let (work, away) = Self.sideNames(filter)
        return [work: filter.color, away: Color.away]
    }

    private func chart(_ entries: [Summary]) -> some View {
        Chart(bars(entries)) { bar in
            BarMark(x: .value("Gün", bar.day, unit: .day), y: .value("Saat", bar.hours))
                .foregroundStyle(by: .value("Tür", bar.kind))
                .cornerRadius(3)
        }
        .chartForegroundStyleScale(colorScale)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(calendar.locale!), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let h = value.as(Double.self) { Text(h > 0 && h < 1 ? "\(Int(h * 60)) dk" : "\(Int(h)) sa") }
                }
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 170)
    }

    // MARK: Özet

    private func stats(_ entries: [Summary]) -> some View {
        let days = Set(entries.map { calendar.startOfDay(for: $0.start) }).count
        let work = entries.reduce(0) { $0 + $1.total(.work) }
        let away = entries.reduce(0) { $0 + $1.total(.away) }
        let active = work + away
        let ratio = active > 0 ? Int((away / active * 100).rounded()) : 0
        let average = entries.isEmpty ? "–" : TimeFormat.words(work / Double(entries.count))
        let tiles: [(String, String, Color)]
        switch filter {
        case nil:
            let byMode = Dictionary(grouping: entries, by: \.kind).mapValues { $0.reduce(0) { $0 + $1.active } }
            let top = byMode.max { $0.value < $1.value }?.key
            tiles = [("Toplam süre", TimeFormat.words(active), .primary),
                     ("Günlük ortalama", days > 0 ? TimeFormat.words(active / Double(days)) : "–", .primary),
                     ("En çok", top?.title ?? "–", top?.color ?? .secondary),
                     ("Kayıt", "\(entries.count)", .secondary)]
        case .shift?:
            tiles = [("Toplam çalışma", TimeFormat.words(work), Mode.shift.color),
                     ("Günlük ortalama", days > 0 ? TimeFormat.words(work / Double(days)) : "–", Mode.shift.color),
                     ("Mola oranı", "%\(ratio)", .away),
                     ("Mesai", "\(entries.count)", .secondary)]
        case .pomodoro?:
            tiles = [("Odak süresi", TimeFormat.words(work), Mode.pomodoro.color),
                     ("Biten odak", "\(entries.reduce(0) { $0 + ($1.rounds ?? 0) })", Mode.pomodoro.color),
                     ("Mola oranı", "%\(ratio)", .away),
                     ("Oturum", "\(entries.count)", .secondary)]
        case .countdown?:
            let done = entries.filter { $0.completed == true }.count
            tiles = [("Toplam süre", TimeFormat.words(work), Mode.countdown.color),
                     ("Tamamlanan", "\(done) / \(entries.count)", Mode.countdown.color),
                     ("Ortalama", average, .secondary),
                     ("Kayıt", "\(entries.count)", .secondary)]
        case .stopwatch?:
            tiles = [("Toplam süre", TimeFormat.words(work), Mode.stopwatch.color),
                     ("En uzun", TimeFormat.words(entries.map(\.active).max() ?? 0), Mode.stopwatch.color),
                     ("Ortalama", average, .secondary),
                     ("Kayıt", "\(entries.count)", .secondary)]
        }
        return HStack(spacing: 10) {
            ForEach(tiles, id: \.0) { StatTile(title: $0.0, value: $0.1, color: $0.2) }
        }
    }

    private struct StatTile: View {
        let title: String, value: String, color: Color
        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
                Text(value).font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.045)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
        }
    }

    // MARK: CSV

    /// Noktalı virgüllü CSV; Türkçe Excel virgülü ondalık ayırıcı saydığı için.
    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "Time Bar geçmişi.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let date = DateFormatter()
        date.dateFormat = "yyyy-MM-dd HH:mm"
        func minutes(_ t: TimeInterval) -> String { String(Int((t / 60).rounded())) }
        // Ad =, +, -, @ ile başlıyorsa Excel onu formül sayıp çalıştırır; başına ' koyup düz yazı yap
        func field(_ s: String) -> String {
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: s.hasPrefix) ? "'" + s : s
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var lines = ["Mod;Ad;Başlangıç;Bitiş;Süre (dk);Çalışma/Odak (dk);Mola (dk);Mola sayısı;Biten odak;Tamamlandı"]
        for s in model.history.sorted(by: { $0.start < $1.start }) {
            lines.append([s.kind.title, field(s.name), date.string(from: s.start), date.string(from: s.end),
                          minutes(s.active), minutes(s.total(.work)), minutes(s.total(.away)), "\(s.breaks.count)",
                          s.rounds.map(String.init) ?? "", s.completed.map { $0 ? "evet" : "hayır" } ?? ""]
                .joined(separator: ";"))
        }
        // BOM: Excel UTF-8'i ancak böyle tanıyor, yoksa Türkçe harfler bozuk çıkar
        try? ("\u{FEFF}" + lines.joined(separator: "\r\n")).write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Bir kaydın kartı: mod ikonu, ad, gün, şerit; açılınca ayrıntılar.
struct HistoryCard: View {
    @EnvironmentObject var model: Model
    let summary: Summary
    @State private var expanded = false
    @State private var confirmDelete = false

    var body: some View {
        let mode = summary.kind
        Card {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    ModeIcon(mode: mode, size: 13).foregroundStyle(mode.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.name).font(.system(size: 13, weight: .semibold))
                        Text(dateText).font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeFormat.words(summary.total(.work)))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(mode.color)
                        Text(subtitle)
                            .font(.system(size: 11.5).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Timeline(segments: summary.segments, start: summary.start,
                         end: max(summary.end, summary.start.addingTimeInterval(mode == .shift ? summary.target ?? 0 : 0)),
                         now: summary.end, workColor: mode.color)
                HStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(expanded ? 90 : 0))
                            Text(summary.breaks.isEmpty ? "Ayrıntılar" : "\(summary.breaks.count) mola · ayrıntılar")
                        }
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(confirmDelete ? "Emin misin? Sil" : "Sil") {
                        if confirmDelete {
                            model.deleteSummary(summary)
                        } else {
                            confirmDelete = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmDelete = false }
                        }
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11.5))
                    .foregroundStyle(confirmDelete ? Color.red : .secondary)
                }
                if expanded { details }
            }
            .padding(14)
        }
    }

    /// Sağ üstteki ikinci satır, moda göre.
    private var subtitle: String {
        switch summary.kind {
        case .shift: return "\(TimeFormat.words(summary.total(.away))) mola"
        case .pomodoro: return "\(summary.rounds ?? 0) odak · \(TimeFormat.words(summary.total(.away))) mola"
        case .countdown:
            guard let target = summary.target else { return "" }
            return summary.completed == true ? "\(TimeFormat.words(target)) tamamlandı" : "\(TimeFormat.words(target)) hedefti, yarıda kaldı"
        case .stopwatch:
            let pauses = max(summary.segments.count - 1, 0)
            return pauses > 0 ? "\(pauses) kez duraklatıldı" : "kesintisiz"
        }
    }

    private var details: some View {
        let (workName, _) = HistoryPage.sideNames(summary.kind)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(summary.breaks.enumerated()), id: \.offset) { _, segment in
                HStack {
                    Circle().fill(Color.away).frame(width: 6, height: 6)
                    Text("\(TimeFormat.hour(segment.start))–\(TimeFormat.hour(segment.end ?? summary.end))")
                        .monospacedDigit()
                    Spacer()
                    Text(TimeFormat.words(segment.duration(at: summary.end))).foregroundStyle(.secondary)
                }
            }
            if !summary.breaks.isEmpty { Divider().padding(.vertical, 2) }
            line("Başlangıç – bitiş", "\(TimeFormat.hour(summary.start))–\(TimeFormat.hour(summary.end))")
            if summary.span - summary.active >= 60 {
                line("Duraklatılan süre", TimeFormat.words(summary.span - summary.active))
            }
            line("En uzun kesintisiz \(workName.lowercased())", TimeFormat.words(summary.longest(.work)))
            if !summary.breaks.isEmpty {
                line("Ortalama mola", TimeFormat.words(summary.total(.away) / Double(summary.breaks.count)))
            }
            if summary.kind == .shift, let target = summary.target {
                line("Hedef", "\(TimeFormat.words(target)) · \(summary.span >= target ? "tamamlandı" : "\(TimeFormat.words(target - summary.span)) eksik")")
            }
        }
        .font(.system(size: 12))
    }

    private func line(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }

    private var dateText: String {
        let day = summary.start.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "tr_TR")))
        return "\(day) · \(TimeFormat.hour(summary.start))–\(TimeFormat.hour(summary.end))"
    }
}
