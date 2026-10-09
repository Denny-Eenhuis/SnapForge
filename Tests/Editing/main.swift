import AppKit

struct CheckFailure: Error { let message: String }
func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    guard try value() else { throw CheckFailure(message: message) }
}
func fixture(width: Int = 160, height: Int = 120) throws -> CGImage {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let index = (y * width + x) * 4
            if y < 20 { bytes[index + 1] = 0; bytes[index + 2] = 0 }
            else if y >= height - 20 { bytes[index] = 0; bytes[index + 1] = 0 }
            else if x > 30 && x < 100 {
                let tone: UInt8 = (x + y) % 2 == 0 ? 0 : 255
                bytes[index] = tone; bytes[index + 1] = tone; bytes[index + 2] = tone
            }
        }
    }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData), let space = CGColorSpace(name: CGColorSpace.sRGB),
          let result = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { throw CheckFailure(message: "Fixture") }
    return result
}
func pixel(_ image: CGImage, _ x: Int, _ y: Int) throws -> [UInt8] {
    guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let data = context.data else { throw CheckFailure(message: "Pixel context") }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = data.assumingMemoryBound(to: UInt8.self)
    let offset = (y * image.width + x) * 4
    return (0..<4).map { bytes[offset + $0] }
}

func containsGreen(_ image: CGImage) throws -> Bool {
    guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let data = context.data else { throw CheckFailure(message: "Tool pixels") }
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = data.assumingMemoryBound(to: UInt8.self)
    return stride(from: 0, to: image.width * image.height * 4, by: 4).contains { bytes[$0 + 1] > 200 && bytes[$0] < 100 && bytes[$0 + 2] < 100 }
}

try MainActor.assumeIsolated {
    let image = try fixture()
    let doc = EditorDocument(image: image)
    let sourcePixel = try pixel(image, 0, 0)
    try check(sourcePixel == [255, 0, 0, 255], "Fixture top row")
    var state = doc.state
    let color = NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
    let annotation = Annotation(tool: .rectangle, start: CGPoint(x: 10, y: 10), end: CGPoint(x: 25, y: 35), color: color, thickness: 4)
    state.annotations.append(annotation)
    doc.commit(state)
    try check(doc.canUndo && doc.isDirty, "Drawing must create undo and dirty state")
    doc.undo(); try check(doc.state.annotations.isEmpty && !doc.isDirty, "Undo restores initial state")
    doc.redo(); try check(doc.state.annotations == [annotation], "Redo restores exact editable annotation")
    let rendered = try AnnotationRenderer.render(source: image, state: doc.state)
    let stroke = try pixel(rendered, 10, 12)
    try check(stroke[1] > 240 && stroke[0] < 10, "Shape must render at top-left pixel coordinates")
    let bottom = try pixel(rendered, 10, 110)
    try check(bottom == [0, 0, 255, 255], "Source must not flip vertically")
    let moved = annotation.moved(by: CGPoint(x: 8, y: -2))
    try check(moved.start == CGPoint(x: 18, y: 8) && moved.id == annotation.id, "Moving retains identity and translates coordinates")
    var cropState = doc.state; cropState.crop = CGRect(x: 8, y: 8, width: 60, height: 40)
    doc.commit(cropState)
    let cropped = try AnnotationRenderer.render(source: image, state: doc.state)
    try check(cropped.width == 60 && cropped.height == 40, "Crop must export exact dimensions")
    let croppedStroke = try pixel(cropped, 2, 4)
    try check(croppedStroke[1] > 240, "Crop must retain annotation alignment")
    doc.undo(); try check(doc.state.crop == nil, "Crop is undoable")
    doc.redo(); try check(doc.state.crop == cropState.crop, "Crop is redoable")
    doc.undo()
    var branch = doc.state; branch.annotations = [moved]; doc.commit(branch)
    try check(!doc.canRedo, "A new edit must invalidate redo history")
    doc.markSaved(to: URL(fileURLWithPath: "/private/tmp/test.png"), state: branch)
    try check(!doc.isDirty, "Saved state matches exported annotations")
    for effect in [EditorTool.blur, .pixelate] {
        let mask = Annotation(tool: effect, start: CGPoint(x: 40, y: 40), end: CGPoint(x: 80, y: 70), thickness: 4)
        let result = try AnnotationRenderer.render(source: image, state: EditorState(annotations: [mask]))
        let outside = try pixel(result, 5, 5)
        let inside = try pixel(result, 51, 50)
        let originalInside = try pixel(image, 51, 50)
        try check(outside == sourcePixel, "Redaction must not alter pixels outside its region")
        try check(inside != originalInside, "Redaction must change selected content")
    }
    // Every vector tool must render without an error, including text and callouts.
    for tool in [EditorTool.arrow, .rounded, .ellipse, .line, .freehand, .text, .callout] {
        let shape = Annotation(tool: tool, start: CGPoint(x: 110, y: 40), end: CGPoint(x: 150, y: 80), points: [CGPoint(x: 110, y: 40), CGPoint(x: 120, y: 50), CGPoint(x: 140, y: 60)], text: "Test", color: color, thickness: 4, fontSize: 16)
        let result = try AnnotationRenderer.render(source: image, state: EditorState(annotations: [shape]))
        try check(result.width == image.width, "Tool must retain image dimensions")
        try check(try containsGreen(result), "Each vector tool must draw its configured color")
    }
    var invalid = false
    do { _ = try AnnotationRenderer.render(source: image, state: EditorState(crop: CGRect(x: 200, y: 200, width: 2, height: 2))) }
    catch { invalid = true }
    try check(invalid, "Invalid crop must stop export")
    try check(try pixel(image, 0, 0) == sourcePixel, "Edits must leave source pixels unchanged")
}
print("PASS: annotation history, movement, dirty/saved state, crop alignment, redaction, vector tools, original pixels")
