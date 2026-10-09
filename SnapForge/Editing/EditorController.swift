import AppKit

@MainActor
final class EditorController: NSObject, NSWindowDelegate {
    let document: EditorDocument
    let canvas: AnnotationCanvas
    let window: NSWindow
    private let scroll = NSScrollView()
    private let status = NSTextField(labelWithString: "")
    private let colorWell = NSColorWell()
    private let widths = NSPopUpButton()
    private let fonts = NSPopUpButton()
    private let undoButton = NSButton(title: "Undo", target: nil, action: nil)
    private let redoButton = NSButton(title: "Redo", target: nil, action: nil)
    private var tools: [NSButton] = []
    private var exporting = false
    private var magnificationObserver: NSKeyValueObservation?
    var closed: (() -> Void)?

    init(image: CGImage, savedURL: URL?) {
        document = EditorDocument(image: image, savedURL: savedURL)
        canvas = AnnotationCanvas(document: document)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 680), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        super.init()
        window.title = "SnapForge — Editor"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentMinSize = NSSize(width: 760, height: 480)
        buildUI()
        magnificationObserver = scroll.observe(\.magnification, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.updateStatus() }
        }
        document.changed = { [weak self] in self?.canvas.refresh(); self?.updateStatus() }
        canvas.selectionChanged = { [weak self] in self?.selectionChanged() }
        canvas.toolChanged = { [weak self] in self?.chooseTool($0) }
        canvas.command = { [weak self] in self?.command($0) }
        canvas.reportError = { [weak self] in self?.showError($0) }
        let available = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size ?? NSSize(width: 1200, height: 800)
        window.setContentSize(NSSize(width: min(980, available.width * 0.9), height: min(680, available.height * 0.85)))
        window.center()
        chooseTool(.select)
        updateStatus()
    }
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
        fit()
    }
    private func buildUI() {
        let root = NSView()
        let upper = NSStackView()
        let lower = NSStackView()
        for (index, tool) in EditorTool.allCases.enumerated() {
            let button = NSButton(title: tool.rawValue, target: self, action: #selector(toolClicked(_:)))
            button.tag = index
            button.setButtonType(.toggle)
            button.toolTip = "\(tool.rawValue) (\(tool.shortcut.uppercased()))"
            button.setAccessibilityLabel(tool.rawValue + " annotation tool")
            tools.append(button)
            (index < 8 ? upper : lower).addArrangedSubview(button)
        }
        colorWell.color = canvas.color
        colorWell.target = self; colorWell.action = #selector(styleChanged)
        colorWell.setAccessibilityLabel("Annotation color")
        colorWell.widthAnchor.constraint(equalToConstant: 46).isActive = true
        for width in [2, 4, 6, 8, 12, 20] { widths.addItem(withTitle: "\(width) px"); widths.lastItem?.tag = width }
        widths.selectItem(withTag: 4); widths.target = self; widths.action = #selector(styleChanged); widths.setAccessibilityLabel("Line thickness")
        for size in [16, 20, 28, 36, 48, 64] { fonts.addItem(withTitle: "\(size) pt"); fonts.lastItem?.tag = size }
        fonts.selectItem(withTag: 28); fonts.target = self; fonts.action = #selector(styleChanged); fonts.setAccessibilityLabel("Text and callout size")
        [colorWell, widths, fonts].forEach { lower.addArrangedSubview($0) }
        undoButton.target = self; undoButton.action = #selector(undo)
        redoButton.target = self; redoButton.action = #selector(redo)
        lower.addArrangedSubview(undoButton); lower.addArrangedSubview(redoButton)
        scroll.hasVerticalScroller = true; scroll.hasHorizontalScroller = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = true; scroll.backgroundColor = .underPageBackgroundColor
        scroll.documentView = canvas
        scroll.allowsMagnification = true; scroll.minMagnification = 0.25; scroll.maxMagnification = 4
        let footer = NSStackView()
        status.lineBreakMode = .byTruncatingMiddle
        status.setContentCompressionResistancePriority(.init(1), for: .horizontal)
        status.toolTip = "Drag selected annotations to move; drag endpoint handles to resize. Double-click text to edit. Space-drag or scroll to pan."
        footer.addArrangedSubview(status)
        for (title, selector) in [("−", #selector(zoomOut)), ("+", #selector(zoomIn)), ("Fit", #selector(fit)), ("Reset Crop", #selector(resetCrop)), ("Copy", #selector(copyImage)), ("Save", #selector(save)), ("Save As…", #selector(saveAs))] {
            let button = NSButton(title: title, target: self, action: selector)
            button.setAccessibilityLabel(title == "−" ? "Zoom out" : title == "+" ? "Zoom in" : title)
            footer.addArrangedSubview(button)
        }
        for view in [upper, lower, scroll, footer] { root.addSubview(view); view.translatesAutoresizingMaskIntoConstraints = false }
        for stack in [upper, lower, footer] { stack.orientation = .horizontal; stack.spacing = 6 }
        NSLayoutConstraint.activate([
            upper.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12), upper.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            upper.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),
            lower.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12), lower.topAnchor.constraint(equalTo: upper.bottomAnchor, constant: 8),
            lower.trailingAnchor.constraint(lessThanOrEqualTo: root.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: lower.bottomAnchor, constant: 12), scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12), scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            footer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12), footer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            footer.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])
        window.contentView = root
    }
    @objc private func toolClicked(_ sender: NSButton) { chooseTool(EditorTool.allCases[sender.tag]) }
    func chooseTool(_ tool: EditorTool) {
        canvas.tool = tool
        for (index, button) in tools.enumerated() { button.state = EditorTool.allCases[index] == tool ? .on : .off }
        window.invalidateCursorRects(for: canvas)
        updateStatus()
    }
    private func selectionChanged() {
        guard let annotation = canvas.selected else { return }
        colorWell.color = annotation.color; widths.selectItem(withTag: Int(annotation.thickness)); fonts.selectItem(withTag: Int(annotation.fontSize))
        canvas.color = annotation.color; canvas.thickness = annotation.thickness; canvas.fontSize = annotation.fontSize
    }
    @objc private func styleChanged() {
        canvas.color = colorWell.color; canvas.thickness = CGFloat(widths.selectedItem?.tag ?? 4); canvas.fontSize = CGFloat(fonts.selectedItem?.tag ?? 28)
        canvas.applyStyle()
        window.makeFirstResponder(canvas)
    }
    @objc private func undo() { document.undo() }
    @objc private func redo() { document.redo() }
    @objc private func resetCrop() { var state = document.state; state.crop = nil; document.commit(state); fit() }
    @objc private func zoomIn() { setZoom(canvas.zoom * 1.25) }
    @objc private func zoomOut() { setZoom(canvas.zoom / 1.25) }
    @objc func fit() {
        scroll.magnification = 1
        let available = scroll.contentSize
        let image = document.visibleBounds.size
        setZoom(min(1, min(available.width / image.width, available.height / image.height)))
        canvas.scroll(.zero)
    }
    private func setZoom(_ value: CGFloat) { canvas.zoom = max(0.05, min(4, value)); canvas.resizeCanvas(); canvas.needsDisplay = true; updateStatus() }
    private func updateStatus() {
        let size = document.visibleBounds.size
        status.stringValue = "\(canvas.tool.rawValue) · \(Int(size.width)) × \(Int(size.height)) · \(Int(canvas.zoom * scroll.magnification * 100))%" + (document.isDirty ? " · Edited" : document.savedURL == nil ? "" : " · Saved")
        window.isDocumentEdited = document.isDirty
        undoButton.isEnabled = document.canUndo; redoButton.isEnabled = document.canRedo
    }
    private func command(_ name: String) {
        switch name {
        case "undo": undo()
        case "redo": redo()
        case "copy": copyImage()
        case "save": save()
        case "saveAs": saveAs()
        case "fit": fit()
        case "zoomIn": zoomIn()
        case "zoomOut": zoomOut()
        default: break
        }
    }
    @objc private func copyImage() {
        do { try ImageOutput.copy(AnnotationRenderer.render(source: document.source, state: document.state)) }
        catch { showError(error) }
    }
    @objc private func save() {
        guard let url = document.savedURL else { saveAs(); return }
        export(to: url, format: url.pathExtension.lowercased() == "png" ? .png : .jpeg)
    }
    @objc private func saveAs() {
        guard !exporting else { return }
        exporting = true
        let state = document.state
        let panel = NSSavePanel(); let format = Preferences.shared.format
        panel.allowedContentTypes = [format.contentType]
        panel.directoryURL = document.savedURL?.deletingLastPathComponent() ?? Preferences.shared.folder
        panel.nameFieldStringValue = ImageOutput.filename(format: format, savedURL: document.savedURL)
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.exporting = false
            guard response == .OK, let url = panel.url else { return }
            self.export(to: url, format: format, state: state)
        }
    }
    private func export(to url: URL, format: ImageFormat, state: EditorState? = nil) {
        let exportingState = state ?? document.state
        do {
            let result = try AnnotationRenderer.render(source: document.source, state: exportingState)
            try ImageOutput.save(result, format: format, to: url)
            document.markSaved(to: url, state: exportingState)
        } catch { showError(error) }
    }
    private func showError(_ error: Error) { NSAlert(error: error).beginSheetModal(for: window) }
    func windowWillClose(_ notification: Notification) { closed?() }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard document.isDirty else { return true }
        let alert = NSAlert(); alert.messageText = "Discard unsaved annotations?"; alert.informativeText = "Save your edited image before closing to keep the result."
        alert.addButton(withTitle: "Keep Editing"); alert.addButton(withTitle: "Discard")
        return alert.runModal() == .alertSecondButtonReturn
    }
}
