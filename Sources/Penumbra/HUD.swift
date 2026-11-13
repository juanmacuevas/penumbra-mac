// Native-looking on-screen display: a floating glass capsule at the top right.
// (The system's own OSD always shows the real brightness, so it can't show our steps or temperature.)

import Cocoa

final class HUD {
    static let shared = HUD()

    private static let size = NSSize(width: 280, height: 46)

    private let panel: NSPanel
    private let icon = NSImageView()
    private let track = NSView()
    private let fill = NSView()
    private let label = NSTextField(labelWithString: "")
    private let gradient = CAGradientLayer()   // temperature: red → orange → white
    private var hideWork: DispatchWorkItem?
    private var visible = false

    private init() {
        let rect = NSRect(origin: .zero, size: HUD.size)
        panel = NSPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.alphaValue = 0

        let content = NSView(frame: rect)
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView(frame: rect)
            glass.cornerRadius = HUD.size.height / 2
            glass.contentView = content
            panel.contentView = glass
        } else {
            let blur = NSVisualEffectView(frame: rect)
            blur.material = .hudWindow
            blur.blendingMode = .behindWindow
            blur.state = .active
            blur.wantsLayer = true
            blur.layer?.cornerRadius = HUD.size.height / 2
            blur.layer?.masksToBounds = true
            blur.addSubview(content)
            panel.contentView = blur
        }

        let h = HUD.size.height
        icon.frame = NSRect(x: 16, y: (h - 22) / 2, width: 22, height: 22)
        icon.symbolConfiguration = .init(pointSize: 15, weight: .semibold)
        content.addSubview(icon)

        track.frame = NSRect(x: 48, y: (h - 6) / 2, width: HUD.size.width - 48 - 18 - 62, height: 6)
        track.wantsLayer = true
        track.layer?.cornerRadius = 3
        track.layer?.masksToBounds = true
        content.addSubview(track)

        fill.wantsLayer = true
        fill.layer?.masksToBounds = true
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        fill.layer?.addSublayer(gradient)
        track.addSubview(fill)

        label.frame = NSRect(x: HUD.size.width - 18 - 54, y: (h - 16) / 2, width: 54, height: 16)
        content.addSubview(label)
    }

    func showFnLock(standardFunctionKeys: Bool) {
        show(axis: .brightness, fraction: 0, text: standardFunctionKeys ? "F1–F12" : "☀︎ ♪", symbol: "fn", hideTrack: true)
    }

    func show(axis: Axis, fraction: Double, text: String, symbol: String? = nil, hideTrack: Bool = false) {
        let isTemperature = axis == .temperature
        track.isHidden = hideTrack

        // Label: secondary color; a leading "●" (red zone) is drawn red.
        let attr = NSMutableAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        if text.hasPrefix("●") {
            attr.addAttribute(.foregroundColor, value: NSColor.systemRed, range: NSRange(location: 0, length: 1))
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        attr.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attr.length))
        label.attributedStringValue = attr

        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == builtinDisplay
        } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.maxX - HUD.size.width - 12, y: frame.maxY - HUD.size.height - 10))
        }

        let name = symbol ?? (isTemperature ? "thermometer.medium" : axis == .keyboard ? "keyboard" : "sun.max.fill")
        icon.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)

        panel.contentView?.effectiveAppearance.performAsCurrentDrawingAppearance {
            icon.contentTintColor = isTemperature ? .systemOrange : .labelColor
            // The bar is always white (not the theme's text color, which turns black in light mode).
            track.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
            fill.layer?.backgroundColor = isTemperature ? NSColor.clear.cgColor : NSColor.white.cgColor
            let red = Temperature.redSteps / Temperature.steps
            let nightShiftMin = Temperature.position(ofKelvin: Temperature.range.min) / Temperature.steps
            if nightShiftMin > 0 {
                gradient.colors = [NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1).cgColor,
                                   NSColor(srgbRed: 1, green: 0.25, blue: 0.05, alpha: 1).cgColor,
                                   NSColor.systemOrange.cgColor, NSColor.white.cgColor]
                gradient.locations = [0, NSNumber(value: red), NSNumber(value: nightShiftMin), 1]
            } else {
                gradient.colors = [NSColor.systemOrange.cgColor, NSColor.white.cgColor]
                gradient.locations = nil
            }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = track.bounds   // gradient spans the whole track; the fill crops it
        gradient.isHidden = !isTemperature
        CATransaction.commit()
        fill.frame = NSRect(x: 0, y: 0, width: track.bounds.width * clamp(fraction, 0, 1), height: track.bounds.height)

        hideWork?.cancel()
        if !visible {
            visible = true
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.12; panel.animator().alphaValue = 1 }
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.visible = false
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.35; self.panel.animator().alphaValue = 0 },
                                                 completionHandler: { if !self.visible { self.panel.orderOut(nil) } })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.hudVisibleFor, execute: work)
    }
}
