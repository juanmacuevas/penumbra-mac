// Built-in display brightness via the private DisplayServices framework.
// (IOKit's IODisplaySetFloatParameter no longer works on Apple Silicon's built-in panel.)

import CoreGraphics
import Foundation

enum Brightness {
    private typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (UInt32, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getFn: GetFn? = handle.flatMap { dlsym($0, "DisplayServicesGetBrightness") }.map { unsafeBitCast($0, to: GetFn.self) }
    private static let setFn: SetFn? = handle.flatMap { dlsym($0, "DisplayServicesSetBrightness") }.map { unsafeBitCast($0, to: SetFn.self) }

    static var isAvailable: Bool { getFn != nil && setFn != nil }

    static let table = StepTable(Config.brightnessZones)

    static func read() -> Double {
        var b: Float = 0
        _ = getFn?(builtinDisplay, &b)
        return Double(b)
    }

    static func write(_ value: Double) { _ = setFn?(builtinDisplay, Float(clamp(value, 0, 1))) }
}

/// The built-in panel (falls back to the main display).
let builtinDisplay: CGDirectDisplayID = {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var n: UInt32 = 0
    CGGetOnlineDisplayList(16, &ids, &n)
    return ids.prefix(Int(n)).first { CGDisplayIsBuiltin($0) != 0 } ?? CGMainDisplayID()
}()
