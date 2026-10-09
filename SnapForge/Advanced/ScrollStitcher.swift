import AppKit
import ApplicationServices

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
    // A chat viewport can include stationary title/composer bands. Only infer a
    // narrower viewport when its moving portion has a independently valid match.
    static func movingCrop(previous: CGImage, next: CGImage) throws -> CGRect {
        guard previous.width == next.width, previous.height == next.height else { throw StitchError.dimensions }
        let a = try PixelBuffer(previous), b = try PixelBuffer(next)
        let width = previous.width, height = previous.height
        let step = max(1, width / 64)
        func changed(_ y: Int) -> Bool {
            var difference = 0, count = 0
            for x in stride(from: max(0, width / 20), to: max(1, width - width / 20), by: step) {
                let i = (y * width + x) * 4
                for c in 0..<3 { difference += abs(Int(a.bytes[i+c]) - Int(b.bytes[i+c])); count += 1 }
            }
            return count > 0 && Double(difference) / Double(count) > 0.8
        }
        guard let first = (0..<height).first(where: changed), let last = (0..<height).last(where: changed) else { throw StitchError.unchanged }
        let rect = CGRect(x: 0, y: first, width: width, height: last - first + 1)
        guard rect.height >= 80, rect.height >= CGFloat(height) * 0.4, rect.height < CGFloat(height),
              let before = previous.cropping(to: rect), let after = next.cropping(to: rect) else { throw StitchError.overlap }
        _ = try overlap(previous: before, next: after)
        return rect
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
final class ScrollingCaptureController: NSObject, AdvancedWindowClosing {
    let window: NSWindow
    private let selection: RegionSelector.Selection
    private let capture = CaptureService()
    private var previous: CGImage
    private var composite: CGImage
    private var busy = false
    private var contentCrop: CGRect?
    private var automaticTask: Task<Void, Never>?
    private var escapeMonitor: Any?
    private var localEscapeMonitor: Any?
    private var closed = false
    private let automatic = NSButton(title: "Start Automatic Scrolling", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private let add = NSButton(title: "Add Frame After Scrolling", target: nil, action: nil)
    private let finish = NSButton(title: "Finish in Editor", target: nil, action: nil)
    var completed: ((CGImage) -> Void)?
    init(selection: RegionSelector.Selection) {
        self.selection = selection
        previous = selection.image; composite = selection.image
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 250), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(); window.title = "SnapForge — Scrolling Region"; window.isReleasedWhenClosed = false
        let root = NSStackView(); root.orientation = .vertical; root.spacing = 12; root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        add.target = self; add.action = #selector(addFrame); finish.target = self; finish.action = #selector(done)
        automatic.target = self; automatic.action = #selector(startAutomatic)
        for child in [status, automatic, add, finish] { root.addArrangedSubview(child) }
        status.widthAnchor.constraint(equalToConstant: 428).isActive = true
        window.contentView = root
        updateStatus()
        positionOutsideRegion()
    }
    func show(automaticallyStart: Bool = false) {
        window.makeKeyAndOrderFront(nil)
        if automaticallyStart { startAutomatic() }
    }
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
        status.stringValue = "Captured · \(composite.width) × \(composite.height) pixels. Automatic scrolling moves slowly through this region. Escape stops it. You can restart or add frames manually. Keep the target visible."
    }
    @objc private func addFrame() {
        guard !busy, automaticTask == nil, let id = selection.displayID else { return }
        busy = true; add.isEnabled = false; finish.isEnabled = false
        window.orderOut(nil)
        Task {
            defer { busy = false; add.isEnabled = true; finish.isEnabled = true; if !closed { window.makeKeyAndOrderFront(nil) } }
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
    @objc private func done() { guard !busy, automaticTask == nil else { return }; completed?(composite); window.close() }
    @objc private func startAutomatic() {
        guard !busy, automaticTask == nil, let displayID = selection.displayID else { return }
        guard AXIsProcessTrusted() else {
            let alert = NSAlert()
            alert.messageText = "Allow SnapForge to scroll?"
            alert.informativeText = "Automatic scrolling needs Accessibility access. Enable SnapForge in System Settings → Privacy & Security → Accessibility, then return and start again. Screen Recording is still required to capture. Manual scrolling remains available."
            alert.addButton(withTitle: "Open Accessibility Settings"); alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
            return
        }
        let mainHeight = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == CGMainDisplayID() })?.frame.height ?? CGFloat(CGDisplayBounds(CGMainDisplayID()).height)
        let point = ScrollAutomation.point(in: selection.screenRect, mainDisplayHeight: mainHeight)
        let cursor = NSEvent.mouseLocation
        let originalPointer = CGPoint(x: cursor.x, y: mainHeight - cursor.y)
        // Identify the visible target before hiding this utility. Never send scrolls
        // to a different app after the user changes focus.
        window.orderOut(nil)
        let target = ScrollAutomation.target(at: point)
        guard let target else { status.stringValue = "No target window was found beneath the selected region."; window.makeKeyAndOrderFront(nil); return }
        target.activate(options: [])
        automatic.isEnabled = false; add.isEnabled = false; finish.isEnabled = false
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { Task { @MainActor in self?.automaticTask?.cancel() } }
        }
        localEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.automaticTask?.cancel(); return nil }; return event
        }
        window.orderOut(nil)
        automaticTask = Task {
            var unchangedAttempts = 0
            var endMessage = "Automatic capture stopped. Finish to open the captured image."
            defer {
                automaticTask = nil
                removeMonitors()
                let cursor = NSEvent.mouseLocation
                let currentPointer = CGPoint(x: cursor.x, y: mainHeight - cursor.y)
                if hypot(currentPointer.x - point.x, currentPointer.y - point.y) < 3 { ScrollAutomation.positionPointer(at: originalPointer) }
                automatic.isEnabled = true; add.isEnabled = true; finish.isEnabled = true
                status.stringValue = "\(composite.width) × \(composite.height) pixels. " + (contentCrop == nil ? "" : "Fixed top/bottom areas excluded. ") + endMessage
                if !closed { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
            }
            do {
                try await Task.sleep(for: .milliseconds(1200))
                // Refresh the baseline after bringing the target forward.
                let baseline = try await regionFrame(displayID)
                if composite.height == previous.height {
                    // The selection snapshot can be stale after ChatGPT activation
                    // or a newly received message. Begin with the live viewport;
                    // don't mistake that UI change for the first scrolling frame.
                    previous = baseline; composite = baseline
                } else {
                    do {
                        let before = previous, joined = composite
                        let result = try await Task.detached(priority: .userInitiated) { try ScrollStitcher.append(composite: joined, previous: before, next: baseline) }.value
                        try Task.checkCancellation()
                        composite = result; previous = baseline
                    } catch ScrollStitcher.StitchError.unchanged { /* Baseline is already represented. */ }
                }
                ScrollAutomation.positionPointer(at: point)
                try await Task.sleep(for: .milliseconds(100))
                for _ in 0..<40 {
                    try Task.checkCancellation()
                    guard !target.isTerminated, NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
                        endMessage = "Stopped because the target app changed. Keep it visible and start again."; return
                    }
                    guard ScrollAutomation.target(at: point)?.processIdentifier == target.processIdentifier else {
                        endMessage = "Stopped because another window covers the region."; return
                    }
                    let movingHeight = selection.screenRect.height * (contentCrop?.height ?? selection.pixelRect.height) / selection.pixelRect.height
                    try await ScrollAutomation.scrollSlowly(at: point, points: ScrollAutomation.step(for: movingHeight))
                    try await Task.sleep(for: .milliseconds(1200))
                    let frame = try await regionFrame(displayID)
                    let before = previous, joined = composite
                    do {
                        let result = try await Task.detached(priority: .userInitiated) { try ScrollStitcher.append(composite: joined, previous: before, next: frame) }.value
                        try Task.checkCancellation()
                        composite = result; previous = frame; unchangedAttempts = 0
                    } catch ScrollStitcher.StitchError.overlap where contentCrop == nil && composite.height == previous.height {
                        let trimmed = try await Task.detached(priority: .userInitiated) {
                            let crop = try ScrollStitcher.movingCrop(previous: before, next: frame)
                            guard let a = before.cropping(to: crop), let b = frame.cropping(to: crop) else { throw ScrollStitcher.StitchError.overlap }
                            return (crop, b, try ScrollStitcher.append(composite: a, previous: a, next: b))
                        }.value
                        try Task.checkCancellation()
                        contentCrop = trimmed.0; previous = trimmed.1; composite = trimmed.2; unchangedAttempts = 0
                    } catch ScrollStitcher.StitchError.unchanged {
                        unchangedAttempts += 1
                        if unchangedAttempts < 3 { continue }
                        endMessage = composite.height == previous.height
                            ? "The selected area did not scroll. Select the conversation content and start above its bottom, then retry."
                            : "Reached the end of scrolling. Finish to open the captured image."
                        return
                    }
                }
                endMessage = "Reached the 40-frame limit. Finish this capture before starting another."
            } catch is CancellationError {
                endMessage = "Stopped with Escape. Finish to open the captured image."
            } catch { endMessage = error.localizedDescription }
        }
    }
    private func regionFrame(_ displayID: CGDirectDisplayID) async throws -> CGImage {
        let image = try await capture.captureDisplay(displayID)
        guard image.width == Int(selection.displayPixelSize.width), image.height == Int(selection.displayPixelSize.height),
              let result = image.cropping(to: selection.pixelRect) else { throw ScrollStitcher.StitchError.dimensions }
        if let contentCrop {
            guard let cropped = result.cropping(to: contentCrop) else { throw ScrollStitcher.StitchError.dimensions }
            return cropped
        }
        return result
    }
    private func removeMonitors() {
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor); self.escapeMonitor = nil }
        if let localEscapeMonitor { NSEvent.removeMonitor(localEscapeMonitor); self.localEscapeMonitor = nil }
    }
    func advancedWindowWillClose() { closed = true; automaticTask?.cancel(); removeMonitors() }
}

// Production event delivery follows the user's scrolling-region selection, after
// the normal macOS Accessibility grant. Unit checks exercise geometry only.
@MainActor
enum ScrollAutomation {
    static func point(in region: CGRect, mainDisplayHeight: CGFloat) -> CGPoint {
        CGPoint(x: region.midX, y: mainDisplayHeight - region.midY)
    }
    static func step(for height: CGFloat) -> Int32 { Int32(max(1, min(160, height * 0.20))) }
    static func scrollSlowly(at point: CGPoint, points: Int32) async throws {
        // Spread each move over 600 ms so the user can see the target scrolling.
        let count: Int32 = 12
        for index in 0..<count {
            try Task.checkCancellation()
            let amount = (points * (index + 1) / count) - (points * index / count)
            if amount > 0 { try scroll(at: point, points: amount) }
            try await Task.sleep(for: .milliseconds(50))
        }
    }
    static func target(at point: CGPoint) -> NSRunningApplication? {
        guard let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in windows {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = window[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.contains(point) else { continue }
            guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }
            return NSRunningApplication(processIdentifier: pid)
        }
        return nil
    }
    static func positionPointer(at point: CGPoint) {
        // NSScrollView/WKWebView routing depends on the actual hovered view.
        // Merely assigning a scroll event's location can leave it over SnapForge.
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }
    static func scroll(at point: CGPoint, points: Int32) throws {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -points, wheel2: 0, wheel3: 0) else { throw CocoaError(.coderInvalidValue) }
        event.location = point
        event.post(tap: .cghidEventTap)
    }
}
