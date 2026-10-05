import AppKit

/// Kenarlıksız, odak alabilen, uygulamayı öne getirmeyen panel (Sound Mix'teki ile aynı).
final class MenuPanel: NSPanel {
    static let cornerRadius: CGFloat = 12

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovable = false
        hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool { true }

    var onCancel: () -> Void = {}

    override func cancelOperation(_ sender: Any?) { onCancel() }

    private var showing = false

    func show() {
        showing = true
        hasShadow = false
        makeKeyAndOrderFront(nil)
        animate(show: true) { [weak self] in
            guard let self, self.showing else { return }
            self.hasShadow = true
            self.invalidateShadow()
        }
    }

    func hide() {
        showing = false
        hasShadow = false
        animate(show: false) { [weak self] in
            guard let self, !self.showing else { return }
            self.orderOut(nil)
        }
    }

    /// macOS 26 ve sonrasında sistem menüleriyle aynı Liquid Glass, daha eskilerde menü materyalli buzlu cam.
    static func makeBackground(containing hosting: NSView) -> NSView {
        let container = NSView()
        container.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
        ])

        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .regular
            glass.cornerRadius = cornerRadius
            glass.contentView = container
            glass.wantsLayer = true
            return glass
        }

        let effect = NSVisualEffectView()
        effect.material = .menu
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        container.frame = effect.bounds
        effect.addSubview(container)
        return effect
    }

    /// İçeriği katman düzeyinde soldurup kaydırır. Buzlu cam arka plan pencere
    /// şeffaflığı animasyonunu yok saydığı için pencereyi değil içeriği canlandırıyoruz.
    private func animate(show: Bool, completion: @escaping @MainActor () -> Void) {
        guard let layer = contentView?.layer else { completion(); return }
        let lifted = CATransform3DMakeTranslation(0, 8, 0)
        let toOpacity: Float = show ? 1 : 0
        let toTransform = show ? CATransform3DIdentity : lifted

        CATransaction.begin()
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { completion() } }
        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = show ? 0 : 1
        opacity.toValue = toOpacity
        let move = CABasicAnimation(keyPath: "transform")
        move.fromValue = show ? lifted : CATransform3DIdentity
        move.toValue = toTransform
        let group = CAAnimationGroup()
        group.animations = [opacity, move]
        group.duration = show ? 0.2 : 0.16
        group.timingFunction = CAMediaTimingFunction(name: show ? .easeOut : .easeIn)
        layer.opacity = toOpacity
        layer.transform = toTransform
        layer.add(group, forKey: "menuTransition")
        CATransaction.commit()
    }
}
