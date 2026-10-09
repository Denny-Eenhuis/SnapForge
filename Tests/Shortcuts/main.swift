import AppKit
import Carbon

MainActor.assumeIsolated {
    _ = NSApplication.shared
    let manager = ShortcutManager()
    defer { manager.shutdown() }
    var received: [UInt32] = []
    manager.action = { received.append($0) }
    // Exercise Carbon delivery to the actual installed target, without generating
    // keyboard input or requesting Accessibility/Screen Recording permissions.
    for command in UInt32(1)...3 {
        var event: EventRef?
        precondition(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, EventAttributes(kEventAttributeUserEvent), &event) == noErr)
        guard let event else { fatalError("Missing event") }
        defer { ReleaseEvent(event) }
        var id = EventHotKeyID(signature: 0x534E5046, id: command)
        precondition(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &id) == noErr)
        precondition(SendEventToEventTarget(event, GetEventDispatcherTarget()) == noErr, "Hot key must be delivered to its registered handler")
    }
    precondition(received == [1, 2, 3], "Each capture command must dispatch once")
    manager.shutdown()
    print("PASS: dispatcher delivery of main, region and window commands; handler cleanup")
}
