import Foundation

/// Pure decision kernel for `ATShortcut.modifiersMatch`: given a keyboard event's modifier set and a
/// configured shortcut's modifiers, decide whether they match — accounting for the activation (hold)
/// modifiers and the current context (the holdShortcut / nextWindowShortcut special cases). Extracted
/// from `ATShortcut` so the branch *order* is unit-tested (same rationale as `NativeHotkeyResolver`,
/// #5653); `ATShortcut` is the thin adapter that gathers the inputs from `SwitcherSession` / `ControlsTab`.
///
/// All modifier args are *cleaned* Carbon bitmasks (see `CarbonModifierFlags.cleaned()`). The kernel
/// only compares bits, so unit tests can use opaque bit values rather than real Carbon constants.
enum ShortcutModifierResolver {
    static func matches(eventModifiers: UInt32,
                        shortcutModifiers: UInt32,
                        holdModifiers: UInt32,
                        isHoldShortcut: Bool,
                        isNextWindowShortcut: Bool,
                        sessionActive: Bool) -> Bool {
        // holdShortcut: the event must contain *at least* the shortcut's modifiers (e.g. ⌥ held).
        if isHoldShortcut {
            return eventModifiers == (eventModifiers | shortcutModifiers)
        }
        // nextWindowShortcut while the panel is open: also match the base key with the hold modifiers
        // stripped, so a configured ⌥⇥ cycles on bare ⇥ once the switcher is already showing.
        if sessionActive && isNextWindowShortcut {
            let baseModifiers = shortcutModifiers & ~holdModifiers
            if eventModifiers == baseModifiers { return true }
        }
        // Default: the event modifiers are exactly the shortcut's, or exactly the shortcut's + hold.
        return eventModifiers == shortcutModifiers || eventModifiers == (shortcutModifiers | holdModifiers)
    }
}
