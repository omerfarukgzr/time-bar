import AppKit
import SwiftUI
import UserNotifications

/// Ayarlar sayfaları; pencerenin üstündeki sekmelerle aynı sırada.
enum SettingsPage: Int, CaseIterable, Identifiable {
    case general, modes, menuBar, shortcut, notifications, history, about

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .general: "Genel"
        case .menuBar: "Menü Çubuğu"
        case .shortcut: "Kısayol"
        case .notifications: "Bildirimler"
        case .modes: "Modlar"
        case .history: "Geçmiş"
        case .about: "Hakkında"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .menuBar: "menubar.rectangle"
        case .shortcut: "command"
        case .notifications: "bell.badge"
        case .modes: "square.grid.2x2"
        case .history: "chart.bar.xaxis"
        case .about: "info.circle"
        }
    }

    var subtitle: String {
        switch self {
        case .general: "Sistem davranışı ve tüm ayar sayfaları."
        case .menuBar: "Sayacın menü çubuğunda nasıl göründüğü."
        case .shortcut: "Sayacı klavyeden başlatıp durdurmak için."
        case .notifications: "Süre dolunca ne olacağı."
        case .modes: "Panelde hangi modların görüneceği ve her birinin ayarları."
        case .history: "Biten mesailer: ne kadar çalıştın, ne kadar mola verdin."
        case .about: "Sürüm, güncellemeler ve kaynak kodu."
        }
    }
}

/// Ayarlar penceresi: üstte sistem tarzı sekmeler, her sekmede bir SwiftUI sayfası.
/// Sekme değişince pencere, sayfanın boyuna göre üst kenarı sabit kalarak büyür ya da küçülür.
@MainActor
final class SettingsController: NSTabViewController {
    private let model: Model

    init(model: Model) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        transitionOptions = [.crossfade, .allowUserInteraction]
        for page in SettingsPage.allCases {
            let view = SettingsPageView(page: page, select: { [weak self] in self?.select($0) }).environmentObject(model)
            let host = NSHostingController(rootView: view)
            host.sizingOptions = [.preferredContentSize]
            host.title = page.title
            let item = NSTabViewItem(viewController: host)
            item.label = page.title
            item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
            addTabViewItem(item)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    static func makeWindow(model: Model) -> NSWindow {
        let window = NSWindow(contentViewController: SettingsController(model: model))
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    func select(_ page: SettingsPage) {
        selectedTabViewItemIndex = page.rawValue
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let size = tabViewItem?.viewController?.view.fittingSize, let window = view.window else { return }
        let content = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        var frame = window.frame
        frame.origin.y += frame.height - content.height
        frame.size = content.size
        window.setFrame(frame, display: true, animate: true)
    }
}

struct SettingsPageView: View {
    let page: SettingsPage
    var select: (SettingsPage) -> Void = { _ in }

    var body: some View {
        if page == .history || page == .modes {
            // Geçmiş uzayabilir; pencere sabit boyda kalır, sayfa kayar
            ScrollView { content }.frame(width: 560, height: 640)
        } else {
            content.fixedSize(horizontal: false, vertical: true)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(page.title).font(.system(size: 20, weight: .bold))
                Text(page.subtitle).font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
            switch page {
            case .general: GeneralPage(select: select)
            case .menuBar: MenuBarPage()
            case .shortcut: ShortcutPage()
            case .notifications: NotificationsPage()
            case .modes: ModesPage()
            case .history: HistoryPage()
            case .about: AboutPage()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .frame(width: 560, alignment: .leading)
        .toggleStyle(.switch)
    }
}

// MARK: Sayfalar

struct GeneralPage: View {
    @EnvironmentObject var model: Model
    var select: (SettingsPage) -> Void
    @AppStorage(AppDelegate.dockKey) private var showInDock = true
    @AppStorage("showTime") private var showTime = true
    @AppStorage("showName") private var showName = true
    @AppStorage(Sounds.key) private var sound = "Glass"
    @AppStorage(Mode.enabledKey) private var enabledRaw = ""
    @AppStorage(Shortcut.defaultsKey) private var shortcutData: Data?

    var body: some View {
        Card {
            SettingRow("Mac açılınca başlat", "Oturum açıldığında Time Bar menü çubuğunda otomatik görünür.") {
                Toggle("", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 })).labelsHidden()
            }
            SettingRow("Dock'ta göster", "Kapalıyken uygulama sadece menü çubuğunda durur.") {
                Toggle("", isOn: $showInDock).labelsHidden()
                    .onChange(of: showInDock) { AppDelegate.applyDockPolicy() }
            }
        }

        SectionLabel("Menü")
        Card {
            NavRow(.modes, "Paneldeki modlar ve ayrıntılı ayarları", value: "\(Mode.enabled.count) mod", select: select)
            NavRow(.menuBar, "Menü çubuğunda süre ve ad", value: menuBarValue, select: select)
            NavRow(.shortcut, "Başlat / durdur tuşu", value: Shortcut.saved?.display ?? "Yok", select: select)
            NavRow(.notifications, "Bitiş sesi ve bildirim", value: sound.isEmpty ? "Sessiz" : sound, select: select)
            NavRow(.history, "Biten mesailer ve haftalık özet", value: "\(model.history.count) mesai", select: select)
            NavRow(.about, "Sürüm ve güncellemeler", value: UpdateChecker.currentVersion, select: select)
        }
        .id("\(shortcutData?.count ?? 0)\(enabledRaw)") // kısayol ya da modlar değişince değerler yenilensin
    }

    private var menuBarValue: String {
        switch (showName, showTime) {
        case (true, true): "Ad + süre"
        case (false, true): "Süre"
        case (true, false): "Ad"
        case (false, false): "Sadece ikon"
        }
    }
}

struct MenuBarPage: View {
    @AppStorage("showTime") private var showTime = true
    @AppStorage("showName") private var showName = true
    @AppStorage("timeFormat") private var timeFormat = "clock"
    @AppStorage("warnLastMinute") private var warnLastMinute = true

    var body: some View {
        // Ayarların menü çubuğundaki karşılığı
        HStack(spacing: 6) {
            Spacer()
            Image(nsImage: MenuBarIcon.image(Mode.countdown.symbol))
            if showName || showTime {
                Text([showName ? "Ders" : nil, showTime ? (timeFormat == "clock" ? "42:15" : "43 dk") : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 13).monospacedDigit())
            }
            Spacer()
        }
        .frame(height: 44)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.07)))
        .animation(.easeOut(duration: 0.15), value: showName)
        .animation(.easeOut(duration: 0.15), value: showTime)

        Card {
            SettingRow("Süreyi göster", "Kapalıyken sadece modun ikonu görünür.") {
                Toggle("", isOn: $showTime).labelsHidden()
            }
            SettingRow("Adı göster", "Mesaide çalışmayı çanta, molayı fincan ikonu gösterir.") {
                Toggle("", isOn: $showName).labelsHidden()
            }
            SettingRow("Süre biçimi", "Saniyeli saat ya da dakika.") {
                Picker("", selection: $timeFormat) {
                    Text("1:05:00").tag("clock")
                    Text("1 sa 5 dk").tag("words")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            SettingRow("Son dakikada turuncuya dön", "Geri sayımda süre bitmeden fark etmen için.") {
                Toggle("", isOn: $warnLastMinute).labelsHidden()
            }
        }
    }
}

struct ShortcutPage: View {
    var body: some View {
        Card {
            SettingRow("Başlat / durdur", "Tıkla ve tuşlara bas. ⌘, ⌥ ya da ⌃ ile birlikte olmalı; F tuşları tek başına olabilir. Esc vazgeçer.") {
                ShortcutRecorder()
            }
        }
        SectionLabel("Kısayol ve sağ tık ne yapar")
        Card {
            InfoRow("cursorarrow.click.2", "Menü çubuğunda sağ tık", "Kısayolla aynı işi yapar. Paneli açmak için sol tıkla.")
            InfoRow("briefcase", "Mesai", "Çalışmadaysan molaya, moladaysan çalışmaya geçer.")
            InfoRow("timer", "Geri sayım, kronometre, pomodoro", "Duraklatır ya da devam ettirir. Geri sayım bittiyse kapatır.")
            InfoRow("play", "Sayaç yokken", "En son başlattığın sayacı aynı ayarla başlatır. Hiç yoksa paneli açar.")
        }
    }
}

struct NotificationsPage: View {
    @AppStorage(Sounds.key) private var sound = "Glass"
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        Card {
            SettingRow("Bitiş sesi", "Geri sayım bitince ve mesai hedefi dolunca çalar.") {
                HStack(spacing: 6) {
                    Picker("", selection: $sound) {
                        Text("Sessiz").tag("")
                        ForEach(Sounds.choices, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    Button { Sounds.play() } label: { Image(systemName: "speaker.wave.2") }
                        .disabled(sound.isEmpty)
                        .help("Dinle")
                }
            }
            SettingRow("Bildirimler", statusText) {
                if status == .notDetermined {
                    Button("İzin ver") {
                        Notifier.shared.requestPermission { refresh() }
                    }
                } else {
                    Button("Sistem Ayarları…") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
                    }
                }
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private var statusText: String {
        switch status {
        case .authorized, .provisional: "Açık. Süre dolunca bildirimden \"+5 dk\" diyebilirsin."
        case .denied: "Kapalı. Süre dolunca sadece ses çalar ve menü çubuğu kırmızı yanıp söner."
        case .notDetermined: "Henüz izin verilmedi. İlk sayacı başlatınca da sorulur."
        default: "Durum bilinmiyor."
        }
    }

    private func refresh() {
        Task { status = await Notifier.shared.authorizationStatus() }
    }
}

struct ModesPage: View {
    @AppStorage(Mode.enabledKey) private var enabledRaw = Mode.allCases.map(\.rawValue).joined(separator: ",")
    @AppStorage("countdownMinutes") private var countdownMinutes = 60
    @AppStorage("shiftMinutes") private var shiftMinutes = 480
    @AppStorage(Model.lockKey) private var awayOnLock = false
    @AppStorage("pomoFocus") private var focus = 25
    @AppStorage("pomoShort") private var shortBreak = 5
    @AppStorage("pomoLong") private var longBreak = 15
    @AppStorage("pomoRounds") private var rounds = 4
    @AppStorage("pomoAuto") private var autoStart = true

    var body: some View {
        ModeCard(mode: .countdown, enabled: binding(.countdown)) {
            SettingRow("Varsayılan süre", "Panel açılınca seçili gelen süre.") {
                MinutesStepper(minutes: $countdownMinutes, range: 5...600, step: 5)
            }
        }
        ModeCard(mode: .stopwatch, enabled: binding(.stopwatch)) {}
        ModeCard(mode: .shift, enabled: binding(.shift)) {
            SettingRow("Varsayılan hedef", "Bu süre dolunca bildirim gelir; mesai yine de devam eder.") {
                Picker("", selection: $shiftMinutes) {
                    Text("Hedefsiz").tag(0)
                    ForEach([4, 5, 6, 7, 8, 9, 10, 12], id: \.self) { Text("\($0) saat").tag($0 * 60) }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingRow("Ekran kilitlenince molaya geç", "Kilidi açınca çalışmaya geri döner. Kalkarken tuşa basmayı unutursan işe yarar.") {
                Toggle("", isOn: $awayOnLock).labelsHidden()
            }
        }
        ModeCard(mode: .pomodoro, enabled: binding(.pomodoro)) {
            SettingRow("Odak süresi", "Bir turda kesintisiz çalışılan süre.") {
                MinutesStepper(minutes: $focus, range: 5...120, step: 5)
            }
            SettingRow("Kısa mola", "Her odaktan sonra.") {
                MinutesStepper(minutes: $shortBreak, range: 1...30, step: 1)
            }
            SettingRow("Uzun mola", "Belirli sayıda odaktan sonra.") {
                MinutesStepper(minutes: $longBreak, range: 5...60, step: 5)
            }
            SettingRow("Uzun mola sıklığı", "Kaç odakta bir uzun mola verilecek.") {
                Stepper("\(rounds) odakta bir", value: $rounds, in: 2...8)
                    .monospacedDigit()
                    .fixedSize()
            }
            SettingRow("Sonraki aşama kendiliğinden başlasın", "Kapalıyken her aşamadan sonra sayaç bekler; sağ tık ya da kısayolla başlatırsın.") {
                Toggle("", isOn: $autoStart).labelsHidden()
            }
        }
    }

    private var enabled: Set<String> { Set(enabledRaw.split(separator: ",").map(String.init)) }

    /// Panelde göster anahtarı. Son açık mod kapatılamaz.
    private func binding(_ mode: Mode) -> Binding<Bool>? {
        let isOn = enabled.contains(mode.rawValue)
        guard !(isOn && enabled.count == 1) else { return nil }
        return Binding(
            get: { isOn },
            set: { on in
                var set = enabled
                if on { set.insert(mode.rawValue) } else { set.remove(mode.rawValue) }
                enabledRaw = Mode.allCases.map(\.rawValue).filter(set.contains).joined(separator: ",")
            }
        )
    }
}

/// Bir modun kartı: başlıkta "panelde göster" anahtarı, altında ayrıntılı ayarları.
struct ModeCard<Content: View>: View {
    let mode: Mode
    /// nil: bu son açık mod, kapatılamaz.
    let enabled: Binding<Bool>?
    @ViewBuilder let content: Content

    var body: some View {
        let on = enabled?.wrappedValue ?? true
        Card {
            HStack(spacing: 12) {
                ModeIcon(mode: mode, size: 16)
                    .foregroundStyle(on ? Color.accentColor : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title).font(.system(size: 14, weight: .semibold))
                    Text(mode.detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: enabled ?? .constant(true))
                    .labelsHidden()
                    .disabled(enabled == nil)
                    .help(enabled == nil ? "En az bir mod açık olmalı" : "Panelde göster")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            // Group şeffaf: her satır kartta ayrı satır olarak kalır, çizgiler korunur
            Group { content }
                .disabled(!on)
                .opacity(on ? 1 : 0.45)
        }
    }
}

/// "25 dk" ya da "1 sa 30 dk" gösteren adım düğmesi.
struct MinutesStepper: View {
    @Binding var minutes: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        Stepper(TimeFormat.words(TimeInterval(minutes * 60)), value: $minutes, in: range, step: step)
            .monospacedDigit()
            .fixedSize()
    }
}

struct AboutPage: View {
    @EnvironmentObject var model: Model
    @AppStorage("checkUpdates") private var checkUpdates = true

    var body: some View {
        Card {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time Bar").font(.system(size: 15, weight: .semibold))
                    Text("Sürüm \(UpdateChecker.currentVersion)").font(.system(size: 12)).foregroundStyle(.secondary)
                    Text("Menü çubuğunda geri sayım, kronometre ve mesai saati.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
        }
        SectionLabel("Güncellemeler")
        Card {
            SettingRow("Güncellemeleri denetle", "Günde bir kez GitHub'daki son sürüme bakar, hiçbir veri göndermez.") {
                Toggle("", isOn: $checkUpdates).labelsHidden()
                    .onChange(of: checkUpdates) { model.checkForUpdate() }
            }
            SettingRow(updateTitle, lastCheckText) {
                if let update = model.update {
                    Button(model.updateStatus == .installing ? "Güncelleniyor…" : "\(update.version) sürümüne güncelle") {
                        model.installUpdate()
                    }
                    .disabled(model.updateStatus == .installing)
                } else {
                    Button(model.checkingUpdate ? "Denetleniyor…" : "Şimdi denetle") { model.checkForUpdate(force: true) }
                        .disabled(model.checkingUpdate || !checkUpdates)
                }
            }
        }
        SectionLabel("Kaynak")
        Card {
            LinkRow("GitHub", "Kaynak kodu ve sürüm notları", url: "https://github.com/omerfarukgzr/time-bar")
            LinkRow("Lisans", "MIT. Veri toplamaz, analitik kullanmaz.", url: "https://github.com/omerfarukgzr/time-bar/blob/main/LICENSE")
        }
    }

    private var updateTitle: String {
        if model.updateStatus == .failed { return "Güncellenemedi" }
        return model.update.map { "Yeni sürüm var: \($0.version)" } ?? "Güncel"
    }

    private var lastCheckText: String {
        guard let date = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date else { return "Henüz denetlenmedi." }
        return "Son denetim: \(date.formatted(.relative(presentation: .named)))"
    }
}

// MARK: Parçalar

/// Yuvarlak köşeli kart; içindeki satırların arasına çizgi koyar.
struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        _VariadicView.Tree(DividedRows()) { content }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.primary.opacity(0.09), lineWidth: 0.5))
    }
}

/// Kartın satırlarını alt alta dizer, aralarına çizgi koyar (macOS 14'te Group(subviews:) yok).
struct DividedRows: _VariadicView_MultiViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        VStack(spacing: 0) {
            ForEach(children) { child in
                if child.id != children.first?.id { Divider().padding(.leading, 14) }
                child
            }
        }
    }
}

struct SectionLabel: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .padding(.bottom, -10)
    }
}

/// Başlık, açıklama ve sağda bir kontrol.
struct SettingRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: Control

    init(_ title: String, _ detail: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

/// Başka bir ayar sayfasına giden satır: ikon, başlık, açıklama, değer ve ok.
struct NavRow: View {
    let page: SettingsPage
    let detail: String
    let value: String
    let select: (SettingsPage) -> Void
    @State private var hover = false

    init(_ page: SettingsPage, _ detail: String, value: String, select: @escaping (SettingsPage) -> Void) {
        self.page = page
        self.detail = detail
        self.value = value
        self.select = select
    }

    var body: some View {
        Button { select(page) } label: {
            HStack(spacing: 12) {
                Image(systemName: page.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(value).font(.system(size: 12.5)).foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(hover ? 0.05 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

struct InfoRow: View {
    let symbol: String, title: String, detail: String
    init(_ symbol: String, _ title: String, _ detail: String) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct LinkRow: View {
    let title: String, detail: String, url: String
    @State private var hover = false
    init(_ title: String, _ detail: String, url: String) {
        self.title = title
        self.detail = detail
        self.url = url
    }

    var body: some View {
        Button { NSWorkspace.shared.open(URL(string: url)!) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(hover ? 0.05 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
