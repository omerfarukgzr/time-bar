import AppKit

/// Menü çubuğu ikonu. Halka sayacın ilerlemesini gösterir; süre gizlense bile ne kadar kaldığı kabaca görülür.
enum MenuBarIcon {
    enum Kind: Hashable {
        /// Sayaç yok: saat.
        case idle
        /// Geri sayım: kalan oran (1 → 0).
        case remaining(Double)
        /// Kronometre: dakika içindeki saniye (ibre döner).
        case stopwatch(Int)
        /// Mesai, çalışma tarafı: çanta.
        case work
        /// Mola: kahve fincanı.
        case away
    }

    private static let center = NSPoint(x: 9, y: 9.5)
    private static let radius: CGFloat = 6.5

    static func image(_ kind: Kind, badge: Bool = false) -> NSImage {
        if kind == .away, let cup = symbol("cup.and.saucer.fill", badge: badge) { return cup }
        if kind == .work, let bag = symbol("briefcase.fill", badge: badge) { return bag }
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.set()
            switch kind {
            case .idle:
                circle(alpha: 1)
                hand(angle: 0, length: 4)
                hand(angle: 0.25, length: 3)
            case .remaining(let p):
                circle(alpha: 0.3)
                arc(p)
            case .stopwatch(let second):
                circle(alpha: 1)
                NSBezierPath(rect: NSRect(x: 8, y: 0.5, width: 2, height: 2)).fill()
                hand(angle: Double(second) / 60, length: 4.5)
            case .work, .away:
                circle(alpha: 1)
            }
            if badge {
                NSColor.black.set()
                NSBezierPath(ovalIn: NSRect(x: 14, y: 0, width: 4, height: 4)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Time Bar"
        return image
    }

    private static func symbol(_ name: String, badge: Bool) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        guard let cup = NSImage(systemSymbolName: name, accessibilityDescription: name == "briefcase.fill" ? "Çalışma" : "Mola")?
            .withSymbolConfiguration(config) else { return nil }
        guard badge else {
            cup.isTemplate = true
            return cup
        }
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { rect in
            cup.draw(in: NSRect(x: 0, y: (18 - cup.size.height) / 2, width: cup.size.width, height: cup.size.height))
            NSColor.black.set()
            NSBezierPath(ovalIn: NSRect(x: 16, y: 14, width: 4, height: 4)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Saat yönünde, tepeden başlayan açı (0…1 tur) için çember üzerindeki nokta.
    private static func point(_ turn: Double, _ r: CGFloat) -> NSPoint {
        let a = turn * 2 * .pi
        return NSPoint(x: center.x + r * CGFloat(sin(a)), y: center.y - r * CGFloat(cos(a)))
    }

    private static func circle(alpha: CGFloat) {
        let path = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
        path.lineWidth = 1.5
        NSColor.black.withAlphaComponent(alpha).setStroke()
        path.stroke()
    }

    private static func arc(_ progress: Double) {
        let p = min(max(progress, 0), 1)
        guard p > 0.005 else { return }
        let path = NSBezierPath()
        let steps = max(2, Int(p * 72))
        for i in 0...steps {
            let pt = point(p * Double(i) / Double(steps), radius)
            i == 0 ? path.move(to: pt) : path.line(to: pt)
        }
        path.lineWidth = 2.2
        path.lineCapStyle = .round
        NSColor.black.setStroke()
        path.stroke()
    }

    private static func hand(angle: Double, length: CGFloat) {
        let path = NSBezierPath()
        path.move(to: center)
        path.line(to: point(angle, length))
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        NSColor.black.setStroke()
        path.stroke()
    }
}
