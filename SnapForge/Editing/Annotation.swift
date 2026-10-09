import AppKit

// All coordinates are source-image pixels, measured from the top-left corner.
enum EditorTool: String, CaseIterable {
    case select = "Select", arrow = "Arrow", rectangle = "Rectangle", rounded = "Rounded", ellipse = "Ellipse"
    case line = "Line", freehand = "Pen", text = "Text", callout = "Number", blur = "Blur", pixelate = "Pixelate", crop = "Crop"
    var shortcut: String {
        switch self {
        case .select: return "v"
        case .arrow: return "a"
        case .rectangle: return "r"
        case .rounded: return "u"
        case .ellipse: return "e"
        case .line: return "l"
        case .freehand: return "p"
        case .text: return "t"
        case .callout: return "n"
        case .blur: return "b"
        case .pixelate: return "x"
        case .crop: return "c"
        }
    }
}

struct Annotation: Equatable {
    var id = UUID()
    var tool: EditorTool
    var start: CGPoint
    var end: CGPoint
    var points: [CGPoint] = []
    var text = "Text"
    var number = 1
    var color = NSColor.systemRed
    var thickness: CGFloat = 4
    var fontSize: CGFloat = 28
    var rect: CGRect { CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y)) }
    var hitBounds: CGRect {
        if tool == .text {
            let size = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: fontSize, weight: .medium)])
            return CGRect(origin: start, size: size).insetBy(dx: -6, dy: -6)
        }
        if tool == .callout { return CGRect(x: start.x - fontSize, y: start.y - fontSize, width: fontSize * 2, height: fontSize * 2) }
        if tool == .freehand, let first = points.first {
            let bounds = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
            return bounds.insetBy(dx: -max(6, thickness), dy: -max(6, thickness))
        }
        return rect.insetBy(dx: -max(6, thickness), dy: -max(6, thickness))
    }
    func moved(by offset: CGPoint) -> Annotation {
        var result = self
        result.start.x += offset.x; result.start.y += offset.y
        result.end.x += offset.x; result.end.y += offset.y
        result.points = points.map { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) }
        return result
    }
}

struct EditorState: Equatable {
    var annotations: [Annotation] = []
    var crop: CGRect?
}

@MainActor
final class EditorDocument {
    let source: CGImage
    private(set) var state = EditorState()
    private var undoStates: [EditorState] = []
    private var redoStates: [EditorState] = []
    private(set) var savedState = EditorState()
    var savedURL: URL?
    var changed: (() -> Void)?
    var canUndo: Bool { !undoStates.isEmpty }
    var canRedo: Bool { !redoStates.isEmpty }
    var isDirty: Bool { state != savedState }
    var imageBounds: CGRect { CGRect(x: 0, y: 0, width: source.width, height: source.height) }
    var visibleBounds: CGRect { state.crop ?? imageBounds }
    init(image: CGImage, savedURL: URL? = nil) { source = image; self.savedURL = savedURL }
    func commit(_ next: EditorState) {
        guard next != state else { return }
        undoStates.append(state)
        if undoStates.count > 100 { undoStates.removeFirst() }
        redoStates.removeAll()
        state = next
        changed?()
    }
    func undo() {
        guard let previous = undoStates.popLast() else { return }
        redoStates.append(state); state = previous; changed?()
    }
    func redo() {
        guard let next = redoStates.popLast() else { return }
        undoStates.append(state); state = next; changed?()
    }
    func markSaved(to url: URL, state saved: EditorState) { savedURL = url; savedState = saved; changed?() }
}
