import AppKit

struct ScrollStitcher {
    enum StitchError: LocalizedError {
        case dimensions, overlap, unchanged, tooLarge, allocation
        var errorDescription: String? {
            switch self {
            case .dimensions: return "Frame dimensions changed. Keep the window and viewport unchanged."
            case .overlap: return "No reliable overlap found. Scroll less, wait for loading to finish, and exclude fixed headers or footers. Repetitive or animated content may not stitch reliably."
            case .unchanged: return "The viewport has not moved enough. Scroll down before adding a frame."
            case .tooLarge: return "The scrolling image reached the 80 megapixel or 30,000 pixel height limit. Finish this image and start another."
            case .allocation: return "The scrolling image could not be allocated."
            }
        }
    }
    static func overlap(previous: CGImage, next: CGImage) throws -> Int {
        guard previous.width == next.width, previous.height == next.height, previous.height >= 40 else { throw StitchError.dimensions }
        let a = try PixelBuffer(previous), b = try PixelBuffer(next)
        let width = previous.width, height = previous.height
        // Compare interior columns to avoid window borders; sample up to 48 columns.
        let stepX = max(1, width / 48)
        func error(shift: Int, stepY: Int) -> Double {
            var total = 0.0; var count = 0
            for y in stride(from: 0, to: height - shift, by: stepY) {
                for x in stride(from: max(0, width / 20), to: max(1, width - width / 20), by: stepX) {
                    let i = ((y + shift) * width + x) * 4, j = (y * width + x) * 4
                    for c in 0..<3 { total += Double(abs(Int(a.bytes[i+c]) - Int(b.bytes[j+c]))); count += 1 }
                }
            }
            return count == 0 ? 255 : total / Double(count)
        }
        if error(shift: 0, stepY: max(1, height / 80)) < 0.5 { throw StitchError.unchanged }
        let minimum = max(8, height / 50), maximum = height * 4 / 5
        let coarse = 1 // Search each pixel shift: detailed images need exact alignment.
        var candidates: [(Int, Double)] = []
        for shift in stride(from: minimum, through: maximum, by: coarse) { candidates.append((shift, error(shift: shift, stepY: max(1, height / 80)))) }
        let seeds = candidates.sorted { $0.1 < $1.1 }.prefix(8)
        var refined: [Int: Double] = [:]
        for seed in seeds { for shift in max(minimum, seed.0 - coarse)...min(maximum, seed.0 + coarse) { refined[shift] = error(shift: shift, stepY: max(1, height / 160)) } }
        let ranked = refined.sorted { $0.value < $1.value }
        guard let best = ranked.first, best.value < 6 else { throw StitchError.overlap }
        // Reject ambiguous repeated patterns; a distinct distant match must be worse.
        if let alternative = ranked.first(where: { abs($0.key - best.key) > max(8, height / 100) }), alternative.value < best.value + 1 { throw StitchError.overlap }
        return height - best.key
    }
    static func append(composite: CGImage, previous: CGImage, next: CGImage) throws -> CGImage {
        let common = try overlap(previous: previous, next: next)
        let added = next.height - common, height = composite.height + added
        guard composite.width == next.width else { throw StitchError.dimensions }
        guard height <= 30_000, composite.width * height <= 80_000_000 else { throw StitchError.tooLarge }
        guard let tail = next.cropping(to: CGRect(x: 0, y: common, width: next.width, height: added)),
              let context = CGContext(data: nil, width: next.width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw StitchError.allocation }
        context.draw(composite, in: CGRect(x: 0, y: added, width: composite.width, height: composite.height))
        context.draw(tail, in: CGRect(x: 0, y: 0, width: tail.width, height: added))
        guard let result = context.makeImage() else { throw StitchError.allocation }
        return result
    }
}

@MainActor
final class ScrollingCaptureController: NSObject {
    let window: NSWindow
    private let selection: RegionSelector.Selection
    private let capture = CaptureService()
    private var previous: CGImage
    private var composite: CGImage
    private var busy = false
    private let status = NSTextField(wrappingLabelWithString: "")
    private let add = NSButton(title: "Add Frame After Scrolling", target: nil, action: nil)
    private let finish = NSButton(title: "Finish in Editor", target: nil, action: nil)
    var completed: ((CGImage) -> Void)?
    init(selection: RegionSelector.Selection) {
        self.selection = selection
        previous = selection.image; composite = selection.image
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 210), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(); window.title = "SnapForge — Scrolling Region"; window.isReleasedWhenClosed = false
        let root = NSStackView(); root.orientation = .vertical; root.spacing = 12; root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        add.target = self; add.action = #selector(addFrame); finish.target = self; finish.action = #selector(done)
        for child in [status, add, finish] { root.addArrangedSubview(child) }
        status.widthAnchor.constraint(equalToConstant: 428).isActive = true
        window.contentView = root
        updateStatus()
        positionOutsideRegion()
    }
    func show() { window.makeKeyAndOrderFront(nil) }
    private func positionOutsideRegion() {
        let screen = NSScreen.screens.first { $0.frame.intersects(selection.screenRect) }
        let available = screen?.visibleFrame ?? selection.screenRect
        let size = window.frame.size, region = selection.screenRect
        let origins = [CGPoint(x: region.maxX + 12, y: region.maxY - size.height),
                       CGPoint(x: region.minX - size.width - 12, y: region.maxY - size.height),
                       CGPoint(x: region.minX, y: region.minY - size.height - 12),
                       CGPoint(x: region.minX, y: region.maxY + 12)]
        if let origin = origins.first(where: { available.contains(CGRect(origin: $0, size: size)) }) { window.setFrameOrigin(origin) }
        else { window.center() }
    }
    private func updateStatus() {
        status.stringValue = "Captured · \(composite.width) × \(composite.height) pixels. Scroll the content inside your selected region down by less than half its height, then add a frame. Keep the region, window position and zoom fixed. Avoid sticky headers and animated content."
    }
    @objc private func addFrame() {
        guard !busy, let id = selection.displayID else { return }
        busy = true; add.isEnabled = false; finish.isEnabled = false
        window.orderOut(nil)
        Task {
            defer { busy = false; add.isEnabled = true; finish.isEnabled = true; window.makeKeyAndOrderFront(nil) }
            do {
                try await Task.sleep(for: .milliseconds(300))
                let image = try await capture.captureDisplay(id)
                guard image.width == Int(selection.displayPixelSize.width), image.height == Int(selection.displayPixelSize.height),
                      let frame = image.cropping(to: selection.pixelRect) else { throw ScrollStitcher.StitchError.dimensions }
                let oldComposite = composite, oldFrame = previous
                let result = try await Task.detached(priority: .userInitiated) {
                    try ScrollStitcher.append(composite: oldComposite, previous: oldFrame, next: frame)
                }.value
                composite = result; previous = frame
                updateStatus()
            } catch { status.stringValue = error.localizedDescription }
        }
    }
    @objc private func done() { guard !busy else { return }; completed?(composite); window.close() }
}
