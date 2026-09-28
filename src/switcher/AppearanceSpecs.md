# Appearance (window sizing) — Specs

## Summary

`AppearanceTestable.comfortableWidth` decides how wide the switcher is on a given display, so the UI
feels right from an 11" laptop to a 60" TV. The suite pins its output against a table of 21 real device
models (laptops, monitors, ultrawides, TVs) with known physical dimensions, so a tweak to the formula
cannot silently regress any class of screen.

## Behavior & edge cases

- Driven by a fixture table: each row is `(model, physical-mm, expected comfortable fractions)`. The
  test loops the table and asserts with `0.01` tolerance, naming the failing model.
- Bigger physical screens get a smaller comfortable fraction (a 60" TV does not show a half-screen
  switcher). Ultrawides get distinct horizontal and vertical fractions.

## Test scenarios

Mirrors `AppearanceTests.swift` 1:1.

- **testComfortableWidth** — for every model, the comfortable width fraction matches for both horizontal and vertical screen use.
- **testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil** — when the screen's physical dimensions are not reported, fall back to the 0.9 default rather than the 0.45 floor.
