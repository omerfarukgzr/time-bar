import AppKit
import Charts
import SwiftUI
import UniformTypeIdentifiers

/// Ayarlar'daki Geçmiş sayfası: haftalık grafik, haftanın özeti ve o haftanın mesaileri.
struct HistoryPage: View {
    @EnvironmentObject var model: Model
    @State private var weekStart = HistoryPage.calendar.dateInterval(of: .weekOfYear, for: Date())!.start

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

    /// Bu haftanın mesaileri; gece yarısını geçen mesai başladığı güne yazılır.
    private var shifts: [Summary] {
        model.history.filter { $0.start >= weekStart && $0.start < weekEnd }.sorted { $0.start > $1.start }
    }

    var body: some View {
        if model.history.isEmpty {
            Card {
                InfoRow("chart.bar.xaxis", "Henüz biten mesai yok",
                        "Mesai modunda bir sayaç başlatıp bitirdiğinde burada görünür.")
            }
        } else {
            weekBar
            Card { chart.padding(14) }
            stats
            SectionLabel(shifts.isEmpty ? "Bu hafta biten mesai yok" : "Mesailer")
            if !shifts.isEmpty {
                VStack(spacing: 10) {
                    ForEach(shifts) { ShiftCard(summary: $0) }
                }
            }
        }
    }

    // MARK: Hafta seçici

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
            Button {
                exportCSV()
            } label: {
                Label("CSV olarak kaydet…", systemImage: "square.and.arrow.down")
            }
            .help("Bütün geçmişi Excel'de açılabilen bir dosyaya kaydeder")
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

    private var bars: [DayBar] {
        (0..<7).flatMap { offset -> [DayBar] in
            let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            let next = calendar.date(byAdding: .day, value: 1, to: day)!
            let todays = shifts.filter { $0.start >= day && $0.start < next }
            return [
                DayBar(day: day, kind: "Çalışma", hours: todays.reduce(0) { $0 + $1.total(.work) } / 3600),
                DayBar(day: day, kind: "Mola", hours: todays.reduce(0) { $0 + $1.total(.away) } / 3600),
            ]
        }
    }

    private var chart: some View {
        Chart(bars) { bar in
            BarMark(x: .value("Gün", bar.day, unit: .day), y: .value("Saat", bar.hours))
                .foregroundStyle(by: .value("Tür", bar.kind))
                .cornerRadius(3)
        }
        .chartForegroundStyleScale(["Çalışma": Color.work, "Mola": Color.away])
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated).locale(calendar.locale!), centered: true)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { if let h = value.as(Double.self) { Text("\(Int(h)) sa") } }
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 170)
    }

    // MARK: Özet

    private var stats: some View {
        let work = shifts.reduce(0) { $0 + $1.total(.work) }
        let away = shifts.reduce(0) { $0 + $1.total(.away) }
        let days = Set(shifts.map { calendar.startOfDay(for: $0.start) }).count
        let ratio = work + away > 0 ? Int((away / (work + away) * 100).rounded()) : 0
        return HStack(spacing: 10) {
            StatTile(title: "Toplam çalışma", value: TimeFormat.words(work), color: .work)
            StatTile(title: "Günlük ortalama", value: days > 0 ? TimeFormat.words(work / Double(days)) : "–", color: .work)
            StatTile(title: "Mola oranı", value: "%\(ratio)", color: .away)
            StatTile(title: "Mesai", value: "\(shifts.count)", color: .secondary)
        }
    }

    private struct StatTile: View {
        let title: String, value: String, color: Color
        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(color)
                Text(value).font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.8)
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
        func field(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["Ad;Başlangıç;Bitiş;Toplam (dk);Çalışma (dk);Mola (dk);Mola sayısı;En uzun çalışma (dk)"]
        for s in model.history.sorted(by: { $0.start < $1.start }) {
            lines.append([field(s.name), date.string(from: s.start), date.string(from: s.end), minutes(s.span),
                          minutes(s.total(.work)), minutes(s.total(.away)), "\(s.breaks.count)", minutes(s.longest(.work))]
                .joined(separator: ";"))
        }
        // BOM: Excel UTF-8'i ancak böyle tanıyor, yoksa Türkçe harfler bozuk çıkar
        try? ("\u{FEFF}" + lines.joined(separator: "\r\n")).write(to: url, atomically: true, encoding: .utf8)
    }
}

/// Bir mesainin kartı: ad, gün, saat aralığı, şerit; açılınca molalar tek tek.
struct ShiftCard: View {
    @EnvironmentObject var model: Model
    let summary: Summary
    @State private var expanded = false
    @State private var confirmDelete = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.name).font(.system(size: 13, weight: .semibold))
                        Text(dateText).font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(TimeFormat.words(summary.total(.work)))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.work)
                        Text("\(TimeFormat.words(summary.total(.away))) mola")
                            .font(.system(size: 11.5).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                Timeline(segments: summary.segments, start: summary.start,
                         end: max(summary.end, summary.start.addingTimeInterval(summary.target ?? 0)), now: summary.end)
                HStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .rotationEffect(.degrees(expanded ? 90 : 0))
                            Text(summary.breaks.isEmpty ? "Mola yok" : "\(summary.breaks.count) mola · ayrıntılar")
                        }
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(summary.breaks.isEmpty && summary.target == nil)
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

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            line("En uzun kesintisiz çalışma", TimeFormat.words(summary.longest(.work)))
            if !summary.breaks.isEmpty {
                line("Ortalama mola", TimeFormat.words(summary.total(.away) / Double(summary.breaks.count)))
            }
            if let target = summary.target {
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
