import AppKit
import Combine
import SwiftUI

/// Menü çubuğundaki ikon + süre. Sol tık paneli açar, sağ tık durumu tersine çevirir.
@MainActor
final class StatusController: NSObject {
    private let model: Model
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = MenuPanel()
    private var hosting: NSHostingView<AnyView>!
    private var settingsWindow: NSWindow?
    private var outsideClickMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []
    private var isOpen = false
    private var lastIcon: (String, Bool)?

    static let width: CGFloat = 300

    init(model: Model) {
        self.model = model
        super.init()

        let content = PanelContent(openSettings: { [weak self] in self?.showSettings() })
            .environmentObject(model)
            .environmentObject(model.clock)
        hosting = NSHostingView(rootView: AnyView(content))
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: hosting, queue: .main) { [weak self] _ in
            DispatchQueue.main.async { self?.fit() }
        }
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = MenuPanel.makeBackground(containing: hosting)
        panel.onCancel = { [weak self] in self?.closePanel() }

        if let button = statusItem.button {
            button.action = #selector(clicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }

        model.clock.$now.combineLatest(model.$session, model.$alertingSince, model.$update)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
        // Sayaç bitince ya da mesai bitip özet çıkınca paneli boyuna göre güncelle
        model.$shownSummary.receive(on: RunLoop.main).sink { [weak self] _ in DispatchQueue.main.async { self?.fit() } }
            .store(in: &cancellables)
    }

    // MARK: Menü çubuğu

    private func refresh() {
        guard let button = statusItem.button else { return }
        let (kind, text, color) = display()
        let badge = model.update != nil
        if lastIcon == nil || lastIcon! != (kind, badge) {
            button.image = MenuBarIcon.image(kind, badge: badge)
            lastIcon = (kind, badge)
        }
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        var attributes: [NSAttributedString.Key: Any] = [.font: font, .baselineOffset: -1]
        if let color { attributes[.foregroundColor] = color }
        button.attributedTitle = NSAttributedString(string: text.isEmpty ? "" : " " + text, attributes: attributes)
        button.toolTip = model.session.map { "\($0.name) · \($0.mode.title)" } ?? "Time Bar"
    }

    /// İkon türü, yazı ve renk. Ayarlar'daki "süreyi göster" ve "adı göster" burada uygulanır.
    private func display() -> (String, String, NSColor?) {
        let defaults = UserDefaults.standard
        let showTime = defaults.object(forKey: "showTime") as? Bool ?? true
        let showName = defaults.object(forKey: "showName") as? Bool ?? true
        let warn = defaults.object(forKey: "warnLastMinute") as? Bool ?? true
        let seconds = (defaults.string(forKey: "timeFormat") ?? "clock") == "clock"

        // Sayaç yokken panelde seçili modun ikonu
        guard let s = model.session else {
            return (Mode.selected.symbol, "", nil)
        }
        let now = model.now
        func time(_ t: TimeInterval, up: Bool = false) -> String {
            seconds ? TimeFormat.clock(up ? t.rounded(.up) : t) : TimeFormat.compact(t, roundUp: up)
        }
        var name = s.name
        if name.count > 14 { name = String(name.prefix(13)) + "…" }

        var kind = s.mode.symbol
        var value: String
        var color: NSColor?
        switch s.mode {
        case .countdown:
            let remaining = s.remaining(at: now)
            if s.finishedAt != nil {
                value = "Bitti"
                // Yanıp sönme: tek saniyelerde kırmızı, çiftlerde normal
                let blink = model.alertingSince != nil && Int(now.timeIntervalSince1970) % 2 == 1
                color = blink ? nil : .systemRed
            } else {
                value = time(remaining, up: true)
                if !s.isRunning { value += " ⏸" }
                if warn && remaining <= 60 { color = .systemOrange }
            }
        case .stopwatch:
            let elapsed = s.elapsed(at: now)
            value = time(elapsed)
            if !s.isRunning { value += " ⏸" }
        case .pomodoro:
            let phase = s.phase ?? .focus
            let remaining = s.phaseRemaining(at: now)
            if phase != .focus { kind = MenuBarIcon.away }
            value = time(remaining, up: true)
            if !s.isRunning { value += " ⏸" }
            if warn && phase == .focus && remaining <= 60 { color = .systemOrange }
            if model.alertingSince != nil && Int(now.timeIntervalSince1970) % 2 == 1 { color = .systemRed }
        case .shift:
            if s.side == .away {
                kind = MenuBarIcon.away
                value = time(s.currentStretch(at: now))
            } else {
                value = time(s.total(.work, at: now))
            }
        }

        var parts: [String] = []
        // Çalışma mı mola mı olduğunu ikon gösteriyor (çanta / fincan), ayrıca yazmaya gerek yok
        if showName { parts.append(name) }
        if showTime { parts.append(value) }
        // Süre gizliyken de "Bitti" görünsün
        if !showTime && s.finishedAt != nil { parts.append(value) }
        return (kind, parts.joined(separator: " · "), color)
    }

    // MARK: Tıklama

    /// Sol tık paneli açar. Sağ tık (ya da ⌃ tık) menü açmaz, o anki durumun tersine geçer:
    /// mesaide çalışma ↔ mola, diğerlerinde duraklat ↔ devam et. Sayaç yoksa ikonu görünen modu başlatır.
    @objc private func clicked() {
        let event = NSApp.currentEvent
        let right = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if model.alertingSince != nil { model.acknowledgeAlert() }
        if right {
            closePanel()
            hotKeyPressed()
        } else {
            isOpen ? closePanel() : openPanel()
        }
    }

    /// Kısayola basıldı ya da sağ tıklandı.
    func hotKeyPressed() {
        model.primaryAction()
    }

    // MARK: Panel

    func openPanel() {
        guard !isOpen, let button = statusItem.button, let buttonWindow = button.window,
              let screen = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame else { return }
        let height = max(hosting.fittingSize.height, 80)
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let x = min(buttonRect.minX, screen.maxX - Self.width - 8)
        panel.setFrame(NSRect(x: x, y: buttonRect.minY - 6 - height, width: Self.width, height: height), display: true)
        isOpen = true
        button.highlight(true)
        panel.show()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closePanel() }
        }
    }

    func closePanel() {
        guard isOpen else { return }
        isOpen = false
        statusItem.button?.highlight(false)
        panel.hide()
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    /// İçerik yüksekliği değişince paneli üst kenarı sabit kalacak şekilde yeniden boyutlandır.
    private func fit() {
        let height = hosting.fittingSize.height
        guard isOpen, height > 0 else { return }
        var frame = panel.frame
        guard abs(frame.height - height) > 0.5 else { return }
        frame.origin.y += frame.height - height
        frame.size.height = height
        panel.setFrame(frame, display: true)
    }

    // MARK: Ayarlar

    func showSettings(page: SettingsPage? = nil) {
        closePanel()
        if settingsWindow == nil {
            settingsWindow = SettingsController.makeWindow(model: model)
        }
        if let page { (settingsWindow?.contentViewController as? SettingsController)?.select(page) }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
