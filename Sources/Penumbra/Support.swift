import Foundation

var verbose = false

func log(_ message: @autoclosure () -> String) {
    guard verbose else { return }
    print(message())
    fflush(stdout)
}

func now() -> Double { ProcessInfo.processInfo.systemUptime }

func format(_ f: String, _ v: Double) -> String { String(format: f, v) }

func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double { max(lo, min(hi, x)) }

/// Minimal localization: English by default, Spanish when it is the user's preferred language.
func L(_ en: String, _ es: String) -> String {
    (Locale.preferredLanguages.first ?? "en").hasPrefix("es") ? es : en
}

/// Loads a private framework by path. Returns false if it is missing on this macOS version.
@discardableResult
func loadFramework(_ name: String) -> Bool {
    dlopen("/System/Library/PrivateFrameworks/\(name).framework/\(name)", RTLD_NOW) != nil
}

/// Discrete steps defined by consecutive zones, each with its own resolution.
/// Giving a zone a finer step *adds* positions without taking resolution away from others.
struct StepTable {
    let values: [Double]

    init(_ zones: [(upTo: Double, step: Double)]) {
        var v = [0.0], from = 0.0
        for z in zones {
            let n = max(1, Int(((z.upTo - from) / z.step).rounded()))
            for i in 1...n { v.append(from + (z.upTo - from) * Double(i) / Double(n)) }
            from = z.upTo
        }
        values = v
    }

    /// Explicit levels, e.g. a geometric series. Must start at 0 and increase.
    init(levels: [Double]) { values = levels }

    var steps: Double { Double(values.count - 1) }

    func value(at pos: Double) -> Double { values[Int(clamp(pos.rounded(), 0, steps))] }

    /// Position whose value is closest to `v`.
    func position(of v: Double) -> Double {
        var best = 0, bestDistance = Double.infinity
        for (i, x) in values.enumerated() where abs(x - v) < bestDistance { best = i; bestDistance = abs(x - v) }
        return Double(best)
    }
}
