import AppKit

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fputs("FAIL: \(message)\n", stderr); exit(1) }
}
func fixture(width: Int, height: Int) -> CGImage {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    var value: UInt32 = 1234567
    for y in 0..<height { for x in 0..<width {
        value = value &* 1664525 &+ 1013904223
        let i = (y * width + x) * 4
        bytes[i] = UInt8(truncatingIfNeeded: value >> 16); bytes[i+1] = UInt8(truncatingIfNeeded: value >> 8); bytes[i+2] = UInt8(truncatingIfNeeded: value)
    } }
    guard let provider = CGDataProvider(data: Data(bytes) as CFData), let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { fatalError("Fixture allocation") }
    return image
}
let colorBytes: [UInt8] = [255, 0, 0, 255, 0, 0, 255, 255]
guard let colorProvider = CGDataProvider(data: Data(colorBytes) as CFData), let colorImage = CGImage(width: 1, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue), provider: colorProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { fatalError("Color fixture") }
let colors = try PixelBuffer(colorImage)
check(colors.sample(x: 0, y: 0) == PixelSample(red: 255, green: 0, blue: 0), "top-left pixel orientation")
check(colors.sample(x: 0, y: 1) == PixelSample(red: 0, green: 0, blue: 255), "bottom pixel orientation")
check(colors.sample(x: 0, y: 0)?.description == "#FF0000 · RGB 255, 0, 0", "HEX/RGB formatting")
let full = fixture(width: 180, height: 600)
guard let first = full.cropping(to: CGRect(x: 0, y: 0, width: 180, height: 300)), let second = full.cropping(to: CGRect(x: 0, y: 130, width: 180, height: 300)), let third = full.cropping(to: CGRect(x: 0, y: 260, width: 180, height: 300)) else { fatalError("Fixture crop") }
let overlap = try ScrollStitcher.overlap(previous: first, next: second)
check(overlap == 170, "known vertical overlap")
let two = try ScrollStitcher.append(composite: first, previous: first, next: second)
let three = try ScrollStitcher.append(composite: two, previous: second, next: third)
check(three.width == 180 && three.height == 560, "multi-frame output dimensions")
let actual = try PixelBuffer(three), expected = try PixelBuffer(full)
for y in [0, 129, 299, 300, 429, 430, 559] { for x in [0, 90, 179] { check(actual.sample(x: x, y: y) == expected.sample(x: x, y: y), "seam and source pixel preservation \(x),\(y)") } }
check(expected.sample(x: -1, y: 0) == nil && expected.sample(x: 180, y: 0) == nil, "color bounds")
do { _ = try ScrollStitcher.overlap(previous: first, next: first); fatalError("Unchanged should reject") } catch ScrollStitcher.StitchError.unchanged {} catch { throw error }
do { _ = try ScrollStitcher.overlap(previous: first, next: fixture(width: 180, height: 301)); fatalError("Dimensions should reject") } catch ScrollStitcher.StitchError.dimensions {} catch { throw error }
let unrelated = fixture(width: 180, height: 600).cropping(to: CGRect(x: 0, y: 300, width: 180, height: 300))
if let unrelated { do { _ = try ScrollStitcher.overlap(previous: first, next: unrelated); fatalError("Unrelated should reject") } catch ScrollStitcher.StitchError.overlap {} catch { throw error } }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1000, pixelsHigh: 220, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
guard let rep, let graphics = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("OCR fixture") }
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1000, height: 220).fill()
("SnapForge local recognition 12345" as NSString).draw(at: NSPoint(x: 30, y: 100), withAttributes: [.font: NSFont.systemFont(ofSize: 40), .foregroundColor: NSColor.black])
NSGraphicsContext.restoreGraphicsState()
guard let textImage = rep.cgImage else { fatalError("OCR bitmap") }
let text = try OCRService.recognize(textImage).map(\.text).joined(separator: " ")
check(text.contains("SnapForge") && text.contains("12345"), "Vision recognizes real rendered text")
let white = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 100, pixelsHigh: 100, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
if let blank = white?.cgImage { let lines = try OCRService.recognize(blank); check(lines.isEmpty, "blank OCR result") }
print("PASS: Vision text recognition, blank OCR, color bounds, overlap, three-frame seams, unchanged/dimension/unrelated rejection")
