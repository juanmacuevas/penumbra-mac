// Color temperature: Night Shift (private CoreBrightness / CBBlueLightClient) plus gamma tables
// (public CGSetDisplayTransferByTable) to go warmer than Night Shift allows, down to pure red.
//
// The axis is a single list of positions:
//   0 … redSteps                 green/blue fade out to pure red (the "astronomy" end)
//   redSteps … (Night Shift min)  extendedMinKelvin … 2700 K, Night Shift at max + blackbody gamma table
//   … top                         2700 K … 6000 K, Night Shift only
// Every step above the red zone is `Config.kelvinStep` (50 K).

import CoreGraphics
import Foundation

enum Temperature {
    // MARK: Night Shift

    private typealias GetFloat    = @convention(c) (AnyObject, Selector, UnsafeMutablePointer<Float>) -> Bool
    private typealias GetRaw      = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
    private typealias SetStrength = @convention(c) (AnyObject, Selector, Float, Float, Bool) -> Bool
    private typealias SetBool     = @convention(c) (AnyObject, Selector, Bool) -> Bool

    private static let client: NSObject? = {
        guard loadFramework("CoreBrightness") else { return nil }
        return (NSClassFromString("CBBlueLightClient") as? NSObject.Type)?.init()
    }()

    private static func call<T>(_ name: String, as _: T.Type) -> (NSObject, Selector, T)? {
        guard let c = client else { return nil }
        let sel = NSSelectorFromString(name)
        guard c.responds(to: sel) else { return nil }
        return (c, sel, unsafeBitCast(c.method(for: sel), to: T.self))
    }

    static var isAvailable: Bool { client != nil }

    /// Status struct: byte 0 = active (on now, by schedule or manually), byte 1 = enabled (on manually).
    private static func status() -> (active: Bool, enabled: Bool) {
        guard let (c, sel, f) = call("getBlueLightStatus:", as: GetRaw.self) else { return (false, false) }
        let buf = UnsafeMutableRawPointer.allocate(byteCount: 128, alignment: 8)
        defer { buf.deallocate() }
        memset(buf, 0, 128)
        _ = f(c, sel, buf)
        return (buf.load(as: UInt8.self) != 0, buf.load(fromByteOffset: 1, as: UInt8.self) != 0)
    }

    private static func readStrength() -> Double {
        guard status().active, let (c, sel, f) = call("getStrength:", as: GetFloat.self) else { return 0 }
        var s: Float = 0
        _ = f(c, sel, &s)
        return Double(s)
    }

    private static func writeStrength(_ s: Double) {
        // When Night Shift is only on because of its schedule, the system stores a new strength
        // but does NOT apply it on screen. Switching to manual (enabled) mode first fixes that.
        if !status().enabled, let (c, sel, f) = call("setEnabled:", as: SetBool.self) { _ = f(c, sel, true) }
        // Period 0 = no gradual system transition.
        if let (c, sel, f) = call("setStrength:withPeriod:commit:", as: SetStrength.self) { _ = f(c, sel, Float(clamp(s, 0, 1)), 0, true) }
    }

    /// Night Shift range in Kelvin: (warmest, coolest, mid). Measured mapping: strength 0 → max,
    /// 0.5 → mid, 1 → min, linear in between.
    static let range: (min: Double, max: Double, mid: Double) = {
        if let (c, sel, f) = call("getCCTRange:", as: GetRaw.self) {
            let b = UnsafeMutableRawPointer.allocate(byteCount: 64, alignment: 8)
            defer { b.deallocate() }
            memset(b, 0, 64)
            _ = f(c, sel, b)
            let v = (0..<3).map { Double(b.load(fromByteOffset: $0 * 4, as: Float.self)) }
            if v[0] > 0 && v[1] > v[0] { return (v[0], v[1], v[2]) }
        }
        return (2700, 6000, 4100)
    }()

    private static func strength(forKelvin k: Double) -> Double {
        let r = range
        return k >= r.mid ? (r.max - k) / (r.max - r.mid) * 0.5 : 0.5 + (r.mid - k) / (r.mid - r.min) * 0.5
    }

    private static func kelvin(forStrength s: Double) -> Double {
        let r = range
        return s <= 0.5 ? r.max - s / 0.5 * (r.max - r.mid) : r.mid - (s - 0.5) / 0.5 * (r.mid - r.min)
    }

    // MARK: Axis

    /// Lowest Kelvin on the axis and number of red-fade steps. Fall back to Night Shift's own
    /// range when gamma tables are unavailable.
    private(set) static var minKelvin = Config.extendedMinKelvin
    private(set) static var redSteps = Config.redSteps

    static var steps: Double { ((range.max - minKelvin) / Config.kelvinStep).rounded() + redSteps }

    static func kelvin(at pos: Double) -> Double { min(range.max, minKelvin + max(0, pos - redSteps) * Config.kelvinStep) }

    static func position(ofKelvin k: Double) -> Double { redSteps + (k - minKelvin) / Config.kelvinStep }

    /// HUD label: "3450 K", or "● 35%" in the red zone (no words, so it reads in any language).
    static func label(at pos: Double) -> String {
        pos < redSteps
            ? "● \(Int(((redSteps - pos) / redSteps * 100).rounded()))%"
            : format("%.0f K", kelvin(at: pos))
    }

    static func currentPosition() -> Double {
        let s = readStrength()
        if let p = gammaPosition, s >= 0.999 { return clamp(p.rounded(), 0, steps) }
        return clamp(position(ofKelvin: kelvin(forStrength: s)).rounded(), 0, steps)
    }

    static func apply(_ pos: Double) {
        let p = clamp(pos, 0, steps)
        let k = kelvin(at: p)
        if k < range.min || p < redSteps {
            writeStrength(1)
            gammaPosition = p
        } else {
            writeStrength(strength(forKelvin: k))
            if gammaPosition == nil { return }
            gammaPosition = nil
        }
        applyGamma()
    }

    // MARK: Gamma tables (warmer than Night Shift)
    //
    // Below 2700 K: scale green and blue by blackbody ratios (Tanner Helland's approximation,
    // valid from ~1000 K) relative to 2700 K, so the hand-off from Night Shift is seamless.
    // In the red zone green/blue fade linearly to 0. macOS restores the table when the process
    // exits, so the screen can never be left tinted.

    private static var gammaPosition: Double?
    private static var original: (r: [CGGammaValue], g: [CGGammaValue], b: [CGGammaValue], n: UInt32)?

    static func setUpGamma() {
        let cap: UInt32 = 1024
        var r = [CGGammaValue](repeating: 0, count: Int(cap)), g = r, b = r
        var n: UInt32 = 0
        if CGGetDisplayTransferByTable(builtinDisplay, cap, &r, &g, &b, &n) == .success, n > 0 {
            original = (Array(r.prefix(Int(n))), Array(g.prefix(Int(n))), Array(b.prefix(Int(n))), n)
        } else {
            minKelvin = range.min
            redSteps = 0
            log("gamma tables unavailable: temperature axis limited to \(Int(range.min)) K")
        }
    }

    /// Re-apply after wake or display changes (macOS may reset the table).
    static func reapplyGammaIfNeeded() { if gammaPosition != nil { applyGamma() } }

    /// Drop the extra tint (used when pausing).
    static func resetGamma() {
        gammaPosition = nil
        applyGamma()
    }

    private static func blackbodyGB(_ k: Double) -> (g: Double, b: Double) {
        let t = k / 100
        let g = 99.4708025861 * log(t) - 161.1195681661
        let b = t <= 10 ? 0 : 138.5177312231 * log(t - 10) - 305.0447927307
        return (clamp(g, 0, 255), clamp(b, 0, 255))
    }

    private static func applyGamma() {
        guard let o = original else { return }
        guard let pos = gammaPosition else {
            _ = CGSetDisplayTransferByTable(builtinDisplay, o.n, o.r, o.g, o.b)
            return
        }
        let ref = blackbodyGB(range.min), cur = blackbodyGB(kelvin(at: pos))
        var gm = Float(ref.g > 0 ? cur.g / ref.g : 1)
        var bm = Float(ref.b > 0 ? cur.b / ref.b : 0)
        if pos < redSteps {
            let f = Float(max(0, pos) / redSteps)
            gm *= f
            bm *= f
        }
        _ = CGSetDisplayTransferByTable(builtinDisplay, o.n, o.r, o.g.map { $0 * gm }, o.b.map { $0 * bm })
    }
}
