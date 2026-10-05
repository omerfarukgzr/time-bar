// Time Bar uygulama ikonunu çizer: koyu zemin, soluk halka, turuncu ilerleme yayı, beyaz ibre.
// Kullanım: swift scripts/make_icon.swift <çıktı.png>
import AppKit

let px: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let dark = NSColor(srgbRed: 0x1d / 255, green: 0x1d / 255, blue: 0x1f / 255, alpha: 1)
let orange = NSColor(srgbRed: 1, green: 0x7a / 255, blue: 0x1a / 255, alpha: 1)

// Zemin (macOS ikon ızgarası: 824px kare, 100px kenar boşluğu)
let bg = NSBezierPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), xRadius: 188, yRadius: 188)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
dark.setFill()
bg.fill()
ctx.restoreGState()

let c = CGPoint(x: 512, y: 500)
let r: CGFloat = 250
let lw: CGFloat = 64

// Üstteki düğme (kronometre)
let knob = NSBezierPath(roundedRect: CGRect(x: 512 - 44, y: c.y + r + lw / 2 + 18, width: 88, height: 56), xRadius: 18, yRadius: 18)
NSColor.white.setFill()
knob.fill()

// Soluk halka
let track = NSBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
track.lineWidth = lw
NSColor.white.withAlphaComponent(0.22).setStroke()
track.stroke()

// Tepeden saat yönünde %70'lik turuncu yay
let arc = NSBezierPath()
arc.appendArc(withCenter: c, radius: r, startAngle: 90, endAngle: 90 - 0.7 * 360, clockwise: true)
arc.lineWidth = lw
arc.lineCapStyle = .round
orange.setStroke()
arc.stroke()

// İbre ve merkez
let hand = NSBezierPath()
hand.move(to: c)
let a = 0.7 * 2 * Double.pi
hand.line(to: CGPoint(x: c.x + 170 * CGFloat(sin(a)), y: c.y + 170 * CGFloat(cos(a))))
hand.lineWidth = 34
hand.lineCapStyle = .round
NSColor.white.setStroke()
hand.stroke()
NSColor.white.setFill()
NSBezierPath(ovalIn: CGRect(x: c.x - 34, y: c.y - 34, width: 68, height: 68)).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
