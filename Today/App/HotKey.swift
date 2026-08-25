import Carbon.HIToolbox

enum HotKeyConfig {
    // ⌥Space. If this collides with an input-source switcher, change the
    // modifier here (e.g. controlKey, or optionKey | shiftKey).
    static let keyCode = UInt32(kVK_Space)
    static let modifiers = UInt32(optionKey)
}

// AppKit-arcana: Carbon's RegisterEventHotKey is still the sanctioned way to
// own a global hotkey — unlike NSEvent global monitors, it consumes the event.
@MainActor
final class HotKey {
    // Only ever touched on the main thread, but deinit is nonisolated.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?
    private let handler: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
                // Carbon dispatches on the main thread.
                MainActor.assumeIsolated { hotKey.handler() }
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )
        guard installStatus == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x5444_4159) /* 'TDAY' */, id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
