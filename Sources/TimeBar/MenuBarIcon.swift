import AppKit

/// Menü çubuğu ikonu: o anki modun paneldeki ikonu. Sayaç yokken panelde seçili modun ikonu,
/// molada (mesai ya da pomodoro) kahve fincanı. Yeni sürüm varsa sağ üstte nokta.
enum MenuBarIcon {
    static let away = "cup.and.saucer.fill"

    static func image(_ symbol: String, badge: Bool = false) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Time Bar")?.withSymbolConfiguration(config)
            ?? NSImage(size: NSSize(width: 16, height: 16))
        guard badge else {
            base.isTemplate = true
            return base
        }
        let size = NSSize(width: base.size.width + 3, height: max(base.size.height, 16))
        let image = NSImage(size: size, flipped: false) { _ in
            base.draw(in: NSRect(x: 0, y: (size.height - base.size.height) / 2, width: base.size.width, height: base.size.height))
            NSColor.black.set()
            NSBezierPath(ovalIn: NSRect(x: size.width - 4, y: size.height - 4, width: 4, height: 4)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
