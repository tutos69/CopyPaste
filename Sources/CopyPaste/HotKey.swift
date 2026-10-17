import Carbon

/// Global keyboard shortcut via Carbon. Does not need Accessibility permission.
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?
    private(set) var registered = false

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        let id = UInt32(HotKey.handlers.count + 1)
        HotKey.handlers[id] = handler
        HotKey.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x4350_5354), id: id) // "CPST"
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        registered = status == noErr
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
    }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            DispatchQueue.main.async { HotKey.handlers[hotKeyID.id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
