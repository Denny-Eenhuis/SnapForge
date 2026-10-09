import AppKit

@MainActor
final class AnnotationCanvas: NSView {
    let document: EditorDocument
    var tool: EditorTool = .select { didSet { window?.makeFirstResponder(self); needsDisplay = true } }
    var color = NSColor.systemRed
    var thickness: CGFloat = 4
    var fontSize: CGFloat = 28
    var selectedID: UUID? { didSet { selectionChanged?(); needsDisplay = true } }
    var selectionChanged: (() -> Void)?
    var toolChanged: ((EditorTool) -> Void)?
    var command: ((String) -> Void)?
    var reportError: ((Error) -> Void)?
    var zoom: CGFloat = 1
    private var rendered: NSImage?
    private var draft: Annotation?
    private var anchor: CGPoint?
    private var original: Annotation?
    private var resizeEnd = false
    private var panAnchor: CGPoint?
    private var spaceDown = false
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(document: EditorDocument) {
        self.document = document
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Screenshot annotation canvas. Use the toolbar to choose a tool. Drag to draw; V selects; Delete removes; Space-drag pans.")
        refresh()
    }
    required init?(coder: NSCoder) { nil }
    var selected: Annotation? { document.state.annotations.first { $0.id == selectedID } }
    func refresh() {
        var state = document.state
        if let original { state.annotations.removeAll { $0.id == original.id } }
        do {
            let image = try AnnotationRenderer.render(source: document.source, state: state)
            rendered = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        } catch { rendered = nil; reportError?(error) }
        resizeCanvas()
        setAccessibilityValue("\(document.state.annotations.count) editable annotations")
        needsDisplay = true
    }
    func resizeCanvas() { setFrameSize(NSSize(width: document.visibleBounds.width * zoom, height: document.visibleBounds.height * zoom)) }
    private func sourcePoint(_ event: NSEvent) -> CGPoint {
        let location = convert(event.locationInWindow, from: nil)
        return CGPoint(x: location.x / zoom + document.visibleBounds.minX, y: location.y / zoom + document.visibleBounds.minY)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        guard let rendered else { return }
        rendered.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = AffineTransform(scale: zoom)
        (transform as NSAffineTransform).concat()
        let offset = AffineTransform(translationByX: -document.visibleBounds.minX, byY: -document.visibleBounds.minY)
        (offset as NSAffineTransform).concat()
        if let draft {
            if draft.tool == .blur || draft.tool == .pixelate || draft.tool == .crop {
                NSColor.systemBlue.withAlphaComponent(0.2).setFill(); NSBezierPath(rect: draft.rect).fill()
                NSColor.systemBlue.setStroke(); let border = NSBezierPath(rect: draft.rect); border.lineWidth = 1 / zoom; border.stroke()
            } else { AnnotationRenderer.draw(draft) }
        }
        if let selected = draft ?? selected, selectedID != nil {
            NSColor.systemBlue.setStroke()
            let border = NSBezierPath(rect: selected.hitBounds); border.lineWidth = 1 / zoom; border.setLineDash([4 / zoom, 3 / zoom], count: 2, phase: 0); border.stroke()
            if selected.tool != .text && selected.tool != .freehand && selected.tool != .callout {
                for point in [selected.start, selected.end] {
                    let handle = CGRect(x: point.x - 4 / zoom, y: point.y - 4 / zoom, width: 8 / zoom, height: 8 / zoom)
                    NSColor.white.setFill(); NSBezierPath(rect: handle).fill(); NSColor.systemBlue.setStroke(); NSBezierPath(rect: handle).stroke()
                }
            }
        }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: tool == .select ? .arrow : .crosshair) }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if spaceDown {
            panAnchor = convert(event.locationInWindow, from: nil)
            return
        }
        let point = sourcePoint(event)
        anchor = point
        if tool == .select {
            if let selected, [selected.start, selected.end].contains(where: { hypot(point.x - $0.x, point.y - $0.y) < 10 / zoom }), selected.tool != .text && selected.tool != .callout && selected.tool != .freehand {
                original = selected
                resizeEnd = hypot(point.x - selected.end.x, point.y - selected.end.y) < 10 / zoom
            } else {
                selectedID = document.state.annotations.reversed().first { $0.hitBounds.contains(point) }?.id
                original = selected
                resizeEnd = false
                if event.clickCount == 2, let selected, selected.tool == .text {
                    editText(selected); anchor = nil; original = nil; return
                }
            }
            draft = original
            // A hit on the start handle is also a resize, distinct from moving.
            resizing = original.map { $0.tool != .text && $0.tool != .freehand && $0.tool != .callout && (hypot(point.x - $0.start.x, point.y - $0.start.y) < 10 / zoom || resizeEnd) } ?? false
            refresh()
            return
        }
        selectedID = nil
        var annotation = Annotation(tool: tool, start: point, end: point, points: [point], color: color, thickness: thickness, fontSize: fontSize)
        if tool == .text {
            guard let text = askText("", title: "Add Text") else { anchor = nil; return }
            annotation.text = text
            add(annotation); anchor = nil; return
        }
        if tool == .callout {
            annotation.number = (document.state.annotations.filter { $0.tool == .callout }.map(\.number).max() ?? 0) + 1
            add(annotation); anchor = nil; return
        }
        draft = annotation
        needsDisplay = true
    }
    private var resizing = false
    override func mouseDragged(with event: NSEvent) {
        if let panAnchor, let clip = enclosingScrollView?.contentView {
            let position = convert(event.locationInWindow, from: nil)
            clip.scroll(to: CGPoint(x: clip.bounds.minX + panAnchor.x - position.x, y: clip.bounds.minY + panAnchor.y - position.y))
            enclosingScrollView?.reflectScrolledClipView(clip)
            self.panAnchor = convert(event.locationInWindow, from: nil)
            return
        }
        guard let anchor else { return }
        let point = sourcePoint(event)
        if let original {
            if resizing {
                draft = original
                if resizeEnd { draft?.end = point } else { draft?.start = point }
            } else { draft = original.moved(by: CGPoint(x: point.x - anchor.x, y: point.y - anchor.y)) }
        } else {
            draft?.end = point
            if tool == .freehand { draft?.points.append(point) }
        }
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        if panAnchor != nil { panAnchor = nil; return }
        mouseDragged(with: event)
        let result = draft
        let replacing = original?.id
        draft = nil; original = nil; anchor = nil; resizing = false
        guard let result else { return }
        var state = document.state
        if let replacing, let index = state.annotations.firstIndex(where: { $0.id == replacing }) {
            state.annotations[index] = result
            document.commit(state)
            refresh()
        } else if result.tool == .crop {
            let rect = result.rect.integral.intersection(document.visibleBounds)
            if !rect.isNull && rect.width >= 2 && rect.height >= 2 { state.crop = rect; selectedID = nil; document.commit(state) }
        } else if hypot(result.start.x - result.end.x, result.start.y - result.end.y) >= 2 { add(result) }
        needsDisplay = true
    }
    private func add(_ annotation: Annotation) {
        var state = document.state; state.annotations.append(annotation); selectedID = annotation.id; document.commit(state)
    }
    func deleteSelection() {
        guard let selectedID else { return }
        var state = document.state; state.annotations.removeAll { $0.id == selectedID }; self.selectedID = nil; document.commit(state)
    }
    func applyStyle() {
        guard let selectedID, let index = document.state.annotations.firstIndex(where: { $0.id == selectedID }) else { return }
        var state = document.state
        state.annotations[index].color = color; state.annotations[index].thickness = thickness; state.annotations[index].fontSize = fontSize
        document.commit(state)
    }
    func editSelectedText() { if let selected, selected.tool == .text { editText(selected) } }
    private func editText(_ annotation: Annotation) {
        guard let text = askText(annotation.text, title: "Edit Text"), let index = document.state.annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        var state = document.state; state.annotations[index].text = text; document.commit(state)
    }
    private func askText(_ current: String, title: String) -> String? {
        let alert = NSAlert(); alert.messageText = title; alert.addButton(withTitle: "Apply"); alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: current); field.frame = NSRect(x: 0, y: 0, width: 360, height: 28)
        field.setAccessibilityLabel("Annotation text"); alert.accessoryView = field; alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty else { return nil }
        return field.stringValue
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        return handleCommand(event) || super.performKeyEquivalent(with: event)
    }
    private func handleCommand(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        switch key {
        case "z": command?(event.modifierFlags.contains(.shift) ? "redo" : "undo")
        case "c": command?("copy")
        case "s": command?(event.modifierFlags.contains(.shift) ? "saveAs" : "save")
        case "0": command?("fit")
        case "+", "=": command?("zoomIn")
        case "-": command?("zoomOut")
        default: return false
        }
        return true
    }
    override func keyDown(with event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if handleCommand(event) { return }
        if event.keyCode == 51 || event.keyCode == 117 { deleteSelection(); return }
        if event.keyCode == 53 { draft = nil; original = nil; anchor = nil; selectedID = nil; refresh(); return }
        if key == " " { spaceDown = true; return }
        if let choice = EditorTool.allCases.first(where: { $0.shortcut == key }) { toolChanged?(choice); return }
        super.keyDown(with: event)
    }
    override func keyUp(with event: NSEvent) { if event.keyCode == 49 { spaceDown = false; panAnchor = nil } else { super.keyUp(with: event) } }
    override func resignFirstResponder() -> Bool { spaceDown = false; panAnchor = nil; return super.resignFirstResponder() }
}
