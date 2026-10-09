import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let captureService = CaptureService()
    private let preview = PreviewController()
    private var capturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SnapForge")
        item.button?.toolTip = "SnapForge — local screenshots"
        let menu = NSMenu()
        menu.addItem(withTitle: "Capture Main Display", action: #selector(capture), keyEquivalent: "s").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Screen Recording Settings…", action: #selector(openPermissions), keyEquivalent: "").target = self
        menu.addItem(withTitle: "About SnapForge", action: #selector(about), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SnapForge", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        statusItem = item
    }

    @objc private func capture() {
        guard !capturing else { return }
        guard CGPreflightScreenCaptureAccess() else {
            let granted = CGRequestScreenCaptureAccess()
            if !granted { showError("Screen Recording permission is required. Enable SnapForge in System Settings → Privacy & Security → Screen Recording, then quit and reopen SnapForge.") }
            return
        }
        capturing = true
        Task {
            defer { capturing = false }
            do {
                // Allow the menu to disappear before capture.
                try await Task.sleep(for: .milliseconds(250))
                let image = try await captureService.captureMainDisplay()
                preview.show(image)
            } catch { showError(error.localizedDescription) }
        }
    }

    @objc private func openPermissions() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "SnapForge", .applicationVersion: "0.1.0", .credits: NSAttributedString(string: "Local screenshot capture. Phase 0.")])
    }
    @objc private func quit() { NSApp.terminate(nil) }
    private func showError(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "SnapForge"
        alert.informativeText = message
        alert.runModal()
    }
}
