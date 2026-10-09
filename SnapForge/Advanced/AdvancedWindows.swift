import AppKit

// Own auxiliary windows independently of their originating editor, releasing pixels on close.
@MainActor
final class AdvancedWindows: NSObject, NSWindowDelegate {
    static let shared = AdvancedWindows()
    private var owners: [ObjectIdentifier: AnyObject] = [:]
    func retain(_ owner: AnyObject, window: NSWindow) {
        owners[ObjectIdentifier(window)] = owner
        window.delegate = self
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        owners.removeValue(forKey: ObjectIdentifier(window))
    }
}
