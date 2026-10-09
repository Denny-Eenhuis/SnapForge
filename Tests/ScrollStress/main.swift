import AppKit
import ImageIO

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
let width = 1024, viewport = 900, shift = 240, frames = 40
let totalHeight = viewport + shift * (frames - 1)
let source = fixture(width: width, height: totalHeight)
guard let initial = source.cropping(to: CGRect(x: 0, y: 0, width: width, height: viewport)) else { fatalError("initial") }
var previous = initial, composite = initial
for index in 1..<frames {
    try autoreleasepool {
        guard let next = source.cropping(to: CGRect(x: 0, y: shift * index, width: width, height: viewport)) else { fatalError("frame") }
        composite = try ScrollStitcher.append(composite: composite, previous: previous, next: next)
        previous = next
        precondition(composite.height == viewport + shift * index)
    }
}
let actual = try PixelBuffer(composite), expected = try PixelBuffer(source)
precondition(actual.bytes == expected.bytes, "All pixels and every seam must match the source")
print("PASS: 40-frame stitch \(width) × \(totalHeight), every output pixel matches")
guard let tallContext = CGContext(data: nil, width: width, height: 29900, bitsPerComponent: 8, bytesPerRow: width*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let tall = tallContext.makeImage(), let next = source.cropping(to: CGRect(x: 0, y: shift, width: width, height: viewport)) else { fatalError("limit fixture") }
do { _ = try ScrollStitcher.append(composite: tall, previous: initial, next: next); fatalError("Must enforce 30000px limit") }
catch ScrollStitcher.StitchError.tooLarge { print("PASS: height limit stops before composite allocation") }
