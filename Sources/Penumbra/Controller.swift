// Turns brightness-key presses into steps on one of three axes, with taps, quick-tap streaks,
// constant-rate holding, and a both-keys chord that cycles the default axis.

import Foundation

enum Axis: CaseIterable {
    case brightness, temperature, keyboard

    var steps: Double {
        switch self {
        case .brightness:  return Brightness.table.steps
        case .temperature: return Temperature.steps
        case .keyboard:    return KeyboardBacklight.table.steps
        }
    }

    var repeatInterval: Double {
        switch self {
        case .brightness:  return Config.repeatBrightness
        case .temperature: return Config.repeatTemperature
        case .keyboard:    return Config.repeatKeyboard
        }
    }

    func currentPosition() -> Double {
        switch self {
        case .brightness:  return Brightness.table.position(of: Brightness.read())
        case .temperature: return Temperature.currentPosition()
        case .keyboard:    return KeyboardBacklight.table.position(of: KeyboardBacklight.read())
        }
    }

    func apply(_ pos: Double) {
        switch self {
        case .brightness:  Brightness.write(Brightness.table.value(at: pos))
        case .temperature: Temperature.apply(pos)
        case .keyboard:    KeyboardBacklight.write(KeyboardBacklight.table.value(at: pos))
        }
    }

    func label(_ pos: Double) -> String {
        self == .temperature ? Temperature.label(at: pos) : (pos <= 0 ? "off" : "\(Int(pos))/\(Int(steps))")
    }
}

enum Controller {
    private struct Hold {
        var axis: Axis
        var direction: Double
        var start: Double   // position before the tap, to undo it if this turns out to be a chord
        var pos: Double
        var pressedAt: Double
    }

    private static var hold: Hold?
    private static var holdWork: DispatchWorkItem?

    private static var lastTap = (time: 0.0, direction: 0.0, axis: Axis.brightness)
    private static var tapStreak = 0

    private static let modeCycle: [Axis] = [.brightness, .temperature, .keyboard]
    private static var mode = Axis.brightness
    private static var lastActivity = 0.0
    private static var heldKeys = Set<Bool>()   // true = up key, false = down key
    private static var chordActive = false

    /// Entry point from the event tap. `up` = brightness-up key; `isDown` = press (false = release).
    static func brightnessKey(up: Bool, isDown: Bool, isRepeat: Bool, shift: Bool, control: Bool) {
        let t = now()
        if t - lastActivity > Config.modeTimeout { mode = .brightness }
        lastActivity = t

        if !isDown {
            heldKeys.remove(up)
            if chordActive {
                if heldKeys.isEmpty { chordActive = false }
                return
            }
            stopHold()
            return
        }
        guard !isRepeat, !chordActive else { return }   // holding is timed by us, not by key repeat
        heldKeys.insert(up)

        if heldKeys.count == 2 {   // both keys: undo the first key's tap and cycle the mode
            if let h = hold, h.pos != h.start { h.axis.apply(h.start) }
            stopHold()
            chordActive = true
            mode = modeCycle[(modeCycle.firstIndex(of: mode)! + 1) % modeCycle.count]
            log("mode → \(mode)")
            let pos = mode.currentPosition()
            HUD.shared.show(axis: mode, fraction: pos / mode.steps, text: mode.label(pos))
            return
        }

        let axis: Axis = shift ? .temperature : control ? .keyboard : mode
        press(axis: axis, direction: up ? 1 : -1, at: t)
    }

    private static func press(axis: Axis, direction: Double, at t: Double) {
        stopHold()
        let start = axis.currentPosition()
        if t - lastTap.time < Config.tapWindow && direction == lastTap.direction && axis == lastTap.axis {
            tapStreak += 1
        } else {
            tapStreak = 0
        }
        lastTap = (t, direction, axis)
        let step = Double(min(Config.tapMaxStep, 1 + tapStreak / 2))
        let h = Hold(axis: axis, direction: direction, start: start,
                     pos: clamp(start + direction * step, 0, axis.steps), pressedAt: t)
        show(h)
        log("tap ×\(Int(step)) \(axis) \(axis.label(h.pos))")
        hold = h
        scheduleStep(after: Config.holdDelay)
    }

    private static func show(_ h: Hold) {
        h.axis.apply(h.pos)
        HUD.shared.show(axis: h.axis, fraction: h.pos / h.axis.steps, text: h.axis.label(h.pos))
    }

    private static func scheduleStep(after delay: Double) {
        let work = DispatchWorkItem {
            guard var h = hold else { return }
            if now() - h.pressedAt > Config.maxHold { stopHold(); return }
            let next = clamp(h.pos + h.direction, 0, h.axis.steps)
            if next != h.pos { h.pos = next; show(h) }
            hold = h
            scheduleStep(after: h.axis.repeatInterval)
        }
        holdWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    static func stopHold() {
        holdWork?.cancel()
        holdWork = nil
        hold = nil
    }
}
