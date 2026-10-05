import AppKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: Model
    @AppStorage("showTime") private var showTime = true
    @AppStorage("showName") private var showName = true
    @AppStorage("timeFormat") private var timeFormat = "clock"
    @AppStorage("warnLastMinute") private var warnLastMinute = true
    @AppStorage(Sounds.key) private var sound = "Glass"
    @AppStorage(Model.lockKey) private var awayOnLock = false
    @AppStorage(AppDelegate.dockKey) private var showInDock = true
    @AppStorage("checkUpdates") private var checkUpdates = true
    @State private var confirmClear = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        Form {
            Section("Menü çubuğu") {
                Toggle(isOn: $showTime) {
                    Text("Süreyi göster")
                    Text("Kapalıyken sadece ikon görünür. İkondaki halka yine ne kadar kaldığını gösterir.")
                }
                Toggle("Adı göster", isOn: $showName)
                Picker("Süre biçimi", selection: $timeFormat) {
                    Text("1:05:00").tag("clock")
                    Text("1 sa 5 dk").tag("words")
                }
                Toggle("Son dakikada turuncuya dön", isOn: $warnLastMinute)
            }

            Section {
                LabeledContent {
                    ShortcutRecorder()
                } label: {
                    Text("Başlat / durdur")
                    Text("Mesaide çalışma ile mola arasında geçer. Sayaç yoksa son kullanılanı başlatır.")
                }
            } header: {
                Text("Kısayol")
            }

            Section("Mesai") {
                Toggle(isOn: $awayOnLock) {
                    Text("Ekran kilitlenince molaya geç")
                    Text("Kilidi açınca çalışmaya geri döner. Kalkarken tuşa basmayı unutursan işe yarar.")
                }
                LabeledContent {
                    Button("Temizle…") { confirmClear = true }
                        .disabled(model.history.isEmpty)
                        .confirmationDialog("Mesai geçmişi silinsin mi?", isPresented: $confirmClear) {
                            Button("Sil", role: .destructive) { model.clearHistory() }
                        }
                } label: {
                    Text("Geçmiş")
                    Text(model.history.isEmpty ? "Henüz biten mesai yok." : "\(model.history.count) mesai kayıtlı. Sadece bu Mac'te saklanır.")
                }
            }

            Section("Bildirim") {
                Picker("Bitiş sesi", selection: $sound) {
                    Text("Sessiz").tag("")
                    ForEach(Sounds.choices, id: \.self) { Text($0).tag($0) }
                }
                .onChange(of: sound) { Sounds.play() }
            }

            Section {
                Toggle("Dock'ta göster", isOn: $showInDock)
                    .onChange(of: showInDock) { AppDelegate.applyDockPolicy() }
                Toggle("Mac açılınca başlat", isOn: Binding(get: { model.launchAtLogin }, set: { model.launchAtLogin = $0 }))
                Toggle(isOn: $checkUpdates) {
                    Text("Güncellemeleri denetle")
                    Text("Günde bir kez GitHub'daki son sürüme bakar, hiçbir veri göndermez.")
                }
                .onChange(of: checkUpdates) { model.checkForUpdate() }
            }

            Section {
                LabeledContent("Sürüm", value: version)
                LabeledContent("Kaynak kodu") {
                    Link("GitHub", destination: URL(string: "https://github.com/omerfarukgzr/time-bar")!)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .scrollIndicators(.never)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
