import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    guard let context = CGContext(data: nil, width: 4000, height: 3000, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let image = context.makeImage() else { fatalError("Large fixture") }
    let controller = EditorController(image: image, savedURL: URL(fileURLWithPath: "/private/tmp/SnapForge-existing.png"))
    controller.show()
    let window = controller.window
    guard let content = window.contentView else { fatalError("Missing editor") }
    content.layoutSubtreeIfNeeded()
    precondition(content.bounds.width <= 980 && content.bounds.height <= 680, "Large images must not enlarge editor")
    precondition(controller.canvas.document.source.width == 4000 && controller.canvas.document.source.height == 3000, "Source dimensions must be retained")
    for stack in content.subviews.compactMap({ $0 as? NSStackView }) {
        precondition(stack.frame.minY >= 0 && stack.frame.maxY <= content.bounds.maxY, "Toolbar must remain visible")
    }
    window.setContentSize(NSSize(width: 760, height: 480))
    content.layoutSubtreeIfNeeded()
    controller.fit()
    precondition(controller.canvas.frame.width <= 760 && controller.canvas.frame.height <= 480, "Fit must constrain the canvas")
    var commands: [String] = []
    controller.canvas.command = { commands.append($0) }
    window.makeFirstResponder(controller.canvas)
    for (key, shift) in [("z", false), ("z", true), ("c", false), ("s", false), ("s", true), ("0", false), ("=", false), ("-", false)] {
        let flags: NSEvent.ModifierFlags = shift ? [.command, .shift] : [.command]
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: key, charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0) else { fatalError("Key event") }
        precondition(controller.canvas.performKeyEquivalent(with: event), "Canvas must handle editor command equivalents")
    }
    precondition(commands == ["undo", "redo", "copy", "save", "saveAs", "fit", "zoomIn", "zoomOut"], "Editor keys must route to the correct command")
    precondition(ScrollAutomation.point(in: CGRect(x: -1000, y: 200, width: 400, height: 300), mainDisplayHeight: 1000) == CGPoint(x: -800, y: 650), "Automatic scroll coordinates must convert multi-display AppKit origin")
    precondition(ScrollAutomation.step(for: 600) == 180 && ScrollAutomation.step(for: 2000) == 400, "Scroll steps must retain overlap and cap large moves")
    let selection = RegionSelector.Selection(image: image, pixelRect: CGRect(x: 100, y: 200, width: 4000, height: 3000), screenRect: CGRect(x: 100, y: 100, width: 600, height: 400), displayID: 1, displayPixelSize: CGSize(width: 5000, height: 4000))
    let scrolling = ScrollingCaptureController(selection: selection)
    var delivered: CGImage?
    scrolling.completed = { delivered = $0 }
    scrolling.show()
    guard let finish = scrolling.window.contentView?.subviews.compactMap({ $0 as? NSButton }).first(where: { $0.title == "Finish in Editor" }) else { fatalError("Missing scrolling finish") }
    precondition(finish.isEnabled, "Region selection must supply first frame immediately")
    _ = finish.target?.perform(finish.action, with: finish)
    precondition(delivered?.width == 4000 && delivered?.height == 3000, "Finish must deliver initial selected image without another capture")
    let pin = PinController(image: image)
    pin.show()
    precondition(pin.window.isVisible && pin.window.level == .floating && !pin.window.hidesOnDeactivate, "Pinned image must float and remain visible")
    precondition(pin.window.styleMask.contains(.resizable) && pin.window.styleMask.contains(.closable), "Pin must resize and close")
    if let slider = pin.window.contentView?.subviews.compactMap({ $0 as? NSSlider }).first {
        slider.doubleValue = 0.5
        _ = slider.target?.perform(slider.action, with: slider)
        precondition(pin.window.alphaValue == 0.5, "Opacity control must update pin")
    } else { fatalError("Missing opacity control") }
    pin.window.close()
    window.close()
    print("PASS: editor initial sizing, toolbar visibility, fit after resizing, original dimensions, keyboard command routing, pin visibility/opacity/resize controls, scrolling region first-frame delivery")
}
