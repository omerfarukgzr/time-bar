import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Kullanıcının seçtiği kısayol. Carbon'un RegisterEventHotKey'i Erişilebilirlik izni istemez.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt // NSEvent.ModifierFlags
    var key: String

    static let defaultsKey = "shortcut"

    static var saved: Shortcut? {
        get { UserDefaults.standard.data(forKey: defaultsKey).flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } }
        set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }

    var flags: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifiers) }

    var display: String {
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        return s + key
    }

    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    /// Basılan tuştan kısayol üretir. F tuşları dışında en az bir ⌘, ⌥ ya da ⌃ ister,
    /// yoksa yazı yazarken sayaç durup başlar.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let name = Self.specialKeys[event.keyCode]
        let isFunctionKey = name?.hasPrefix("F") == true
        guard isFunctionKey || !flags.intersection([.command, .option, .control]).isEmpty else { return nil }
        guard let key = name ?? event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = flags.rawValue
        self.key = key
    }

    private static let specialKeys: [UInt16: String] = [
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
    ]
}

@MainActor
final class HotKey {
    static let shared = HotKey()

    var action: () -> Void = {}
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    /// Kayıtlı kısayolu (varsa) etkinleştirir.
    func apply() {
        register(Shortcut.saved)
    }

    /// Kısayolu etkinleştirir. Sistem ya da başka bir uygulama o tuşu ayırdıysa false döner.
    @discardableResult
    func register(_ shortcut: Shortcut?) -> Bool {
        unregister()
        guard let shortcut else { return true }
        installHandler()
        let id = EventHotKeyID(signature: OSType(0x544D_4252), id: 1) // "TMBR"
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr { ref = nil }
        return status == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { HotKey.shared.action() } }
            return noErr
        }, 1, &spec, nil, nil)
    }
}

/// Ayarlar'daki kısayol kaydedici: tıkla, tuşlara bas.
struct ShortcutRecorder: View {
    @State private var shortcut = Shortcut.saved
    @State private var recording = false
    @State private var monitor: Any?
    @State private var message: String?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                recording ? stop() : record()
            } label: {
                Text(recording ? (message ?? "Tuşlara bas…") : shortcut?.display ?? "Kısayol ata")
                    .monospacedDigit()
                    .frame(minWidth: 110)
            }
            .foregroundStyle(recording ? Color.accentColor : .primary)
            if shortcut != nil && !recording {
                Button {
                    shortcut = nil
                    Shortcut.saved = nil
                    HotKey.shared.apply()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Kısayolu kaldır")
            }
        }
        .onDisappear { stop() }
    }

    private func record() {
        recording = true
        message = nil
        HotKey.shared.unregister() // mevcut kısayola basınca da yakalanabilsin
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc: vazgeç
                stop()
                return nil
            }
            guard let new = Shortcut(event: event) else {
                message = "⌘, ⌥ ya da ⌃ ile birlikte"
                return nil
            }
            // Tuş başka yerde ayrılmışsa kaydetme; kullanıcı kısayolun çalıştığını sanmasın
            guard HotKey.shared.register(new) else {
                message = "\(new.display) kullanımda, başka dene"
                return nil
            }
            shortcut = new
            Shortcut.saved = new
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        HotKey.shared.apply()
    }
}
