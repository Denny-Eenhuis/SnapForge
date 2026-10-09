import AppKit

struct PixelSample: Equatable {
    let red: UInt8; let green: UInt8; let blue: UInt8
    var description: String { String(format: "#%02X%02X%02X · RGB %d, %d, %d", red, green, blue, red, green, blue) }
}
struct PixelBuffer {
    let width: Int; let height: Int; let bytes: [UInt8]
    init(_ image: CGImage) throws {
        let width = image.width, height = image.height
        self.width = width; self.height = height
        var storage = [UInt8](repeating: 0, count: width * height * 4)
        let success = storage.withUnsafeMutableBytes { data -> Bool in
            guard let context = CGContext(data: data.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height)); return true
        }
        guard success else { throw CocoaError(.coderInvalidValue) }
        bytes = storage
    }
    func sample(x: Int, y: Int) -> PixelSample? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let offset = (y * width + x) * 4
        let alpha = Int(bytes[offset + 3])
        func channel(_ index: Int) -> UInt8 { alpha == 0 ? 0 : UInt8(min(255, Int(bytes[offset + index]) * 255 / alpha)) }
        return PixelSample(red: channel(0), green: channel(1), blue: channel(2))
    }
}

@MainActor
private final class InspectionView: NSView {
    let image: NSImage
    let pixels: PixelBuffer
    var mode = "Distance"
    var result: ((String) -> Void)?
    private var start: CGPoint?
    private var end: CGPoint?
    override var isFlipped: Bool { true }
    init(image: CGImage) throws {
        pixels = try PixelBuffer(image)
        self.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        super.init(frame: .zero)
        setAccessibilityElement(true); setAccessibilityRole(.image); setAccessibilityLabel("Measurement canvas. Drag for distance or ruler; click for pixel color.")
    }
    required init?(coder: NSCoder) { nil }
    private var scale: CGFloat { min(bounds.width / CGFloat(pixels.width), bounds.height / CGFloat(pixels.height)) }
    private func point(_ event: NSEvent) -> CGPoint? {
        let p = convert(event.locationInWindow, from: nil)
        guard scale > 0 else { return nil }
        let mapped = CGPoint(x: p.x / scale, y: p.y / scale)
        guard mapped.x >= 0, mapped.y >= 0, mapped.x < CGFloat(pixels.width), mapped.y < CGFloat(pixels.height) else { return nil }
        return mapped
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.underPageBackgroundColor.setFill(); bounds.fill()
        image.draw(in: CGRect(x: 0, y: 0, width: CGFloat(pixels.width) * scale, height: CGFloat(pixels.height) * scale), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.none])
        guard let start, let end else { return }
        let a = CGPoint(x: start.x * scale, y: start.y * scale), b = CGPoint(x: end.x * scale, y: end.y * scale)
        let path = NSBezierPath(); path.move(to: a); path.line(to: b)
        path.lineWidth = 2; NSColor.systemYellow.setStroke(); path.stroke()
        if mode == "Pixel Ruler" {
            let length = hypot(end.x - start.x, end.y - start.y)
            let interval = max(10, ceil(20 / scale / 10) * 10)
            if length > 0 {
                let dx = (b.x - a.x) / length, dy = (b.y - a.y) / length
                for distance in stride(from: CGFloat(0), through: length, by: interval) {
                    let p = CGPoint(x: a.x + dx * distance, y: a.y + dy * distance)
                    let tick = NSBezierPath(); tick.move(to: CGPoint(x: p.x - dy / scale * 4, y: p.y + dx / scale * 4)); tick.line(to: CGPoint(x: p.x + dy / scale * 4, y: p.y - dx / scale * 4)); tick.stroke()
                }
            }
        }
    }
    override func mouseDown(with event: NSEvent) {
        guard let p = point(event) else { return }
        start = p; end = p
        if mode == "Color Picker", let sample = pixels.sample(x: Int(p.x), y: Int(p.y)) { result?("(\(Int(p.x)), \(Int(p.y))) · \(sample.description)") }
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard mode != "Color Picker", let start, let p = point(event) else { return }
        end = p
        result?(String(format: "Distance %.1f px · Δx %.1f · Δy %.1f", hypot(p.x - start.x, p.y - start.y), p.x - start.x, p.y - start.y))
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) { if mode != "Color Picker" { mouseDragged(with: event) } }
}

@MainActor
final class InspectionController: NSObject {
    let window: NSWindow
    private let view: InspectionView
    private let modes = NSPopUpButton()
    private let status = NSTextField(labelWithString: "Drag on the image to measure source pixels.")
    init(image: CGImage) throws {
        view = try InspectionView(image: image)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 650), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init(); window.title = "SnapForge — Measure & Color"; window.isReleasedWhenClosed = false
        let root = NSView(); window.contentView = root
        modes.addItems(withTitles: ["Distance", "Pixel Ruler", "Color Picker"]); modes.target = self; modes.action = #selector(modeChanged); modes.setAccessibilityLabel("Measurement mode")
        let copy = NSButton(title: "Copy Value", target: self, action: #selector(copyValue))
        for child in [modes, status, copy, view] { root.addSubview(child); child.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            modes.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12), modes.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            status.leadingAnchor.constraint(equalTo: modes.trailingAnchor, constant: 12), status.centerYAnchor.constraint(equalTo: modes.centerYAnchor),
            copy.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12), copy.centerYAnchor.constraint(equalTo: modes.centerYAnchor), status.trailingAnchor.constraint(lessThanOrEqualTo: copy.leadingAnchor, constant: -12),
            view.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12), view.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12), view.topAnchor.constraint(equalTo: modes.bottomAnchor, constant: 12), view.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12)
        ])
        view.result = { [weak self] in self?.status.stringValue = $0 }
        window.center()
    }
    func show() { window.makeKeyAndOrderFront(nil) }
    @objc private func modeChanged() { view.mode = modes.titleOfSelectedItem ?? "Distance"; status.stringValue = view.mode == "Color Picker" ? "Click a pixel to read its sRGB color." : "Drag to measure source pixels."; view.needsDisplay = true }
    @objc private func copyValue() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(status.stringValue, forType: .string) }
}

@MainActor
final class PinController: NSObject {
    let window: NSPanel
    private let imageView = NSImageView()
    init(image: CGImage) {
        let ratio = CGFloat(image.width) / CGFloat(image.height)
        let width = min(600, CGFloat(image.width)); let height = min(500, width / ratio)
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height + 40), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        super.init(); window.title = "SnapForge — Pinned"; window.isReleasedWhenClosed = false
        window.level = .floating; window.hidesOnDeactivate = false; window.isFloatingPanel = true
        let root = NSView(); window.contentView = root
        imageView.image = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)); imageView.imageScaling = .scaleProportionallyUpOrDown; imageView.setAccessibilityLabel("Pinned screenshot")
        let label = NSTextField(labelWithString: "Opacity")
        let slider = NSSlider(value: 1, minValue: 0.2, maxValue: 1, target: self, action: #selector(opacity(_:))); slider.setAccessibilityLabel("Pinned screenshot opacity")
        for child in [imageView, label, slider] { root.addSubview(child); child.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12), label.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            slider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 10), slider.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12), slider.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            imageView.leadingAnchor.constraint(equalTo: root.leadingAnchor), imageView.trailingAnchor.constraint(equalTo: root.trailingAnchor), imageView.topAnchor.constraint(equalTo: root.topAnchor), imageView.bottomAnchor.constraint(equalTo: label.topAnchor, constant: -8)
        ])
        window.center()
    }
    func show() { window.makeKeyAndOrderFront(nil) }
    @objc private func opacity(_ sender: NSSlider) { window.alphaValue = sender.doubleValue }
}
