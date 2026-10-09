import AppKit
import SwiftUI
import ScreenCaptureKit

@MainActor
final class WindowPicker: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var continuation: CheckedContinuation<CGWindowID?, Never>?
    func choose(_ windows: [SCWindow]) async -> CGWindowID? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 440), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "Capture a Window"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: WindowPickerView(model: WindowSearch(), windows: windows, finish: { [weak self] id in self?.finish(id) }))
            window.center()
            self.window = window
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
    func windowWillClose(_ notification: Notification) { finish(nil) }
    private func finish(_ id: CGWindowID?) {
        let pending = continuation
        continuation = nil
        window?.delegate = nil
        window?.close()
        window = nil
        pending?.resume(returning: id)
    }
}

private final class WindowSearch: ObservableObject {
    @Published var search = ""
}

private struct WindowPickerView: View {
    @ObservedObject var model: WindowSearch
    let windows: [SCWindow]
    let finish: (CGWindowID?) -> Void
    private var filtered: [SCWindow] {
        windows.filter { model.search.isEmpty || label($0).localizedCaseInsensitiveContains(model.search) }
    }
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Search windows", text: $model.search)
            if filtered.isEmpty { Text("No available windows.").foregroundStyle(.secondary) }
            List(filtered, id: \.windowID) { window in
                Button { finish(window.windowID) } label: {
                    VStack(alignment: .leading) {
                        Text(window.title?.isEmpty == false ? window.title ?? "Untitled" : "Untitled window")
                        Text(window.owningApplication?.applicationName ?? "Application").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).padding(.vertical, 5)
            }
            Button("Cancel") { finish(nil) }.keyboardShortcut(.cancelAction)
        }.padding(16)
    }
    private func label(_ window: SCWindow) -> String { "\(window.owningApplication?.applicationName ?? "") \(window.title ?? "")" }
}
