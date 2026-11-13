// Keyboard backlight via the private CoreBrightness / KeyboardBrightnessClient.
// Apple Silicon MacBooks dropped the dedicated keys; this brings them back.

import Foundation

enum KeyboardBacklight {
    private typealias GetLevel = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias SetLevel = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
    private typealias GetAuto  = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    private typealias SetAuto  = @convention(c) (AnyObject, Selector, Bool, UInt64) -> Bool

    private static let client: NSObject? = {
        guard loadFramework("CoreBrightness") else { return nil }
        return (NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type)?.init()
    }()

    private static let keyboardID: UInt64? = (client?.perform(NSSelectorFromString("copyKeyboardBacklightIDs"))?
        .takeRetainedValue() as? [NSNumber])?.first?.uint64Value

    private static func call<T>(_ name: String, as _: T.Type) -> (NSObject, Selector, T, UInt64)? {
        guard let c = client, let id = keyboardID else { return nil }
        let sel = NSSelectorFromString(name)
        guard c.responds(to: sel) else { return nil }
        return (c, sel, unsafeBitCast(c.method(for: sel), to: T.self), id)
    }

    static var isAvailable: Bool { keyboardID != nil }

    static let table = StepTable(levels: Config.keyboardLevels)

    static func read() -> Double {
        guard let (c, sel, f, id) = call("brightnessForKeyboard:", as: GetLevel.self) else { return 0 }
        return Double(f(c, sel, id))
    }

    /// Setting a level turns automatic (ambient-light) adjustment off; otherwise the system
    /// would move it again, which is the opposite of what you want in the dark.
    static func write(_ value: Double) {
        if let (c, sel, f, id) = call("isAutoBrightnessEnabledForKeyboard:", as: GetAuto.self), f(c, sel, id),
           let (c2, sel2, f2, id2) = call("enableAutoBrightness:forKeyboard:", as: SetAuto.self) {
            _ = f2(c2, sel2, false, id2)
        }
        if let (c, sel, f, id) = call("setBrightness:forKeyboard:", as: SetLevel.self) {
            _ = f(c, sel, Float(clamp(value, 0, 1)), id)
        }
    }
}
