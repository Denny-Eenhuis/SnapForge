import CoreGraphics

enum CaptureGeometry {
    // AppKit selection uses a bottom-left origin; captured pixels use top-left.
    static func pixelCrop(selection: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let clipped = selection.standardized.intersection(CGRect(origin: .zero, size: viewSize))
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else { return nil }
        let sx = imageSize.width / viewSize.width
        let sy = imageSize.height / viewSize.height
        return CGRect(x: clipped.minX * sx, y: (viewSize.height - clipped.maxY) * sy,
                      width: clipped.width * sx, height: clipped.height * sy).integral
            .intersection(CGRect(origin: .zero, size: imageSize))
    }
}
