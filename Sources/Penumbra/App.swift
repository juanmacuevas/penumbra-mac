// Penumbra — fine control of brightness, color temperature (down to pure red) and keyboard
// backlight from the brightness keys, plus Fn Lock. Menu bar app, no Dock icon.

import Cocoa
import ServiceManagement

@main
enum PenumbraMain {
    static func main() {
        verbose = CommandLine.arguments.contains("-v") || CommandLine.arguments.contains("--verbose")
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pauseItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var paused = false
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Temperature.setUpGamma()
        setUpMenu()
        observeSystemChanges()
        startTapOrAskForPermission()
    }

    // MARK: Accessibility permission

    private func startTapOrAskForPermission() {
        if EventTap.start() {
            permissionItem.isHidden = true
            log("running. brightness keys: brightness · shift: temperature · control: keyboard · both keys: cycle · fn+Esc: Fn Lock")
            return
        }
        permissionItem.isHidden = false
        // Shows the system prompt that leads to System Settings → Privacy & Security → Accessibility.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        log("waiting for Accessibility permission…")
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted(), EventTap.start() else { return }
            timer.invalidate()
            self?.permissionItem.isHidden = true
            log("permission granted, running")
        }
    }

    // MARK: Menu bar

    private func setUpMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuViews.statusIcon()

        let menu = NSMenu()
        permissionItem = NSMenuItem(title: L("Grant Accessibility permission…", "Dar permiso de Accesibilidad…"),
                                    action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionItem.target = self
        permissionItem.isHidden = true
        menu.addItem(permissionItem)

        pauseItem = NSMenuItem(title: L("Pause", "Pausar"), action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        loginItem = NSMenuItem(title: L("Open at Login", "Abrir al iniciar sesión"), action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())
        if #available(macOS 14.0, *) {
            menu.addItem(.sectionHeader(title: L("Shortcuts", "Atajos")))
        }
        menu.addItem(MenuViews.shortcutsItem())
        menu.addItem(.separator())

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let about = NSMenuItem(title: "Penumbra \(version) · © 2026 JuanMa Cuevas", action: #selector(openProjectPage), keyEquivalent: "")
        about.target = self
        about.attributedTitle = NSAttributedString(string: about.title, attributes: [
            .font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.secondaryLabelColor])
        menu.addItem(about)

        let quit = NSMenuItem(title: L("Quit Penumbra", "Salir de Penumbra"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        statusItem.menu = menu
    }

    @objc private func togglePause() {
        paused.toggle()
        if paused {
            EventTap.pause()
            Temperature.resetGamma()
        } else {
            EventTap.start()
        }
        pauseItem.title = paused ? L("Resume", "Reanudar") : L("Pause", "Pausar")
        statusItem.button?.appearsDisabled = paused
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            log("login item error: \(error.localizedDescription)")
        }
    }

    @objc private func openProjectPage() {
        if let url = URL(string: "https://github.com/juanmacuevas/penumbra-mac") { NSWorkspace.shared.open(url) }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: System changes

    private func observeSystemChanges() {
        // macOS may reset gamma tables on wake or display changes.
        let reapply: (Notification) -> Void = { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { Temperature.reapplyGammaIfNeeded() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main, using: reapply)
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main, using: reapply)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main, using: reapply)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}
