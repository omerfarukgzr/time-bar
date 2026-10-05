import AppKit
import SwiftUI

extension Color {
    static let work = Color.accentColor
    static let away = Color.orange
}

struct PanelContent: View {
    @EnvironmentObject var model: Model
    var openSettings: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let update = model.update {
                UpdateRow(update: update)
                Divider()
            }
            if let session = model.session {
                switch session.mode {
                case .countdown: CountdownView(session: session)
                case .stopwatch: StopwatchView(session: session)
                case .shift: ShiftView(session: session)
                case .pomodoro: PomodoroView(session: session)
                }
            } else if let summary = model.shownSummary {
                SummaryView(summary: summary)
            } else {
                NewSessionView()
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: StatusController.width)
    }

    private var footer: some View {
        HStack {
            FooterButton(action: openSettings) {
                Label("Ayarlar…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            Spacer()
            FooterButton(action: { NSApp.terminate(nil) }) {
                Label("Çık", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, -6)
    }
}

// MARK: Yeni sayaç

struct NewSessionView: View {
    @EnvironmentObject var model: Model
    @AppStorage("lastMode") private var lastMode: Mode = .countdown
    @AppStorage(Mode.enabledKey) private var enabledRaw = ""
    @AppStorage("countdownMinutes") private var countdownDefault = 60
    @AppStorage("shiftMinutes") private var shiftDefault = 480
    @State private var name = ""
    @State private var hours = 1
    @State private var minutes = 0
    @State private var hasTarget = true

    private var modes: [Mode] { _ = enabledRaw; return Mode.enabled }
    private var mode: Mode { modes.contains(lastMode) ? lastMode : modes[0] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if modes.count > 1 {
                ModeTabs(modes: modes, selection: Binding(get: { mode }, set: { lastMode = $0; applyDefaults() }))
            }

            TextField(placeholder, text: $name)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)
                .onSubmit(start)

            switch mode {
            case .countdown, .shift: durationPicker
            case .pomodoro: PomodoroPlan()
            case .stopwatch: EmptyView()
            }

            Button(action: start) {
                Label("Başlat", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(mode == .countdown && total == 0)
        }
        .onAppear(perform: applyDefaults)
    }

    private var placeholder: String {
        switch mode {
        case .countdown: "Ad (örn. Ders)"
        case .stopwatch: "Ad (örn. Koşu)"
        case .shift: "Ad (örn. Mesai)"
        case .pomodoro: "Ad (örn. Okuma)"
        }
    }

    private var total: Int { hours * 3600 + minutes * 60 }

    private var presets: [(String, Int)] {
        mode == .shift
            ? [("4 sa", 240), ("6 sa", 360), ("8 sa", 480), ("9 sa", 540)]
            : [("15 dk", 15), ("25 dk", 25), ("45 dk", 45), ("1 sa", 60), ("1,5 sa", 90)]
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                ForEach(presets, id: \.1) { label, value in
                    Chip(label, selected: hasTarget && total == value * 60) {
                        hasTarget = true
                        hours = value / 60
                        minutes = value % 60
                    }
                }
                if mode == .shift {
                    Chip("Hedefsiz", selected: !hasTarget) { hasTarget = false }
                }
            }
            if hasTarget {
                HStack(spacing: 12) {
                    Stepper("\(hours) sa", value: $hours, in: 0...23)
                    Stepper("\(minutes) dk", value: $minutes, in: 0...55, step: 5)
                }
                .font(.system(size: 12).monospacedDigit())
            }
        }
    }

    /// Ayarlar › Modlar'daki varsayılan süre.
    private func applyDefaults() {
        let value = mode == .shift ? shiftDefault : countdownDefault
        hasTarget = value > 0
        let m = value > 0 ? value : 480
        hours = m / 60
        minutes = m % 60
    }

    private func start() {
        guard !(mode == .countdown && total == 0) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let timed = (mode == .countdown || mode == .shift) && hasTarget && total > 0
        model.start(Preset(name: trimmed.isEmpty ? mode.title : trimmed, mode: mode, target: timed ? TimeInterval(total) : nil))
        name = ""
    }
}

/// Mod seçici: ikon üstte, ad altta; Ayarlar'daki sekmelere benzer.
struct ModeTabs: View {
    let modes: [Mode]
    @Binding var selection: Mode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(modes) { mode in
                let selected = mode == selection
                Button { selection = mode } label: {
                    VStack(spacing: 3) {
                        ModeIcon(mode: mode, size: 15)
                        Text(mode.title).font(.system(size: 10.5, weight: selected ? .semibold : .regular))
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04)))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Pomodoro'nun Ayarlar'dan gelen planı: odak, kısa mola, uzun mola.
struct PomodoroPlan: View {
    @AppStorage("pomoFocus") private var focus = 25
    @AppStorage("pomoShort") private var shortBreak = 5
    @AppStorage("pomoLong") private var longBreak = 15
    @AppStorage("pomoRounds") private var rounds = 4

    var body: some View {
        HStack(spacing: 6) {
            tile("Odak", focus, .work)
            tile("Mola", shortBreak, .away)
            tile("\(rounds) turda bir", longBreak, .away)
        }
    }

    private func tile(_ title: String, _ minutes: Int, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text("\(minutes) dk").font(.system(size: 14, weight: .semibold).monospacedDigit())
            Text(title).font(.system(size: 10.5)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.1)))
    }
}

struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    init(_ title: String, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(Capsule().fill(selected ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.07)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: Geri sayım

struct CountdownView: View {
    @EnvironmentObject var model: Model
    let session: Session

    var body: some View {
        let now = model.now
        let target = max(session.target ?? 1, 1)
        let remaining = session.remaining(at: now)
        let finished = session.finishedAt != nil
        VStack(alignment: .leading, spacing: 10) {
            Header(session: session)
            Text(finished ? "Süre doldu" : TimeFormat.clock(remaining.rounded(.up)))
                .font(.system(size: 38, weight: .light).monospacedDigit())
                .foregroundStyle(finished ? Color.red : remaining <= 60 ? .orange : .primary)
                .frame(maxWidth: .infinity)
            ProgressView(value: 1 - remaining / target)
                .tint(remaining <= 60 ? .orange : .accentColor)
            Text(caption(now: now, remaining: remaining))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            HStack {
                if finished {
                    Button("+5 dk") { model.addFiveMinutes() }
                    Button("Tekrar") { model.restart() }
                    Spacer()
                    Button("Tamam") { model.dismiss() }.keyboardShortcut(.defaultAction)
                } else {
                    PrimaryButton()
                    Button("+5 dk") { model.addFiveMinutes() }
                    Button { model.restart() } label: { Image(systemName: "arrow.counterclockwise") }
                        .help("Baştan başlat")
                    Spacer()
                    Button("Bitir") { model.finish() }
                }
            }
            .controlSize(.regular)
        }
    }

    private func caption(now: Date, remaining: TimeInterval) -> String {
        let total = "Toplam \(TimeFormat.words(session.target ?? 0))"
        if let end = session.finishedAt { return "\(TimeFormat.hour(end))'de bitti · \(total)" }
        guard session.isRunning else { return "Duraklatıldı · \(total)" }
        return "Bitiş \(TimeFormat.hour(now.addingTimeInterval(remaining))) · \(total)"
    }
}

// MARK: Kronometre

struct StopwatchView: View {
    @EnvironmentObject var model: Model
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Header(session: session)
            Text(TimeFormat.clock(session.elapsed(at: model.now)))
                .font(.system(size: 38, weight: .light).monospacedDigit())
                .frame(maxWidth: .infinity)
            Text(session.isRunning ? "\(TimeFormat.hour(session.startedAt))'de başladı" : "Duraklatıldı")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            HStack {
                PrimaryButton()
                Button { model.restart() } label: { Image(systemName: "arrow.counterclockwise") }
                    .help("Sıfırla")
                Spacer()
                Button("Bitir") { model.finish() }
            }
        }
    }
}

// MARK: Pomodoro

struct PomodoroView: View {
    @EnvironmentObject var model: Model
    let session: Session

    var body: some View {
        let now = model.now
        let phase = session.phase ?? .focus
        let length = max(session.phaseLength ?? 1, 1)
        let remaining = session.phaseRemaining(at: now)
        let color: Color = phase == .focus ? .work : .away
        let rounds = PomodoroSettings.rounds
        let done = phase == .longBreak ? rounds : (session.round ?? 0) % rounds
        VStack(alignment: .leading, spacing: 10) {
            Header(session: session)
            HStack {
                Label(phase.title, systemImage: phase == .focus ? "brain.head.profile" : "cup.and.saucer.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Capsule().fill(color.opacity(0.15)))
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<rounds, id: \.self) { i in
                        Circle()
                            .fill(i < done ? Color.work : Color.primary.opacity(0.15))
                            .frame(width: 7, height: 7)
                    }
                }
                .help("\(session.round ?? 0) odak tamamlandı")
            }
            Text(TimeFormat.clock(remaining.rounded(.up)))
                .font(.system(size: 38, weight: .light).monospacedDigit())
                .frame(maxWidth: .infinity)
            ProgressView(value: 1 - remaining / length).tint(color)
            Text(caption(phase: phase))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            HStack {
                PrimaryButton()
                Button { model.skipPhase() } label: { Image(systemName: "forward.end.fill") }
                    .help("Bu aşamayı atla")
                Spacer()
                Button("Bitir") { model.finish() }
            }
        }
    }

    private func caption(phase: Phase) -> String {
        let next = PomodoroSettings.next(after: phase, round: (session.round ?? 0) + (phase == .focus ? 1 : 0))
        let nextText = "Sıradaki: \(TimeFormat.words(PomodoroSettings.length(next))) \(next.title.lowercased())"
        if !session.isRunning { return session.phaseElapsed(at: model.now) == 0 ? "Hazır · \(nextText)" : "Duraklatıldı · \(nextText)" }
        return nextText
    }
}

// MARK: Mesai

struct ShiftView: View {
    @EnvironmentObject var model: Model
    let session: Session
    @State private var confirmFinish = false

    var body: some View {
        let now = model.now
        let work = session.total(.work, at: now)
        let away = session.total(.away, at: now)
        VStack(alignment: .leading, spacing: 10) {
            Header(session: session)
            HStack(spacing: 8) {
                SideTile(side: .work, total: work, session: session, now: now)
                SideTile(side: .away, total: away, session: session, now: now)
            }
            Timeline(segments: session.segments, start: session.startedAt,
                     end: max(now, session.startedAt.addingTimeInterval(session.target ?? 0)), now: now)
            HStack {
                Text(TimeFormat.hour(session.startedAt))
                Spacer()
                Text(progressText(now: now))
                Spacer()
                if let target = session.target {
                    Text(TimeFormat.hour(session.startedAt.addingTimeInterval(target)))
                }
            }
            .font(.system(size: 11).monospacedDigit())
            .foregroundStyle(.secondary)

            HStack {
                PrimaryButton(prominent: true)
                Spacer()
                Button(confirmFinish ? "Emin misin?" : "Mesaiyi bitir") {
                    if confirmFinish {
                        model.finish()
                    } else {
                        confirmFinish = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { confirmFinish = false }
                    }
                }
                .tint(confirmFinish ? .red : nil)
            }
        }
    }

    private func progressText(now: Date) -> String {
        let span = session.span(at: now)
        let breaks = session.segments.filter { $0.side == .away }.count
        var text = TimeFormat.words(span)
        if let target = session.target { text += " / \(TimeFormat.words(target))" }
        if breaks > 0 { text += " · \(breaks) mola" }
        return text
    }
}

/// Satranç saatinin bir tarafı. Aktif olmayan tarafa tıklayınca saat oraya geçer.
struct SideTile: View {
    @EnvironmentObject var model: Model
    let side: Side
    let total: TimeInterval
    let session: Session
    let now: Date
    @State private var hover = false

    var body: some View {
        let active = session.side == side
        let color: Color = side == .work ? .work : .away
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: side == .work ? "briefcase.fill" : "cup.and.saucer.fill")
                Text(side == .work ? "Çalışma" : "Mola")
                Spacer()
                if active {
                    Circle().fill(color).frame(width: 7, height: 7)
                }
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(active ? color : .secondary)
            Text(TimeFormat.clock(total))
                .font(.system(size: 22, weight: active ? .medium : .light).monospacedDigit())
                .foregroundStyle(active ? .primary : .secondary)
            Text(active ? "Şu an \(TimeFormat.words(session.currentStretch(at: now)))" : hover ? "Buraya geç" : share)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(active ? color.opacity(0.16) : Color.primary.opacity(hover ? 0.09 : 0.05))
        )
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(active ? color.opacity(0.6) : .clear, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onHover { hover = $0 && !active }
        .onTapGesture { model.setSide(side) }
        .accessibilityAddTraits(.isButton)
    }

    private var share: String {
        let span = session.span(at: now)
        guard span > 0 else { return " " }
        return "%\(Int((total / span * 100).rounded()))"
    }
}

/// Mesainin zaman şeridi: çalışma ve mola aralıkları renkli bloklar halinde.
struct Timeline: View {
    let segments: [Segment]
    let start: Date
    let end: Date
    let now: Date

    var body: some View {
        GeometryReader { geo in
            let range = max(end.timeIntervalSince(start), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let x = segment.start.timeIntervalSince(start) / range * geo.size.width
                    let w = max(segment.duration(at: now) / range * geo.size.width, 1)
                    Rectangle()
                        .fill(segment.side == .work ? Color.work : Color.away)
                        .frame(width: w)
                        .offset(x: x)
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

// MARK: Özet

struct SummaryView: View {
    @EnvironmentObject var model: Model
    let summary: Summary

    var body: some View {
        let work = summary.total(.work)
        let away = summary.total(.away)
        let span = max(summary.span, 1)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(summary.name).font(.system(size: 13, weight: .semibold))
                    Text(dateText).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(TimeFormat.words(summary.span))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Stat(title: "Çalışma", value: TimeFormat.clock(work), detail: "%\(Int((work / span * 100).rounded()))", color: .work)
                Stat(title: "Mola", value: TimeFormat.clock(away), detail: "%\(Int((away / span * 100).rounded()))", color: .away)
            }
            Timeline(segments: summary.segments, start: summary.start,
                     end: max(summary.end, summary.start.addingTimeInterval(summary.target ?? 0)), now: summary.end)
            VStack(spacing: 4) {
                Line("Mola sayısı", "\(summary.breaks.count)")
                if !summary.breaks.isEmpty {
                    Line("Ortalama mola", TimeFormat.words(away / Double(summary.breaks.count)))
                    Line("En uzun mola", TimeFormat.words(summary.longest(.away)))
                }
                Line("En uzun kesintisiz çalışma", TimeFormat.words(summary.longest(.work)))
                if let target = summary.target {
                    Line("Hedef", "\(TimeFormat.words(target)) · \(summary.span >= target ? "tamamlandı" : "\(TimeFormat.words(target - summary.span)) eksik")")
                }
            }
            HStack {
                Spacer()
                Button("Tamam") { model.shownSummary = nil }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var dateText: String {
        let day = summary.start.formatted(.dateTime.day().month(.abbreviated).weekday(.wide))
        return "\(day), \(TimeFormat.hour(summary.start))–\(TimeFormat.hour(summary.end))"
    }

    private struct Stat: View {
        let title: String, value: String, detail: String, color: Color
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11.5, weight: .medium)).foregroundStyle(color)
                Text(value).font(.system(size: 20, weight: .medium).monospacedDigit())
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.12)))
        }
    }

    private struct Line: View {
        let title: String, value: String
        init(_ title: String, _ value: String) { self.title = title; self.value = value }
        var body: some View {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text(value).monospacedDigit()
            }
            .font(.system(size: 12))
        }
    }
}

// MARK: Ortak

struct Header: View {
    @EnvironmentObject var model: Model
    let session: Session

    var body: some View {
        HStack(spacing: 6) {
            ModeIcon(mode: session.mode, size: 13).foregroundStyle(.secondary)
            Text(session.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Spacer()
            if session.name != session.mode.title {
                Text(session.mode.title).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
        }
    }
}

/// Başlat/duraklat ya da mesaide taraf değiştirme; kısayol varsa üzerinde yazar.
struct PrimaryButton: View {
    @EnvironmentObject var model: Model
    var prominent = false

    var body: some View {
        let button = Button {
            model.primaryAction()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                Text(model.primaryTitle)
                if let hint = Shortcut.saved?.display {
                    Text(hint).foregroundStyle(.secondary).font(.system(size: 11))
                }
            }
        }
        if prominent {
            button.buttonStyle(.borderedProminent).tint(model.session?.side == .away ? Color.work : Color.away)
        } else {
            button
        }
    }

    private var symbol: String {
        guard let s = model.session else { return "play.fill" }
        if s.mode == .shift { return s.side == .away ? "briefcase.fill" : "cup.and.saucer.fill" }
        return s.isRunning ? "pause.fill" : "play.fill"
    }
}

struct UpdateRow: View {
    @EnvironmentObject var model: Model
    let update: AvailableUpdate

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(Color.accentColor)
            switch model.updateStatus {
            case .idle:
                Text("Yeni sürüm var: \(update.version)").font(.system(size: 12.5))
                Spacer()
                Button("Güncelle") { model.installUpdate() }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            case .installing:
                Text("Güncelleniyor…").font(.system(size: 12.5))
                Spacer()
                ProgressView().controlSize(.mini)
            case .failed:
                Text("Güncellenemedi").font(.system(size: 12.5))
                Spacer()
                Button("İndir") { NSWorkspace.shared.open(update.url) }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
            }
        }
    }
}

/// Alttaki sade yazı butonları: görünüm aynı, tıklanan alan geniş, üzerine gelince hafif vurgu.
struct FooterButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            label
                .font(.system(size: 12))
                .foregroundStyle(hover ? Color.primary : Color.secondary)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(hover ? 0.1 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
