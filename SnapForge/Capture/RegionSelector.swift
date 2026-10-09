import AppKit

@MainActor
final class RegionSelector {
    struct Snapshot {
        let frame: NSRect
        let image: CGImage
    }
    private var windows: [NSWindow] = []
    private var continuation: CheckedContinuation<CGImage?, Never>?
    private var previousApplication: NSRunningApplication?

    func select(_ snapshots: [Snapshot]) async -> CGImage? {
        guard !snapshots.isEmpty else { return nil }
        previousApplication = NSWorkspace.shared.frontmostApplication
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            for snapshot in snapshots {
                let window = SelectionWindow(contentRect: snapshot.frame, styleMask: .borderless, backing: .buffered, defer: false)
                window.level = .screenSaver
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isReleasedWhenClosed = false
                window.isOpaque = true
                let view = SelectionView(frame: NSRect(origin: .zero, size: snapshot.frame.size), image: snapshot.image)
                view.finish = { [weak self] image in self?.finish(image) }
                window.contentView = view
                window.makeFirstResponder(view)
                windows.append(window)
                window.orderFrontRegardless()
            }
            NSApp.activate(ignoringOtherApps: true)
            let mouse = NSEvent.mouseLocation
            (windows.first(where: { $0.frame.contains(mouse) }) ?? windows.first)?.makeKey()
        }
    }
    private func finish(_ image: CGImage?) {
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows.removeAll()
        previousApplication?.activate(options: [])
        previousApplication = nil
        let pending = continuation
        continuation = nil
        pending?.resume(returning: image)
    }
}

private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    let image: CGImage
    var finish: ((CGImage?) -> Void)?
    private var start: NSPoint?
    private var selection: NSRect?
    override var acceptsFirstResponder: Bool { true }
    init(frame: NSRect, image: CGImage) {
        self.image = image
        super.init(frame: frame)
        setAccessibilityLabel("Drag to select a screenshot region. Escape cancels. Selection stays within one display.")
    }
    required init?(coder: NSCoder) { nil }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func draw(_ dirtyRect: NSRect) {
        NSImage(cgImage: image, size: bounds.size).draw(in: bounds)
        NSColor.black.withAlphaComponent(0.35).setFill()
        let mask = NSBezierPath(rect: bounds)
        if let selection { mask.appendRect(selection) }
        mask.windingRule = .evenOdd
        mask.fill()
        if let selection {
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 1
            border.stroke()
        }
        let label = "Drag to capture • Esc to cancel • One display per selection"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor.white, .backgroundColor: NSColor.black.withAlphaComponent(0.7)]
        (label as NSString).draw(at: NSPoint(x: 24, y: bounds.height - 44), withAttributes: attributes)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeKey()
        start = convert(event.locationInWindow, from: nil)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let end = convert(event.locationInWindow, from: nil)
        selection = NSRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        guard let selection, let crop = CaptureGeometry.pixelCrop(selection: selection, viewSize: bounds.size, imageSize: CGSize(width: image.width, height: image.height)), let result = image.cropping(to: crop) else {
            start = nil
            self.selection = nil
            needsDisplay = true
            return
        }
        finish?(result)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { finish?(nil) } else { super.keyDown(with: event) }
    }
}
