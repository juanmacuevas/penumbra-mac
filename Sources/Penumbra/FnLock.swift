// Fn Lock (fn + Esc), like on ThinkPads: toggles "Use F1, F2, etc. keys as standard function keys"
// live, via IOHIDSystem's HIDFKeyMode parameter, and stores the preference so System Settings agrees.

import Foundation
import IOKit
import IOKit.hidsystem

enum FnLock {
    private static let prefKey = "com.apple.keyboard.fnState" as CFString

    /// true = F1–F12 are standard function keys; false = media keys.
    static var standardFunctionKeys: Bool {
        CFPreferencesCopyAppValue(prefKey, kCFPreferencesAnyApplication) as? Bool ?? false
    }

    static func set(standardFunctionKeys standard: Bool) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        defer { IOObjectRelease(service) }
        var connection: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection) == KERN_SUCCESS else { return }
        defer { IOServiceClose(connection) }
        var value: UInt32 = standard ? 1 : 0
        _ = IOHIDSetParameter(connection, kIOHIDFKeyModeKey as CFString, &value, IOByteCount(MemoryLayout<UInt32>.size))
        CFPreferencesSetValue(prefKey, standard as CFBoolean, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    static func toggle() {
        let standard = !standardFunctionKeys
        set(standardFunctionKeys: standard)
        log("fn lock → \(standard ? "F1–F12" : "media keys")")
        HUD.shared.showFnLock(standardFunctionKeys: standard)
    }
}
