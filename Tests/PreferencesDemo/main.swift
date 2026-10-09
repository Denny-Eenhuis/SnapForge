import AppKit

@MainActor
final class DemoDelegate: NSObject, NSApplicationDelegate {
    let preferences = PreferencesController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .aqua)
        preferences.show(apply: {})
        let menu = NSMenu()
        let item = NSMenuItem(title: "Validation", action: nil, keyEquivalent: "")
        let actions = NSMenu()
        actions.addItem(withTitle: "Light Appearance", action: #selector(light), keyEquivalent: "l").target = self
        actions.addItem(withTitle: "Dark Appearance", action: #selector(dark), keyEquivalent: "d").target = self
        actions.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q").target = self
        item.submenu = actions; menu.addItem(item); NSApp.mainMenu = menu
    }
    @objc func light() { NSApp.appearance = NSAppearance(named: .aqua) }
    @objc func dark() { NSApp.appearance = NSAppearance(named: .darkAqua) }
    @objc func quit() { NSApp.terminate(nil) }
}
MainActor.assumeIsolated {
let app = NSApplication.shared
let delegate = DemoDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

}
