// All tunables in one place.

import Foundation

enum Config {
    // Brightness: 50 linear steps of 2 %. Position 0 turns the backlight off.
    static let brightnessZones: [(upTo: Double, step: Double)] = [(1.00, 0.02)]

    // Keyboard backlight: off + 10 geometric levels (how the eye perceives light).
    // Tested by eye on an M2 MacBook Air: every value from ~0.25 down to 0.001 looks identical
    // (the LED driver's lowest visible level; macOS's own minimum step, 0.0625, sits there too),
    // so the levels start at 0.25 instead of wasting steps that change nothing.
    static let keyboardLevels: [Double] = {
        let lowest = 0.25, count = 10
        let ratio = pow(1 / lowest, 1 / Double(count - 1))
        return [0] + (0..<count).map { lowest * pow(ratio, Double($0)) }
    }()

    // Color temperature axis: steps of 50 K from 6000 K down to `extendedMinKelvin`
    // (below Night Shift's 2700 K floor via gamma tables), then `redSteps` more steps
    // that fade green/blue out to pure red.
    static let kelvinStep = 50.0
    static let extendedMinKelvin = 1000.0
    static let redSteps = 20.0

    // Holding a key: after `holdDelay`, one step every fixed interval (no acceleration).
    static let holdDelay = 0.30
    static let repeatBrightness = 0.05   // 50 steps ≈ 2.5 s
    static let repeatKeyboard = 0.15     // 10 steps ≈ 1.5 s
    static let repeatTemperature = 0.03  // 120 steps ≈ 3.6 s
    static let maxHold = 8.0             // safety stop if the key-up never arrives

    // Quick taps (< tapWindow apart, same direction and axis) take bigger steps: 1, 1, 2, 2, 3.
    static let tapWindow = 0.35
    static let tapMaxStep = 3

    // Pressing both brightness keys cycles the mode; it falls back to brightness after this idle time.
    static let modeTimeout = 5.0

    // HUD
    static let hudVisibleFor = 1.4
}
