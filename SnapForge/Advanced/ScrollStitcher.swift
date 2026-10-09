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
final class ScrollingCaptureController: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let windowID: CGWindowID
    private let capture = CaptureService()
    private var previous: CGImage?
    private var composite: CGImage?
    private var busy = false
    private let top = NSTextField(string: "0"), bottom = NSTextField(string: "0")
    private let status = NSTextField(wrappingLabelWithString: "Set fixed header/footer exclusions in image pixels. Capture the first frame, scroll the target window down by less than half a viewport, then add a frame. Keep its size unchanged. No automatic scrolling or Accessibility permission is required.")
    private let add = NSButton(title: "Capture First Frame", target: nil, action: nil)
    private let finish = NSButton(title: "Finish in Editor", target: nil, action: nil)
    var completed: ((CGImage) -> Void)?
    init(windowID: CGWindowID) {
        self.windowID = windowID
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 250), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(); window.title = "SnapForge — Scrolling Capture"; window.isReleasedWhenClosed = false; window.delegate = self
        let root = NSStackView(); root.orientation = .vertical; root.spacing = 12; root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let row = NSStackView(views: [NSTextField(labelWithString: "Exclude top px"), top, NSTextField(labelWithString: "Bottom px"), bottom]); row.spacing = 8
        top.setAccessibilityLabel("Exclude top pixels"); bottom.setAccessibilityLabel("Exclude bottom pixels")
        top.widthAnchor.constraint(equalToConstant: 60).isActive = true; bottom.widthAnchor.constraint(equalToConstant: 60).isActive = true
        add.target = self; add.action = #selector(addFrame); finish.target = self; finish.action = #selector(done); finish.isEnabled = false
        for child in [status, row, add, finish] { root.addArrangedSubview(child) }
        status.widthAnchor.constraint(equalToConstant: 440).isActive = true
        window.contentView = root; window.center()
    }
    func show() { window.makeKeyAndOrderFront(nil) }
    @objc private func addFrame() {
        guard !busy else { return }
        guard let upper = Int(top.stringValue), let lower = Int(bottom.stringValue), upper >= 0, lower >= 0 else { report("Enter nonnegative whole pixel exclusions."); return }
        busy = true; add.isEnabled = false; finish.isEnabled = false
        window.orderOut(nil)
        Task {
            defer { busy = false; add.isEnabled = true; finish.isEnabled = composite != nil; window.makeKeyAndOrderFront(nil) }
            do {
                try await Task.sleep(for: .milliseconds(300))
                let image = try await capture.captureWindow(windowID)
                guard upper + lower < image.height - 40, let frame = image.cropping(to: CGRect(x: 0, y: upper, width: image.width, height: image.height - upper - lower)) else { throw ScrollStitcher.StitchError.dimensions }
                let oldComposite = composite, oldFrame = previous
                let result = try await Task.detached(priority: .userInitiated) {
                    if let oldComposite, let oldFrame { return try ScrollStitcher.append(composite: oldComposite, previous: oldFrame, next: frame) }
                    return frame
                }.value
                composite = result; previous = frame
                top.isEnabled = false; bottom.isEnabled = false
                add.title = "Add Frame After Scrolling"
                status.stringValue = "\(result.width) × \(result.height) pixels. Scroll down less than half a viewport, wait for content to settle, then add a frame. Fixed overlays, animations, repeated rows, horizontal motion and changing zoom can prevent stitching."
            } catch { report(error.localizedDescription) }
        }
    }
    @objc private func done() { guard !busy, let composite else { return }; completed?(composite); window.close() }
    private func report(_ message: String) { status.stringValue = message }
}
