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
        let content = NSView()
        content.addSubview(view)
        content.addSubview(buttons)
        view.translatesAutoresizingMaskIntoConstraints = false
        buttons.translatesAutoresizingMaskIntoConstraints = false
        // Ignore the screenshot's intrinsic pixel size when laying out the preview.
        view.setContentHuggingPriority(.init(1), for: .horizontal)
        view.setContentHuggingPriority(.init(1), for: .vertical)
        view.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        view.setContentCompressionResistancePriority(.init(1), for: .vertical)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            view.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            view.topAnchor.constraint(equalTo: content.topAnchor, constant: 16),
            view.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16)
        ])
        let isNew = window == nil
        let preview = window ?? NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        preview.isReleasedWhenClosed = false
        preview.title = "SnapForge — Capture"
        preview.contentMinSize = NSSize(width: 320, height: 240)
        preview.contentView = content
        if isNew {
            let available = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size ?? NSSize(width: 1200, height: 800)
            preview.setContentSize(NSSize(width: min(900, available.width * 0.8), height: min(600, available.height * 0.8)))
            preview.center()
        }
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
