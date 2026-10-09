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
        view.setAccessibilityLabel("Captured screenshot")
        let save = NSButton(title: "Save As…", target: self, action: #selector(saveImage))
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
        do { try ImageOutput.copy(image) } catch { NSAlert(error: error).runModal() }
    }
    @objc private func saveImage() {
        guard let image, let window else { return }
        let format = Preferences.shared.format
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.directoryURL = Preferences.shared.folder
        panel.nameFieldStringValue = ImageOutput.filename(format: format)
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            do { try ImageOutput.save(image, format: format, to: url) }
            catch { NSAlert(error: error).beginSheetModal(for: window) }
        }
    }
}
