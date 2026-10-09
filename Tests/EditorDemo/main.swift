import AppKit

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let menu = NSMenu()
    let applicationMenu = NSMenu()
    applicationMenu.addItem(withTitle: "Quit Editor Check", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    let entry = NSMenuItem(); entry.submenu = applicationMenu; menu.addItem(entry); app.mainMenu = menu
    guard let context = CGContext(data: nil, width: 1200, height: 800, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError("Fixture allocation") }
    context.setFillColor(CGColor(gray: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
    for index in 0..<12 {
        context.setFillColor(CGColor(red: CGFloat(index) / 12, green: 0.35, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 80 + index * 80, y: 80, width: 60, height: 100))
    }
    guard let raw = context.makeImage() else { fatalError("Fixture") }
    let labels = [Annotation(tool: .text, start: CGPoint(x: 80, y: 60), end: .zero, text: "SnapForge annotation test", color: .black, fontSize: 44), Annotation(tool: .text, start: CGPoint(x: 80, y: 150), end: .zero, text: "Synthetic image — no Screen Recording permission needed", color: .darkGray, fontSize: 24)]
    guard let image = try? AnnotationRenderer.render(source: raw, state: EditorState(annotations: labels)) else { fatalError("Fixture labels") }
    let editor = EditorController(image: image, savedURL: nil)
    editor.show()
    withExtendedLifetime(editor) { app.run() }
}
