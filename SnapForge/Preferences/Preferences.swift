import SwiftUI
import AppKit

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    private let defaults: UserDefaults
    @Published var copyAutomatically: Bool { didSet { defaults.set(copyAutomatically, forKey: "copyAutomatically") } }
    @Published var showPreview: Bool { didSet { defaults.set(showPreview, forKey: "showPreview") } }
    @Published var automaticScrolling: Bool { didSet { defaults.set(automaticScrolling, forKey: "automaticScrolling") } }
    @Published var autoSave: Bool { didSet { defaults.set(autoSave, forKey: "autoSave") } }
    @Published var format: ImageFormat { didSet { defaults.set(format.rawValue, forKey: "format") } }
    @Published var folder: URL? { didSet { defaults.set(folder?.path, forKey: "folder") } }
    @Published var shortcutsEnabled: Bool { didSet { defaults.set(shortcutsEnabled, forKey: "shortcutsEnabled") } }
    @Published var displayKey: String { didSet { defaults.set(displayKey, forKey: "displayKey") } }
    @Published var regionKey: String { didSet { defaults.set(regionKey, forKey: "regionKey") } }
    @Published var windowKey: String { didSet { defaults.set(windowKey, forKey: "windowKey") } }
    @Published var shortcutModifiers: String { didSet { defaults.set(shortcutModifiers, forKey: "shortcutModifiers") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: ["automaticScrolling": true, "copyAutomatically": true, "showPreview": true, "displayKey": "1", "regionKey": "2", "windowKey": "3", "shortcutModifiers": "commandShift", "shortcutsEnabled": true])
        copyAutomatically = defaults.bool(forKey: "copyAutomatically")
        showPreview = defaults.bool(forKey: "showPreview")
        automaticScrolling = defaults.bool(forKey: "automaticScrolling")
        autoSave = defaults.bool(forKey: "autoSave")
        format = ImageFormat(rawValue: defaults.string(forKey: "format") ?? "png") ?? .png
        folder = defaults.string(forKey: "folder").map { URL(fileURLWithPath: $0, isDirectory: true) }
        shortcutsEnabled = defaults.bool(forKey: "shortcutsEnabled")
        displayKey = defaults.string(forKey: "displayKey") ?? "1"
        regionKey = defaults.string(forKey: "regionKey") ?? "2"
        windowKey = defaults.string(forKey: "windowKey") ?? "3"
        shortcutModifiers = defaults.string(forKey: "shortcutModifiers") ?? "commandShift"
    }
}

@MainActor
final class PreferencesController {
    private var window: NSWindow?
    func show(apply: @escaping () -> Void) {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 620), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "SnapForge Preferences"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: PreferencesView(apply: apply))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct PreferencesView: View {
    @ObservedObject var preferences = Preferences.shared
    let apply: () -> Void
    var body: some View {
        Form {
            Toggle("Copy captures to clipboard", isOn: $preferences.copyAutomatically)
            Toggle("Show preview after capture", isOn: $preferences.showPreview)
            Picker("Output format", selection: $preferences.format) {
                Text("PNG").tag(ImageFormat.png)
                Text("JPEG").tag(ImageFormat.jpeg)
            }
            Toggle("Automatically save captures", isOn: $preferences.autoSave)
            HStack {
                Text(preferences.folder?.path ?? "Choose a save folder").lineLimit(1).truncationMode(.middle)
                Button("Choose…") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK { preferences.folder = panel.url }
                }
            }
            Toggle("Automatically scroll selected capture region", isOn: $preferences.automaticScrolling)
            Text("Scrolling Capture starts after you drag a region. Escape stops it and opens the result.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Toggle("Enable global capture shortcuts", isOn: $preferences.shortcutsEnabled)
            Picker("Modifiers", selection: $preferences.shortcutModifiers) {
                Text("⌘ ⇧").tag("commandShift")
                Text("⌘ ⌥").tag("commandOption")
                Text("⌃ ⌥").tag("controlOption")
            }
            keyPicker("Main display", selection: $preferences.displayKey)
            keyPicker("Region", selection: $preferences.regionKey)
            keyPicker("Window", selection: $preferences.windowKey)
            Button("Apply Shortcuts", action: apply)
            Text("Choose different keys for each command. Conflicts with other apps are reported when applying.").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 500, height: 620)
    }
    private func keyPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Array("1234567890abcdefghijklmnopqrstuvwxyz").map(String.init), id: \.self) { Text($0.uppercased()).tag($0) }
        }
    }
}
