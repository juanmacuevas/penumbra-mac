// Menu bar glyph and the shortcuts list shown in the menu.

import Cocoa

enum MenuViews {
    /// Monochrome version of the app icon ("Eclipse"): a sun crescent with the covering disc
    /// outlined. Template image, so macOS tints it for light/dark menu bars.
    static func statusIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            // Same geometry as Resources/AppIcon.svg, scaled to 18 pt (y axis pointing up).
            let sun = NSRect(x: 7.96 - 6.24, y: 7.96 - 6.24, width: 12.48, height: 12.48)
            let moon = NSRect(x: 10.82 - 5.72, y: 10.56 - 5.72, width: 11.44, height: 11.44)
            NSColor.black.setFill()
            NSBezierPath(ovalIn: sun).fill()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: moon.insetBy(dx: -1.1, dy: -1.1)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver
            let outline = NSBezierPath(ovalIn: moon)
            outline.lineWidth = 1.1
            NSColor.black.withAlphaComponent(0.5).setStroke()
            outline.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Penumbra"
        return image
    }

    private enum Key {
        case text(String)
        case symbol(String)
    }

    /// The shortcuts list: keys drawn as keycaps, descriptions in the normal label color.
    static func shortcutsItem() -> NSMenuItem {
        let rows: [([Key], String)] = [
            ([.symbol("sun.max")], L("Brightness", "Brillo")),
            ([.text("⇧"), .symbol("sun.max")], L("Color temperature", "Temperatura de color")),
            ([.text("⌃"), .symbol("sun.max")], L("Keyboard backlight", "Luz del teclado")),
            ([.symbol("sun.min"), .text("+"), .symbol("sun.max")], L("Cycle mode", "Cambiar de modo")),
            ([.text("fn"), .text("esc")], "Fn Lock"),
        ]

        let grid = NSGridView(views: rows.map { keys, description in
            let caps = NSStackView(views: keys.map(keycap))
            caps.spacing = 3
            let label = NSTextField(labelWithString: description)
            label.font = .menuFont(ofSize: 13)
            label.textColor = .labelColor
            return [caps, label]
        })
        grid.columnSpacing = 12
        grid.rowSpacing = 7
        grid.rowAlignment = .firstBaseline
        grid.column(at: 0).xPlacement = .trailing
        for row in 0..<grid.numberOfRows { grid.row(at: row).yPlacement = .center }

        let size = grid.fittingSize
        let container = NSView(frame: NSRect(x: 0, y: 0, width: size.width + 28, height: size.height + 12))
        grid.frame = NSRect(x: 14, y: 4, width: size.width, height: size.height)
        container.addSubview(grid)

        let item = NSMenuItem()
        item.view = container
        return item
    }

    private static func keycap(_ key: Key) -> NSView {
        if case .text("+") = key {   // separator between two keys, not a key itself
            let plus = NSTextField(labelWithString: "+")
            plus.font = .systemFont(ofSize: 11, weight: .medium)
            plus.textColor = .secondaryLabelColor
            return plus
        }
        let content: NSView
        switch key {
        case .text(let s):
            let label = NSTextField(labelWithString: s)
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.textColor = .labelColor
            content = label
        case .symbol(let name):
            let view = NSImageView(image: NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage())
            view.symbolConfiguration = .init(pointSize: 11, weight: .medium)
            view.contentTintColor = .labelColor
            content = view
        }
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 4
        box.borderWidth = 0.5
        box.borderColor = .tertiaryLabelColor
        box.fillColor = .quaternaryLabelColor
        box.titlePosition = .noTitle
        box.contentViewMargins = NSSize(width: 5, height: 1)
        box.contentView = content
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 18).isActive = true
        box.widthAnchor.constraint(greaterThanOrEqualToConstant: 20).isActive = true
        return box
    }
}
