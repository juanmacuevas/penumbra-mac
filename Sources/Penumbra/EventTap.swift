// Captures the brightness keys (and fn + Esc) before the system handles them.
//
// Brightness keys arrive as NX_SYSDEFINED events (subtype 8) with key code 2 (up) / 3 (down) and
// real press/release states. Because we react to the *event*, not the physical key, the
// "Use F1, F2… as standard function keys" setting is respected automatically.

import Cocoa

enum EventTap {
    private static var tap: CFMachPort?

    static var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    /// Returns false if the tap could not be created (missing Accessibility permission).
    @discardableResult
    static func start() -> Bool {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            return true
        }
        let mask: CGEventMask = (1 << 14) | (1 << CGEventType.keyDown.rawValue)   // NX_SYSDEFINED + key down
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: mask, callback: eventTapCallback, userInfo: nil)
        else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    static func pause() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        Controller.stopHold()
    }

    fileprivate static func reenable() { if let tap { CGEvent.tapEnable(tap: tap, enable: true) } }
}

private let escapeKeyCode: Int64 = 53

private func eventTapCallback(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent,
                              _ refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        EventTap.reenable()
        return Unmanaged.passUnretained(event)
    }

    // fn + Esc → Fn Lock
    if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == escapeKeyCode,
       event.flags.contains(.maskSecondaryFn) {
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { FnLock.toggle() }
        return nil
    }

    guard type.rawValue == 14, let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8 else {
        return Unmanaged.passUnretained(event)
    }
    let code = (ns.data1 & 0xFFFF0000) >> 16
    guard code == 2 || code == 3 else { return Unmanaged.passUnretained(event) }
    let state = (ns.data1 & 0xFF00) >> 8   // 0xA = down, 0xB = up
    let flags = event.flags
    Controller.brightnessKey(up: code == 2, isDown: state == 0xA, isRepeat: (ns.data1 & 0x1) == 1,
                             shift: flags.contains(.maskShift), control: flags.contains(.maskControl))
    return nil   // swallowed: the system never sees it
}
