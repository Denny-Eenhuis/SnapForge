import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    guard let context = CGContext(data: nil, width: 4000, height: 3000, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let image = context.makeImage() else {
        fatalError("Cannot create large test image")
    }
    let controller = PreviewController()
    controller.show(image, savedURL: URL(fileURLWithPath: "/private/tmp/SnapForge-2026-10-09T16-43-29Z-15A938.png"))
    guard let window = app.windows.first(where: { $0.title == "SnapForge — Capture" }), let content = window.contentView else { fatalError("Preview missing") }
    content.layoutSubtreeIfNeeded()
    let size = content.bounds.size
    precondition(size.width <= 900 && size.height <= 600, "Large images must not enlarge the initial window")
    precondition(content.subviews.contains(where: { $0 is NSStackView && $0.frame.maxY <= content.bounds.maxY && $0.frame.minY >= 0 }), "Toolbar must fit inside preview")
    window.setContentSize(NSSize(width: 420, height: 320))
    content.layoutSubtreeIfNeeded()
    guard let imageView = content.subviews.first(where: { $0 is NSImageView }) else { fatalError("Image view missing") }
    precondition(imageView.frame.width <= 420 && imageView.frame.height <= 320, "Image must fit resized window")
    precondition((imageView as? NSImageView)?.image?.size == NSSize(width: 4000, height: 3000), "Preview must preserve source image dimensions")
    window.close()
    print("PASS: large-image window sizing, toolbar visibility, resizing, original image dimensions")
}
