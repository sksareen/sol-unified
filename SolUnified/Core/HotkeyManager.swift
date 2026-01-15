//
//  HotkeyManager.swift
//  SolUnified
//
//  Global hotkey registration using Carbon APIs.
//  Supports multiple hotkeys for v2 architecture:
//  - Opt+P: Toggle HUD (set objective)
//  - Opt+C: Context Engine (capture and copy)
//

import Foundation
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()

    // Hotkey references
    private var hudHotKeyRef: EventHotKeyRef?
    private var contextHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    // Callbacks
    private var hudCallback: (() -> Void)?
    private var contextCallback: (() -> Void)?

    private init() {}

    // MARK: - Public API

    /// Register all hotkeys for v2
    func registerAll(
        onHUD: @escaping () -> Void,
        onContext: @escaping () -> Void
    ) -> Bool {
        self.hudCallback = onHUD
        self.contextCallback = onContext

        // Install single event handler for all hotkeys
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(event)
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        if status != noErr {
            print("Failed to install event handler: \(status)")
            return false
        }

        // Register Opt+P for HUD
        var hudHotKeyID = EventHotKeyID()
        hudHotKeyID.signature = OSType(0x534F4C31) // 'SOL1'
        hudHotKeyID.id = 1

        let hudStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(optionKey),
            hudHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hudHotKeyRef
        )

        if hudStatus != noErr {
            print("Failed to register HUD hotkey (Opt+P): \(hudStatus)")
            return false
        }

        // Register Opt+C for Context Engine
        var contextHotKeyID = EventHotKeyID()
        contextHotKeyID.signature = OSType(0x534F4C32) // 'SOL2'
        contextHotKeyID.id = 2

        let contextStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_C),
            UInt32(optionKey),
            contextHotKeyID,
            GetApplicationEventTarget(),
            0,
            &contextHotKeyRef
        )

        if contextStatus != noErr {
            print("Failed to register Context hotkey (Opt+C): \(contextStatus)")
            return false
        }

        print("✓ Hotkeys registered:")
        print("  - Opt+P: Toggle HUD")
        print("  - Opt+C: Capture Context")

        return true
    }

    /// Unregister all hotkeys
    func unregisterAll() {
        if let ref = hudHotKeyRef {
            UnregisterEventHotKey(ref)
            hudHotKeyRef = nil
        }

        if let ref = contextHotKeyRef {
            UnregisterEventHotKey(ref)
            contextHotKeyRef = nil
        }

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }

        hudCallback = nil
        contextCallback = nil
    }

    // MARK: - Legacy API (for compatibility)

    func register(onActivation: @escaping () -> Void) -> Bool {
        // Legacy: Just register HUD hotkey
        return registerAll(onHUD: onActivation, onContext: {})
    }

    func unregister() {
        unregisterAll()
    }

    // MARK: - Private

    private func handleHotKeyEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else { return status }

        DispatchQueue.main.async { [weak self] in
            switch hotKeyID.id {
            case 1: // HUD
                self?.hudCallback?()
            case 2: // Context Engine
                self?.contextCallback?()
            default:
                break
            }
        }

        return noErr
    }

    deinit {
        unregisterAll()
    }
}
