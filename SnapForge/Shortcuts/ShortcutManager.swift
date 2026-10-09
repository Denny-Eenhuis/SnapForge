import Carbon

// Carbon hot keys do not require Accessibility or Input Monitoring access.
@MainActor
final class ShortcutManager {
    private var refs: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    var action: ((UInt32) -> Void)?
    private static let signature: OSType = 0x534E5046
    static let keyCodes: [String: UInt32] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"1":18,"2":19,"3":20,"4":21,"6":22,"5":23,"9":25,"7":26,"8":28,"0":29,"o":31,"u":32,"i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46]
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        // AppKit consumes application-target keyboard events; dispatch hot keys
        // before they reach its responder chain.
        let status = InstallEventHandler(GetEventDispatcherTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == ShortcutManager.signature else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<ShortcutManager>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { manager.action?(id.id) }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        if status != noErr { handler = nil }
    }
    func apply(_ preferences: Preferences) throws {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        guard preferences.shortcutsEnabled else { return }
        guard handler != nil else { throw ShortcutError.conflict }
        let keys = [preferences.displayKey, preferences.regionKey, preferences.windowKey]
        guard Set(keys).count == keys.count, keys.allSatisfy({ Self.keyCodes[$0] != nil }) else { throw ShortcutError.invalid }
        let modifiers: UInt32
        switch preferences.shortcutModifiers {
        case "commandOption": modifiers = UInt32(cmdKey | optionKey)
        case "controlOption": modifiers = UInt32(controlKey | optionKey)
        default: modifiers = UInt32(cmdKey | shiftKey)
        }
        for (index, key) in keys.enumerated() {
            guard let code = Self.keyCodes[key] else { throw ShortcutError.invalid }
            var ref: EventHotKeyRef?
            let result = RegisterEventHotKey(code, modifiers, EventHotKeyID(signature: Self.signature, id: UInt32(index + 1)), GetEventDispatcherTarget(), 0, &ref)
            guard result == noErr, let ref else {
                refs.forEach { UnregisterEventHotKey($0) }
                refs.removeAll()
                throw ShortcutError.conflict
            }
            refs.append(ref)
        }
    }
    func shutdown() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
    enum ShortcutError: LocalizedError {
        case invalid, conflict
        var errorDescription: String? {
            self == .invalid ? "Choose a different valid key for each capture command. Shortcuts are disabled until corrected." : "A shortcut could not be registered. Choose another combination in Preferences. Shortcuts are disabled until corrected."
        }
    }
}
