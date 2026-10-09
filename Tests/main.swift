import AppKit
import ImageIO

struct TestFailure: Error { let message: String }
func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw TestFailure(message: message) }
}

func testGeometry() throws {
    let crop = CaptureGeometry.pixelCrop(selection: CGRect(x: 10, y: 20, width: 30, height: 40), viewSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 200, height: 200))
    try expect(crop == CGRect(x: 20, y: 80, width: 60, height: 80), "Retina crop must flip Y and scale both axes")
    let clipped = CaptureGeometry.pixelCrop(selection: CGRect(x: -10, y: 80, width: 30, height: 40), viewSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 100, height: 100))
    try expect(clipped == CGRect(x: 0, y: 0, width: 20, height: 20), "Out-of-bounds selection must clip to display")
    let reversed = CaptureGeometry.pixelCrop(selection: CGRect(x: 40, y: 60, width: -30, height: -40), viewSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 200, height: 200))
    try expect(reversed == crop, "Reverse drag must produce identical crop")
    try expect(CaptureGeometry.pixelCrop(selection: .zero, viewSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 200, height: 200)) == nil, "Empty selection must be rejected")
    let nonuniform = CaptureGeometry.pixelCrop(selection: CGRect(x: 0, y: 0, width: 100, height: 50), viewSize: CGSize(width: 100, height: 100), imageSize: CGSize(width: 300, height: 200))
    try expect(nonuniform == CGRect(x: 0, y: 100, width: 300, height: 100), "Independent axes must use actual pixel dimensions")
}

func testEncoding() throws {
    guard let context = CGContext(data: nil, width: 32, height: 24, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw TestFailure(message: "Create context") }
    guard let red = CGColor(colorSpace: context.colorSpace ?? CGColorSpaceCreateDeviceRGB(), components: [1, 0, 0, 1]) else { throw TestFailure(message: "Red fixture") }
    context.setFillColor(red)
    context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
    guard let image = context.makeImage() else { throw TestFailure(message: "Create image") }
    for format in ImageFormat.allCases {
        let data = try ImageOutput.data(image, format: format)
        guard let decoded = NSBitmapImageRep(data: data) else { throw TestFailure(message: "Decode \(format)") }
        try expect(decoded.pixelsWide == 32 && decoded.pixelsHigh == 24, "Export must retain pixel dimensions")
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let roundTrip = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let pixels = CGContext(data: nil, width: 32, height: 24, bitsPerComponent: 8, bytesPerRow: 32 * 4,
                                     space: context.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let originalData = context.data, let decodedData = pixels.data else { throw TestFailure(message: "Decode pixels") }
        pixels.draw(roundTrip, in: CGRect(x: 0, y: 0, width: 32, height: 24))
        let original = originalData.assumingMemoryBound(to: UInt8.self)
        let restored = decodedData.assumingMemoryBound(to: UInt8.self)
        for channel in 0..<4 {
            try expect(abs(Int(original[channel]) - Int(restored[channel])) <= (format == .png ? 0 : 3), "Export must retain pixel channel \(channel)")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(format.rawValue)
        defer { try? FileManager.default.removeItem(at: url) }
        try ImageOutput.save(image, format: format, to: url)
        let saved = try Data(contentsOf: url)
        try expect(saved == data, "Saved bytes must match encoded data")
    }
    var rejected = false
    do { try ImageOutput.save(image, format: .png, to: URL(fileURLWithPath: "/private/tmp/\(UUID().uuidString)/absent/file.png")) }
    catch { rejected = true }
    try expect(rejected, "Missing output folder must throw")
}

try testGeometry()
try testEncoding()
try MainActor.assumeIsolated {
    let suite = "SnapForgeTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else { throw TestFailure(message: "Defaults suite") }
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = Preferences(defaults: defaults)
    try expect(first.copyAutomatically && first.showPreview && !first.autoSave, "Safe initial output preferences")
    first.format = .jpeg
    first.showPreview = false
    first.folder = URL(fileURLWithPath: "/private/tmp")
    first.regionKey = "r"
    let restored = Preferences(defaults: defaults)
    try expect(restored.format == .jpeg && !restored.showPreview && restored.folder?.path == "/private/tmp" && restored.regionKey == "r", "Preferences must persist across instances")
}
print("PASS: crop geometry, Retina scaling, PNG/JPEG round-trip, output failure, preferences persistence")
