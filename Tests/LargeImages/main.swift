import AppKit
import ImageIO

try MainActor.assumeIsolated {
    let width = 6000, height = 4000
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.coderInvalidValue) }
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 1000, height: height))
    guard let source = context.makeImage() else { throw CocoaError(.coderInvalidValue) }
    let state = EditorState(annotations: [Annotation(tool: .rectangle, start: CGPoint(x: 1200, y: 100), end: CGPoint(x: 5800, y: 3800), thickness: 20)])
    let rendered = try AnnotationRenderer.render(source: source, state: state)
    precondition(rendered.width == width && rendered.height == height)
    for format in ImageFormat.allCases {
        try autoreleasepool {
            let bytes = try ImageOutput.data(rendered, format: format)
            guard let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                  let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw CocoaError(.coderInvalidValue) }
            precondition(decoded.width == width && decoded.height == height, "24MP export must preserve dimensions")
            print("PASS: 24MP annotated \(format.rawValue) round-trip, \(bytes.count) encoded bytes")
        }
    }
    let cropped = try AnnotationRenderer.render(source: source, state: EditorState(annotations: state.annotations, crop: CGRect(x: 1000, y: 1000, width: 4000, height: 2000)))
    precondition(cropped.width == 4000 && cropped.height == 2000)
    precondition(source.width == width && source.height == height, "Original dimensions must remain immutable")
    print("PASS: 24MP annotation render, crop and original preservation")
}
