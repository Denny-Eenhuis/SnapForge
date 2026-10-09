import AppKit
import Vision

struct RecognizedText: Sendable {
    let text: String
    let bounds: CGRect
    let confidence: Float
}
struct OCRService {
    static func recognize(_ image: CGImage) throws -> [RecognizedText] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedText(text: candidate.string, bounds: observation.boundingBox, confidence: candidate.confidence)
        }.sorted {
            // Reading order: top to bottom, left to right within a line.
            let firstRow = Int(($0.bounds.midY * 100).rounded())
            let secondRow = Int(($1.bounds.midY * 100).rounded())
            if firstRow != secondRow { return firstRow > secondRow }
            return $0.bounds.minX < $1.bounds.minX
        }
    }
}

@MainActor
final class OCRController: NSObject {
    let window: NSWindow
    private let text = NSTextView()
    init(lines: [RecognizedText]) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        super.init()
        window.title = "SnapForge — Recognized Text"
        window.isReleasedWhenClosed = false
        let root = NSStackView(); root.orientation = .vertical; root.spacing = 10; root.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        let hint = NSTextField(labelWithString: lines.isEmpty ? "No text was recognized." : "Select text to copy a portion, or copy all. Recognition runs locally.")
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        text.isEditable = false; text.isSelectable = true; text.isRichText = false
        text.font = .systemFont(ofSize: 15); text.string = lines.map(\.text).joined(separator: "\n")
        text.setAccessibilityLabel("Recognized text")
        text.autoresizingMask = [.width]; text.isVerticallyResizable = true; text.isHorizontallyResizable = false
        text.textContainer?.widthTracksTextView = true
        scroll.documentView = text
        let copy = NSButton(title: "Copy All", target: self, action: #selector(copyAll)); copy.isEnabled = !lines.isEmpty
        let selected = NSButton(title: "Copy Selection", target: self, action: #selector(copySelection))
        let buttons = NSStackView(views: [selected, copy]); buttons.spacing = 8
        for view in [hint, scroll, buttons] { root.addArrangedSubview(view) }
        window.contentView = root
        scroll.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -24).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        window.center()
    }
    func show() { window.makeKeyAndOrderFront(nil); window.makeFirstResponder(text) }
    @objc private func copySelection() {
        let range = text.selectedRange()
        guard range.length > 0 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString((text.string as NSString).substring(with: range), forType: .string)
    }
    @objc private func copyAll() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text.string, forType: .string) }
}
