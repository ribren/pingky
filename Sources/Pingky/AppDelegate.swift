import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private static let targetKey = "PingTarget"
    private let monitor = PingMonitor(
        host: UserDefaults.standard.string(forKey: AppDelegate.targetKey) ?? "8.8.8.8"
    )
    private let updates = UpdateChecker()
    private let presetTargets: [(label: String, host: String)] = [
        ("Google DNS (8.8.8.8)", "8.8.8.8"),
        ("Cloudflare (1.1.1.1)", "1.1.1.1"),
        ("Quad9 (9.9.9.9)", "9.9.9.9"),
    ]
    private var panel: NSPanel!
    private var statusItem: NSStatusItem!

    private let frameKey = "PingkyPanelFrame"
    private let defaultSize = NSSize(width: 380, height: 150)
    private let sponsorURL = URL(string: "https://github.com/sponsors/ribren")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildPanel()
        buildStatusItem()
        monitor.start()
        updates.onChange = { [weak self] in self?.rebuildMenu() }
        updates.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        if let panel { UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey) }
    }

    // MARK: - Panel

    private func buildPanel() {
        let initialRect = savedFrame() ?? defaultRect()

        let panel = NSPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true

        // Blurred, rounded background for the widget look.
        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true

        let host = NSHostingView(rootView: PingGridView().environmentObject(monitor))
        host.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            host.topAnchor.constraint(equalTo: effect.topAnchor),
            host.bottomAnchor.constraint(equalTo: effect.bottomAnchor)
        ])

        panel.contentView = effect
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private func savedFrame() -> NSRect? {
        guard let string = UserDefaults.standard.string(forKey: frameKey) else { return nil }
        let rect = NSRectFromString(string)
        return rect.width > 0 && rect.height > 0 ? rect : nil
    }

    private func defaultRect() -> NSRect {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: screen.maxX - defaultSize.width - 24,
            y: screen.maxY - defaultSize.height - 24,
            width: defaultSize.width,
            height: defaultSize.height
        )
    }

    // MARK: - Status item (menu bar)

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wave.3.right", accessibilityDescription: "Pingky")
        }
        rebuildMenu()
    }

    /// Rebuilt whenever update state changes, so the menu can grow an
    /// "Update to vX.Y" item (items with a nil action render disabled).
    private func rebuildMenu() {
        let menu = NSMenu()
        if let update = updates.available {
            if updates.installing {
                menu.addItem(NSMenuItem(title: "Updating to v\(update.version)…", action: nil, keyEquivalent: ""))
            } else {
                menu.addItem(NSMenuItem(title: "Update to v\(update.version)", action: #selector(installUpdate), keyEquivalent: ""))
            }
            if let error = updates.lastError {
                menu.addItem(NSMenuItem(title: "Update failed (\(error)) — open releases", action: #selector(openReleases), keyEquivalent: ""))
            }
            menu.addItem(.separator())
        }
        menu.addItem(NSMenuItem(title: "Show / Hide", action: #selector(togglePanel), keyEquivalent: "s"))
        menu.addItem(targetMenuItem())
        menu.addItem(NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdates), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Buy me a coffee ☕", action: #selector(openSponsor), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pingky", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    /// "Ping Target" submenu: presets, the current custom target if any,
    /// and a Custom… dialog accepting an IP, hostname, or URL.
    private func targetMenuItem() -> NSMenuItem {
        let submenu = NSMenu()
        for preset in presetTargets {
            let item = NSMenuItem(title: preset.label, action: #selector(selectPresetTarget(_:)), keyEquivalent: "")
            item.representedObject = preset.host
            item.state = monitor.host == preset.host ? .on : .off
            item.target = self
            submenu.addItem(item)
        }
        if !presetTargets.contains(where: { $0.host == monitor.host }) {
            let current = NSMenuItem(title: monitor.host, action: nil, keyEquivalent: "")
            current.state = .on
            submenu.addItem(current)
        }
        submenu.addItem(.separator())
        let custom = NSMenuItem(title: "Custom…", action: #selector(customTarget), keyEquivalent: "")
        custom.target = self
        submenu.addItem(custom)

        let item = NSMenuItem(title: "Ping Target: \(monitor.host)", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    @objc private func selectPresetTarget(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? String else { return }
        applyTarget(target)
    }

    @objc private func customTarget() {
        let alert = NSAlert()
        alert.messageText = "Ping Target"
        alert.informativeText = "An IP address, hostname, or URL — Pingky pings its host once a second."
        alert.addButton(withTitle: "Use Target")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = monitor.host
        field.placeholderString = "8.8.8.8, example.com, or https://…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        if let normalized = PingMonitor.normalizeTarget(field.stringValue) {
            applyTarget(normalized)
        } else {
            let oops = NSAlert()
            oops.messageText = "That doesn't look pingable"
            oops.informativeText = "Try an IP address (8.8.8.8), a hostname (example.com), or a URL (https://example.com)."
            oops.runModal()
        }
    }

    private func applyTarget(_ target: String) {
        UserDefaults.standard.set(target, forKey: Self.targetKey)
        monitor.retarget(target)
        rebuildMenu()
    }

    @objc private func installUpdate() {
        updates.install()
    }

    @objc private func checkForUpdates() {
        updates.check()
    }

    @objc private func openReleases() {
        if let update = updates.available {
            NSWorkspace.shared.open(update.pageURL)
        }
    }

    @objc private func openSponsor() {
        NSWorkspace.shared.open(sponsorURL)
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
