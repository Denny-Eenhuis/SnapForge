import AppKit

@MainActor
final class PreviewController {
    private var window: NSWindow?
    private var image: CGImage?

    func show(_ captured: CGImage) {
        image = captured
        let view = NSImageView()
        view.image = NSImage(cgImage: captured, size: NSSize(width: captured.width, height: captured.height))
        view.imageScaling = .scaleProportionallyUpOrDown
        view.setAccessibilityLabel("Captured main display")
        let save = NSButton(title: "Save PNG…", target: self, action: #selector(savePNG))
        let copy = NSButton(title: "Copy", target: self, action: #selector(copyImage))
        let buttons = NSStackView(views: [copy, save])
        buttons.orientation = .horizontal
        let content = NSStackView(views: [view, buttons])
        content.orientation = .vertical
        content.spacing = 12
        content.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        let preview = window ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        preview.isReleasedWhenClosed = false
        preview.title = "SnapForge — Capture"
        preview.contentView = content
        if window == nil { preview.center() }
        window = preview
        NSApp.activate(ignoringOtherApps: true)
        preview.makeKeyAndOrderFront(nil)
    }

    @objc private func copyImage() {
        guard let image else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))])
    }
    @objc private func savePNG() {
        guard let image, let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "SnapForge-\(Int(Date().timeIntervalSince1970)).png"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let bitmap = NSBitmapImageRep(cgImage: image)
                guard let data = bitmap.representation(using: .png, properties: [:]) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: url, options: .atomic)
            } catch {
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: window)
            }
        }
    }
}
