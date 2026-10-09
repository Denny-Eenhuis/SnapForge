import AppKit
import CoreImage

@MainActor
enum AnnotationRenderer {
    private static let filters = CIContext(options: [.cacheIntermediates: false])
    enum RenderError: LocalizedError {
        case allocation, filter, crop
        var errorDescription: String? {
            switch self {
            case .allocation: return "There is not enough memory to export this image."
            case .filter: return "The blur or pixelation could not be rendered. Export was stopped."
            case .crop: return "The crop is outside the image."
            }
        }
    }
    static func render(source: CGImage, state: EditorState) throws -> CGImage {
        if state.annotations.isEmpty {
            guard let crop = state.crop else { return source }
            let rect = crop.integral.intersection(CGRect(x: 0, y: 0, width: source.width, height: source.height))
            guard !rect.isNull, rect.width > 0, rect.height > 0, let result = source.cropping(to: rect) else { throw RenderError.crop }
            return result
        }
        guard let context = CGContext(data: nil, width: source.width, height: source.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: source.colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw RenderError.allocation }
        context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        context.translateBy(x: 0, y: CGFloat(source.height))
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        for annotation in state.annotations {
            if annotation.tool == .blur || annotation.tool == .pixelate {
                let area = annotation.rect.integral.intersection(CGRect(x: 0, y: 0, width: source.width, height: source.height))
                guard !area.isNull, area.width > 0, area.height > 0 else { continue }
                guard let current = context.makeImage() else { throw RenderError.allocation }
                let input = CIImage(cgImage: current)
                let result: CIImage
                if annotation.tool == .blur {
                    result = input.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: max(10, annotation.thickness * 4)]).cropped(to: input.extent)
                } else {
                    result = input.applyingFilter("CIPixellate", parameters: [kCIInputScaleKey: max(12, annotation.thickness * 5)])
                }
                let region = CGRect(x: area.minX, y: CGFloat(source.height) - area.maxY, width: area.width, height: area.height)
                guard let filtered = filters.createCGImage(result, from: region) else { throw RenderError.filter }
                NSImage(cgImage: filtered, size: area.size).draw(in: area, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
            } else { draw(annotation) }
        }
        guard let output = context.makeImage() else { throw RenderError.allocation }
        if let crop = state.crop {
            let clipped = crop.integral.intersection(CGRect(x: 0, y: 0, width: source.width, height: source.height))
            guard !clipped.isNull, clipped.width > 0, clipped.height > 0, let result = output.cropping(to: clipped) else { throw RenderError.crop }
            return result
        }
        return output
    }
    static func draw(_ annotation: Annotation) {
        annotation.color.setStroke()
        annotation.color.setFill()
        let path = NSBezierPath()
        path.lineWidth = annotation.thickness
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        switch annotation.tool {
        case .arrow, .line:
            path.move(to: annotation.start); path.line(to: annotation.end); path.stroke()
            if annotation.tool == .arrow {
                let angle = atan2(annotation.end.y - annotation.start.y, annotation.end.x - annotation.start.x)
                let length = max(12, annotation.thickness * 4)
                let head = NSBezierPath()
                head.move(to: annotation.end)
                for delta in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                    head.line(to: CGPoint(x: annotation.end.x - length * cos(angle + delta), y: annotation.end.y - length * sin(angle + delta)))
                    head.line(to: annotation.end)
                }
                head.lineWidth = annotation.thickness; head.lineCapStyle = .round; head.stroke()
            }
        case .rectangle: NSBezierPath(rect: annotation.rect).styledStroke(annotation.thickness)
        case .rounded: NSBezierPath(roundedRect: annotation.rect, xRadius: 12, yRadius: 12).styledStroke(annotation.thickness)
        case .ellipse: NSBezierPath(ovalIn: annotation.rect).styledStroke(annotation.thickness)
        case .freehand:
            guard let first = annotation.points.first else { return }
            path.move(to: first)
            for point in annotation.points.dropFirst() { path.line(to: point) }
            path.stroke()
        case .text:
            (annotation.text as NSString).draw(at: annotation.start, withAttributes: [.font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .medium), .foregroundColor: annotation.color])
        case .callout:
            NSBezierPath(ovalIn: CGRect(x: annotation.start.x - annotation.fontSize, y: annotation.start.y - annotation.fontSize, width: annotation.fontSize * 2, height: annotation.fontSize * 2)).fill()
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: annotation.fontSize, weight: .bold), .foregroundColor: NSColor.white]
            let string = String(annotation.number) as NSString
            let size = string.size(withAttributes: attributes)
            string.draw(at: CGPoint(x: annotation.start.x - size.width / 2, y: annotation.start.y - size.height / 2), withAttributes: attributes)
        default: break
        }
    }
}

private extension NSBezierPath {
    func styledStroke(_ width: CGFloat) { lineWidth = width; stroke() }
}
