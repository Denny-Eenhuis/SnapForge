import AppKit
import UniformTypeIdentifiers
import ImageIO

// One encoder for preview export and automatic saving.
enum ImageFormat: String, CaseIterable, Identifiable {
    case png, jpeg
    var id: String { rawValue }
    var contentType: UTType { self == .png ? .png : .jpeg }
}

enum ImageOutput {
    static func data(_ image: CGImage, format: ImageFormat) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.contentType.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }

    static func copy(_ image: CGImage) throws {
        let data = try data(image, format: .png)
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setData(data, forType: .png) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
    static func save(_ image: CGImage, format: ImageFormat, to url: URL) throws {
        try data(image, format: format).write(to: url, options: .atomic)
    }
    static func filename(format: ImageFormat, savedURL: URL? = nil) -> String {
        if let savedURL { return savedURL.deletingPathExtension().lastPathComponent + "." + format.rawValue }
        return "SnapForge-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-"))-\(UUID().uuidString.prefix(6)).\(format.rawValue)"
    }
}
