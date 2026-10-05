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
        // SF Symbol'lerin kutusu çizimi ortalamaz (çantanın altında boşluk kalıyor),
        // menü çubuğu ise kutuyu ortalar. Çizimin gerçek sınırlarını bulup sabit yükseklikte ortalıyoruz.
        let ink = inkBounds(of: base)
        let size = NSSize(width: ink.width + (badge ? 3 : 0), height: height)
        let image = NSImage(size: size, flipped: false) { _ in
            // Tam noktaya yuvarla; 1x ekranda yarım nokta yarım piksel olur, çizgiler bulanıklaşır.
            // 1 nokta yukarı: çantanın gövdesi yazıyla aynı hizaya gelsin, sap üstte kalsın.
            let origin = NSPoint(x: -ink.minX, y: ((size.height - ink.height) / 2 - ink.minY).rounded() + 1)
            base.draw(in: NSRect(origin: origin, size: base.size))
            if badge {
                NSColor.black.set()
                NSBezierPath(ovalIn: NSRect(x: size.width - 4, y: size.height - 4, width: 4, height: 4)).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Menü çubuğu ikonunun yüksekliği; çizim bunun içinde dikeyde ortalanır.
    private static let height: CGFloat = 18

    /// İkonun boyalı piksellerinin sınırı (nokta cinsinden, sol alt köşe başlangıç).
    private static func inkBounds(of image: NSImage) -> NSRect {
        let scale: CGFloat = 4
        let w = Int(image.size.width * scale), h = Int(image.size.height * scale)
        guard w > 0, h > 0, let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSRect(origin: .zero, size: image.size)
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()

        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h {
            for x in 0..<w where rep.colorAt(x: x, y: y)!.alphaComponent > 0.2 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return NSRect(origin: .zero, size: image.size) }
        // colorAt'te y yukarıdan aşağı sayılır; çizim koordinatına çevir
        return NSRect(x: CGFloat(minX) / scale, y: CGFloat(h - 1 - maxY) / scale,
                      width: CGFloat(maxX - minX + 1) / scale, height: CGFloat(maxY - minY + 1) / scale)
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
        // Semboller farklı yükseklikte (kronometre uzun); aynı kutuda dursunlar ki altlarındaki yazılar hizalı kalsın
        Group {
            if mode == .pomodoro {
                // Çizilmiş resmin baseline'ı yok; .firstTextBaseline'da alt kenarı yazı çizgisine oturup yukarı kayıyordu.
                // Semboller gibi büyük harf yüksekliğinin ortasına hizala.
                Image(nsImage: Tomato.image(size: size * 1.2)).renderingMode(.template)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + size * 0.35 }
            } else {
                Image(systemName: mode.symbol).font(.system(size: size))
            }
        }
        .frame(height: size * 1.2)
    }
}
