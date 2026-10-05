import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let dockKey = "showInDock"

    private var model: Model?
    private var controller: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Zaten açıksa ikinci ikon olmasın
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != .current }
        guard others.isEmpty else {
            NSApp.terminate(nil)
            return
        }

        Self.applyDockPolicy()
        NSApp.mainMenu = Self.makeMainMenu()

        let model = Model()
        let controller = StatusController(model: model)
        self.model = model
        self.controller = controller
        Notifier.shared.setup(model: model)
        HotKey.shared.action = { [weak controller] in controller?.hotKeyPressed() }
        HotKey.shared.apply()
        // Geliştirirken ayarları doğrudan açmak için: open -a "Time Bar" --args --settings
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--settings") {
            let page = args.indices.contains(i + 1) ? Int(args[i + 1]).flatMap(SettingsPage.init) : nil
            controller.showSettings(page: page ?? .general)
        }
    }

    /// Dock ikonuna tıklanınca paneli aç.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.openPanel()
        return false
    }

    static func applyDockPolicy() {
        let show = UserDefaults.standard.object(forKey: dockKey) as? Bool ?? false
        NSApp.setActivationPolicy(show ? .regular : .accessory)
    }

    /// Paneldeki ad alanında ⌘V, ⌘C, ⌘A çalışsın diye Düzen menüsü gerekiyor.
    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: "Time Bar Hakkında", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Time Bar'ı Gizle", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "Time Bar'dan Çık", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = app

        let edit = NSMenu(title: "Düzen")
        edit.addItem(withTitle: "Geri Al", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Yinele", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Kes", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopyala", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Yapıştır", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Tümünü Seç", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "Düzen", action: nil, keyEquivalent: "").submenu = edit

        let window = NSMenu(title: "Pencere")
        window.addItem(withTitle: "Kapat", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(withTitle: "Küçült", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(withTitle: "Pencere", action: nil, keyEquivalent: "").submenu = window

        return main
    }
}
