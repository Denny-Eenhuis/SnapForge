import AppKit

@MainActor
final class PreviewController {
    private var editors: [EditorController] = []
    func canQuit() -> Bool {
        guard editors.contains(where: { $0.document.isDirty }) else { return true }
        let alert = NSAlert()
        alert.messageText = "Discard unsaved annotations and quit?"
        alert.informativeText = "Choose Keep Editing to save your edited screenshots before quitting."
        alert.addButton(withTitle: "Keep Editing")
        alert.addButton(withTitle: "Discard and Quit")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func show(_ captured: CGImage, savedURL: URL? = nil) {
        editors.removeAll { !$0.window.isVisible && !$0.document.isDirty }
        let editor = EditorController(image: captured, savedURL: savedURL)
        editor.closed = { [weak self, weak editor] in
            self?.editors.removeAll { $0 === editor }
        }
        editors.append(editor)
        editor.show()
    }
}
