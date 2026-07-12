import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let monitor = PingMonitor(host: "8.8.8.8")
    private var panel: NSPanel!
    private var statusItem: NSStatusItem!

    private let frameKey = "PingkyPanelFrame"
    private let defaultSize = NSSize(width: 380, height: 150)
    private let sponsorURL = URL(string: "https://github.com/sponsors/ribren")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildPanel()
        buildStatusItem()
        monitor.start()
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

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show / Hide", action: #selector(togglePanel), keyEquivalent: "s"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Buy me a coffee ☕", action: #selector(openSponsor), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Pingky", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
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
