//
//  HotkeyManager.swift
//  SolUnified
//
//  Global hotkey registration using Carbon APIs
//

import Foundation
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    private init() {}
    
    func register(onActivation: @escaping () -> Void) -> Bool {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x53554944) // 'SUID'
        hotKeyID.id = 1
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Create callback context
        let context = UnsafeMutableRawPointer(Unmanaged.passRetained(HotkeyCallback(callback: onActivation)).toOpaque())
        
        // Install event handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let callback = Unmanaged<HotkeyCallback>.fromOpaque(userData).takeUnretainedValue()
                callback.callback()
                return noErr
            },
            1,
            &eventType,
            context,
            &eventHandler
        )
        
        if status != noErr {
            print("Failed to install event handler: \(status)")
            return false
        }
        
        // Register hotkey: Option + Backtick
        let keyCode = UInt32(kVK_ANSI_Grave) // Backtick key
        let modifiers = UInt32(optionKey)
        
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if registerStatus != noErr {
            print("Failed to register hotkey: \(registerStatus)")
            return false
        }
        
        print("Hotkey registered successfully: Option + `")
        return true
    }
    
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    deinit {
        unregister()
    }
}

// Helper class to hold the callback closure
private class HotkeyCallback {
    let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
}

