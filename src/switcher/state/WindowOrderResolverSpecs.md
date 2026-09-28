# WindowOrderResolver — Specs

> **Line coverage:** `WindowOrderResolver.swift` 96% · _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

`WindowOrderResolver.isOrderedBefore` decides the order windows appear in the switcher. It's the
comparator behind `Windows.sort`, extracted as a pure kernel: the caller precomputes each window's
ordering facts once (`OrderWindow` — a window's `WindowState` + its `ApplicationState`) and the kernel
compares two of them; the sort-mode knobs (`windowlessAtEnd`, `hiddenAtEnd`, `minimizedAtEnd`,
`sortType`) are labeled parameters with defaults, hoisted once per sort by the caller and captured by the
comparator closure.

Decision order:
1. **Show-at-the-end buckets** → windows whose type is set to "show at the end" (windowless / hidden /
   minimized) sink below the rest.
2. **Sort type** → `recentlyFocused` (lowest `lastFocusOrder`), `recentlyCreated` (highest
   `creationOrder`), `alphabetical` (app name, then title; `localizedStandardCompare`), or `space`
   (all-spaces windows first, then lowest space index, then alphabetical).
3. **Tiebreak** → `lastFocusOrder` (for the alphabetical/space paths).

## Behavior & edge cases

- Buckets only separate when the relevant "show at the end" preference is set *and* the two windows
  differ on that trait; otherwise ordering falls through to the sort type.
- `recentlyFocused`/`recentlyCreated` return directly (no alphabetical tiebreak); the `lastFocusOrder`
  tiebreak applies to the alphabetical/space paths.
- `space`: windows on all spaces sort ahead of space-bound ones; ties within a space fall back to
  alphabetical, then `lastFocusOrder`.
- Equal facts → not ordered before each other (strict weak ordering, required by `Array.sort`).

## One window per app

The stored `mainWindow` preference now means “show one window per app”; its persisted enum index is unchanged.
Only windows which passed the active filters are representative candidates. Selection order is exact current
attention, the still-eligible representative already shown in this switcher session, the app's last confirmed
attention, cached AX mainness as a cold-start fallback, then MRU with creation order and id as deterministic
tiebreaks. Current attention may replace the session choice; discovery and grouping churn may not.

## Test scenarios

Mirrors `WindowOrderResolverTests.swift` 1:1.

### B. Show-at-the-end buckets
- **testWindowlessPushedToEndWhenConfigured** — a windowless row sinks below a real window.
- **testRealWindowBeforeWindowlessWhenConfigured** — the real window comes first.
- **testWindowlessNotSeparatedWhenFlagOff** — with the bucket off, the sort type decides instead.
- **testHiddenPushedToEndWhenConfigured** — hidden-app windows sink when configured.
- **testMinimizedPushedToEndWhenConfigured** — minimized windows sink when configured.

### C. Recently focused
- **testRecentlyFocusedLowerOrderFirst** — lowest `lastFocusOrder` first.

### D. Recently created
- **testRecentlyCreatedHigherCreationOrderFirst** — highest `creationOrder` first.

### E. Alphabetical
- **testAlphabeticalByAppName** — by app name.
- **testAlphabeticalTitleBreaksTieWithinSameApp** — same app → by window title.
- **testAlphabeticalTiebreaksByLastFocusOrder** — identical app+title → `lastFocusOrder`.

### F. Space
- **testSpaceAllSpacesWindowsFirst** — all-spaces windows precede space-bound ones (a on all spaces).
- **testSpaceLowerSpaceIndexFirst** — lower space index first.
- **testSpaceTiebreaksByAppName** — same space → alphabetical.
- **testSpaceBothOnAllSpacesTiebreaksByAppName** — both on all spaces → no space-index ordering; fall through to alphabetical.
- **testSpaceOnlyBOnAllSpacesSortsBFirst** — mirror of `testSpaceAllSpacesWindowsFirst`: only b on all spaces → b sorts first (pins comparator symmetry).

### G. Tiebreak / symmetry
- **testEqualWindowsAreNotOrderedBeforeEachOther** — equal facts are not ordered before each other.
