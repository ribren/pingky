import AppKit

// Program entry runs on the main thread, so it is safe to assume main-actor isolation.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    // Accessory app: no Dock icon, lives in the menu bar with a floating panel.
    // PINGKY_REGULAR=1 forces a Dock presence (used only for screenshot verification).
    if ProcessInfo.processInfo.environment["PINGKY_REGULAR"] == "1" {
        app.setActivationPolicy(.regular)
    } else {
        app.setActivationPolicy(.accessory)
    }

    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
