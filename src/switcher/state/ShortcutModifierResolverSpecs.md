# ShortcutModifierResolver — Specs

## Summary

`ShortcutModifierResolver` is the pure decision kernel for `ATShortcut.modifiersMatch`: given a
keyboard event's modifier set and a configured shortcut's modifiers, does the event match the
shortcut? Extracted from `ATShortcut` so its branch order is unit-tested (same rationale as
`NativeHotkeyResolver`, #5653). `ATShortcut` is the thin adapter that gathers the inputs from
`SwitcherSession` (is a session active, which hold modifiers apply) and `ControlsTab`, then calls this
kernel.

All modifier arguments are *cleaned* Carbon bitmasks (`CarbonModifierFlags.cleaned()`). The kernel
only compares bits, so tests use opaque bit values.

## Branch order (matters — tested)

1. **holdShortcut** — the event must contain *at least* the shortcut's modifiers (`event == event | shortcut`).
   This is the "is the activation modifier held" check, so extra modifiers don't disqualify it.
2. **nextWindowShortcut while a session is active** — also match the base key with the hold modifiers
   stripped (`event == shortcut & ~hold`), so a configured ⌥⇥ keeps cycling on bare ⇥ once the switcher
   is already showing. Only consulted when `sessionActive`; falls through otherwise.
3. **default** — exact match, or exact + hold (`event == shortcut || event == shortcut | hold`).

---

## Test scenarios

Mirrors `ShortcutModifierResolverTests.swift` 1:1.

### A. holdShortcut ("contains at least")
- **testHoldShortcutMatchesWhenEventContainsItsModifiers** — shortcut ⌥, event ⌥⌘ → matches (extra modifier allowed).
- **testHoldShortcutFailsWhenEventMissingItsModifiers** — shortcut ⌥, event ⌘ → no match.

### B. nextWindowShortcut base key (hold stripped) while a session is active
- **testNextWindowMatchesBaseKeyWithoutHoldDuringSession** — shortcut ⌘⌥, hold ⌥, event ⌘ → matches the base key.
- **testNextWindowBaseKeyNotMatchedWithoutSession** — same inputs, no session → falls through to default → no match.

### D. Default matching (exact, or exact + hold)
- **testKeyShortcutMatchesExactModifiers** — shortcut ⌘, event ⌘ → matches.
- **testKeyShortcutMatchesShortcutPlusHold** — shortcut none, event ⌥ (a key with no modifiers, pressed with the hold modifier) → matches.
- **testKeyShortcutFailsWithExtraModifier** — shortcut ⌘, event ⌘⇧ → no match.
