import AppKit
import SwiftUI

/// Menü çubuğu ikonu: o anki modun paneldeki ikonu. Sayaç yokken panelde seçili modun ikonu,
/// molada (mesai ya da pomodoro) kahve fincanı. Yeni sürüm varsa sağ üstte nokta.
enum MenuBarIcon {
    static let away = "cup.and.saucer.fill"

    static func image(_ symbol: String, badge: Bool = false) -> NSImage {
        let base: NSImage
        if symbol == Tomato.name {
            base = Tomato.image(size: 17)
        } else {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            base = NSImage(systemSymbolName: symbol, accessibilityDescription: "Time Bar")?.withSymbolConfiguration(config)
                ?? NSImage(size: NSSize(width: 16, height: 16))
        }
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

/// Pomodoro'nun domates ikonu. SF Symbols'te domates olmadığı için çiziyoruz; tek renk, şablon.
enum Tomato {
    static let name = "tomato"

    static func image(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.scaleBy(x: size / 18, y: size / 18)
            NSColor.black.set()
            // Gövde: hafif basık yuvarlak
            NSBezierPath(ovalIn: NSRect(x: 1.2, y: 4.4, width: 15.6, height: 12.4)).fill()
            // Yıldız gibi yayılan yapraklar (sola, sağa, aşağıya); gövdeden ince bir boşlukla ayrılır
            let crown = NSBezierPath()
            let c = NSPoint(x: 9, y: 5.4)
            for (tip, bend) in [(NSPoint(x: 2.6, y: 6.8), -1.6), (NSPoint(x: 15.4, y: 6.8), -1.6),
                                (NSPoint(x: 6.2, y: 9.6), 0.9), (NSPoint(x: 11.8, y: 9.6), 0.9)] as [(NSPoint, CGFloat)] {
                // Uca doğru incelen yaprak: iki kontrol noktası yaprağın iki kenarını çizer
                let mid = NSPoint(x: (c.x + tip.x) / 2, y: (c.y + tip.y) / 2)
                let dx = tip.x - c.x, dy = tip.y - c.y
                let len = max(sqrt(dx * dx + dy * dy), 0.1)
                let nx = -dy / len * 1.5, ny = dx / len * 1.5
                crown.move(to: c)
                crown.curve(to: tip, controlPoint1: NSPoint(x: mid.x + nx, y: mid.y + ny + bend * 0.3), controlPoint2: tip)
                crown.curve(to: c, controlPoint1: tip, controlPoint2: NSPoint(x: mid.x - nx, y: mid.y - ny + bend * 0.3))
                crown.close()
            }
            let stem = NSBezierPath()
            stem.move(to: NSPoint(x: 9, y: 5.4))
            stem.curve(to: NSPoint(x: 10.4, y: 1.0), controlPoint1: NSPoint(x: 9, y: 3.4), controlPoint2: NSPoint(x: 9.5, y: 1.8))
            stem.lineCapStyle = .round

            ctx.setBlendMode(.clear)
            crown.lineWidth = 2.2
            crown.lineJoinStyle = .round
            crown.stroke()
            crown.fill()
            stem.lineWidth = 3.4
            stem.stroke()
            ctx.setBlendMode(.normal)
            crown.fill()
            stem.lineWidth = 1.4
            stem.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Pomodoro"
        return image
    }
}

/// Bir modun ikonu SwiftUI'de; Pomodoro için domates.
struct ModeIcon: View {
    let mode: Mode
    var size: CGFloat = 15

    var body: some View {
        if mode == .pomodoro {
            Image(nsImage: Tomato.image(size: size * 1.2)).renderingMode(.template)
        } else {
            Image(systemName: mode.symbol).font(.system(size: size))
        }
    }
}
