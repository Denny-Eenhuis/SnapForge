import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let captureService = CaptureService()
    private let preview = PreviewController()
    private let preferencesController = PreferencesController()
    private let regionSelector = RegionSelector()
    private let windowPicker = WindowPicker()
    private let shortcuts = ShortcutManager()
    private let displayMenu = NSMenu()
    private var capturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Copies of this utility share shortcuts and preferences. Keep one instance.
        if let bundleID = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
            existing.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SnapForge")
        item.button?.toolTip = "SnapForge — local screenshots"
        let menu = NSMenu()
        add("Capture Main Display", action: #selector(captureMain), to: menu)
        let displays = NSMenuItem(title: "Capture Display", action: nil, keyEquivalent: "")
        displays.submenu = displayMenu
        displayMenu.delegate = self
        menu.addItem(displays)
        add("Capture Region…", action: #selector(captureRegion), to: menu)
        add("Capture Window…", action: #selector(captureWindow), to: menu)
        add("Scrolling Capture…", action: #selector(captureScrolling), to: menu)
        menu.addItem(.separator())
        add("Preferences…", action: #selector(preferences), key: ",", to: menu)
        add("Screen Recording Settings…", action: #selector(openPermissions), to: menu)
        add("About SnapForge", action: #selector(about), to: menu)
        menu.addItem(.separator())
        add("Quit SnapForge", action: #selector(quit), key: "q", to: menu)
        item.menu = menu
        statusItem = item
        shortcuts.action = { [weak self] id in
            switch id {
            case 1: self?.captureMain()
            case 2: self?.captureRegion()
            case 3: self?.captureWindow()
            default: break
            }
        }
        applyShortcuts()
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        preview.canQuit() ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcuts.shutdown()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferences()
        return true
    }

    private func add(_ title: String, action: Selector, key: String = "", to menu: NSMenu) {
        menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === displayMenu else { return }
        menu.removeAllItems()
        for screen in NSScreen.screens {
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { continue }
            let entry = NSMenuItem(title: screen.localizedName + (id == CGMainDisplayID() ? " (Main)" : ""), action: #selector(captureSelectedDisplay(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = NSNumber(value: id)
            menu.addItem(entry)
        }
    }
    @objc private func captureMain() { capture(.display(CGMainDisplayID())) }
    @objc private func captureSelectedDisplay(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? NSNumber { capture(.display(id.uint32Value)) }
    }
    @objc private func captureRegion() { capture(.region) }
    @objc private func captureWindow() { capture(.window) }
    @objc private func captureScrolling() {
        guard !capturing else { return }
        guard CGPreflightScreenCaptureAccess() else { showError("Enable SnapForge Screen Recording permission, then quit and reopen the app."); return }
        capturing = true
        Task {
            defer { capturing = false }
            do {
                try await Task.sleep(for: .milliseconds(250))
                var snapshots: [RegionSelector.Snapshot] = []
                for screen in NSScreen.screens {
                    guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { continue }
                    snapshots.append(.init(frame: screen.frame, image: try await captureService.captureDisplay(id), displayID: id))
                }
                guard let selection = await regionSelector.selectRegion(snapshots), selection.displayID != nil else { return }
                let controller = ScrollingCaptureController(selection: selection)
                controller.completed = { [weak owner = self] image in owner?.deliver(image) }
                AdvancedWindows.shared.retain(controller, window: controller.window); controller.show()
            } catch { showError(error.localizedDescription) }
        }
    }
    private enum CaptureKind { case display(CGDirectDisplayID), region, window }
    private func capture(_ kind: CaptureKind) {
        guard !capturing else { return }
        guard CGPreflightScreenCaptureAccess() else {
            let granted = CGRequestScreenCaptureAccess()
            showError(granted ? "Screen Recording access was granted. Try the capture again; macOS may require quitting and reopening SnapForge." : "Screen Recording permission is required. Enable SnapForge in System Settings → Privacy & Security → Screen Recording, then quit and reopen SnapForge.")
            return
        }
        capturing = true
        Task {
            defer { capturing = false }
            do {
                try await Task.sleep(for: .milliseconds(250))
                let image: CGImage?
                switch kind {
                case .display(let id): image = try await captureService.captureDisplay(id)
                case .region:
                    var snapshots: [RegionSelector.Snapshot] = []
                    for screen in NSScreen.screens {
                        guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { continue }
                        snapshots.append(.init(frame: screen.frame, image: try await captureService.captureDisplay(id), displayID: id))
                    }
                    image = await regionSelector.select(snapshots)
                case .window:
                    let content = try await captureService.content()
                    let windows = content.windows.filter {
                        $0.windowLayer == 0 && $0.frame.width > 1 && $0.frame.height > 1 && $0.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier
                    }.sorted { ($0.owningApplication?.applicationName ?? "") < ($1.owningApplication?.applicationName ?? "") }
                    if let id = await windowPicker.choose(windows) {
                        try await Task.sleep(for: .milliseconds(200))
                        image = try await captureService.captureWindow(id)
                    } else { image = nil }
                }
                if let image { deliver(image) }
            } catch { showError(error.localizedDescription) }
        }
    }
    private func deliver(_ image: CGImage) {
        let settings = Preferences.shared
        var errors: [String] = []
        var savedURL: URL?
        if settings.copyAutomatically {
            do { try ImageOutput.copy(image) } catch { errors.append("Clipboard: \(error.localizedDescription)") }
        }
        if settings.autoSave {
            if let folder = settings.folder {
                do {
                    let destination = folder.appendingPathComponent(ImageOutput.filename(format: settings.format))
                    try ImageOutput.save(image, format: settings.format, to: destination)
                    savedURL = destination
                }
                catch { errors.append("Automatic save: \(error.localizedDescription)") }
            } else { errors.append("Choose an automatic save folder in Preferences.") }
        }
        // Keep the capture recoverable if there is no output or any output failed.
        if settings.showPreview || !errors.isEmpty || (!settings.copyAutomatically && !settings.autoSave) { preview.show(image, savedURL: savedURL) }
        if !errors.isEmpty { showError(errors.joined(separator: "\n")) }
    }
    @objc private func preferences() { preferencesController.show { [weak self] in self?.applyShortcuts() } }
    private func applyShortcuts() {
        do { try shortcuts.apply(Preferences.shared) } catch { showError(error.localizedDescription) }
    }
    @objc private func openPermissions() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "SnapForge", .applicationVersion: "0.4.3", .credits: NSAttributedString(string: "Local screenshot capture. Independently implemented.")])
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
