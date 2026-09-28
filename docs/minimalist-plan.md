# Minimalist AltTab plan

## Goal

When you press Cmd+Tab, AltTab shows a vertical list. Each row has the app icon and the window title. There are no screenshots, no previews, no licensing, and no extra features.

## Starting point

AltTab already has a "Titles" appearance style (`AppearanceStylePreference.titles`). That style shows one window per row with the app icon and the title (`titlesSize` in `src/switcher/Appearance.swift` sets `rowsCount = 1` and `hideThumbnails = true`). It takes no screenshots. The plan uses this style as the only style, then deletes the code that only the other styles and the extra features use.

The source tree has 295 Swift files and about 45,000 lines. The Xcode project has 744 source entries across the app target and the `unit-tests` target. There are 65 test files.

## Rules for every phase

Each phase ends with a build that compiles and tests that pass. Do these steps at the end of each phase:

1. Remove each deleted file from `alt-tab-macos.xcodeproj/project.pbxproj`. A file can be in the app target, the `unit-tests` target, or both.
2. Delete the matching triad files. For each deleted `Foo.swift`, also delete `FooSpecs.md` and `FooTests.swift` if they exist.
3. Build with the command in `ai/build.sh`.
4. Run the tests with `ai/test.sh`.
5. Commit the phase as one commit on the `tiny` branch.

The `unit-tests` target has its own source list. If you only run `ai/test.sh`, the app target does not compile. You must run both scripts.

If a git worktree has no `config/local.xcconfig`, copy it from the main checkout before you build.

This Mac runs macOS 14.6, so the newest Xcode it can run is Xcode 16.2 (Swift 6.0, macOS 15 SDK). Code that needs the macOS 26 SDK is behind `#if compiler(>=6.2)`, so an Xcode 26 build keeps it. Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` if `xcode-select` points to the Command Line Tools.

When a deleted enum case or type breaks the build, use the compiler errors as the list of call sites to fix. Do not search for call sites by hand first.

## Phase 1: lock the style to Titles

This phase changes the behavior with very little code. After it, Cmd+Tab shows the list you want, and you can test it before you delete anything.

Changes:

- In `src/switcher/Appearance.swift`, make `currentStyle` return `.titles`.
- In `src/preferences/Preferences.swift`, make `effectiveAppearanceStyle(_:)` return `.titles`.
- In `Preferences.defaultValues`, set `previewFocusedWindow` to `false` and `captureWindowsInBackground` to `false`.
- In `Preferences.screenRecordingDependentFeatures` and `anyShortcutShowsWindowCaptures`, return values that say that no feature needs Screen Recording.
- In `Preferences.defaultValues`, set the default `holdShortcut` to Cmd (`⌘`). AltTab then replaces the system app switcher.
- In `Preferences.defaultValues`, set `showWindowlessApps` to `hide`.

Result: the app stops asking for the Screen Recording permission. `PermissionCalloutResolver` asks for it only for the thumbnails style and the preview.

Test manually: press Cmd+Tab with windows from several apps, on several Spaces, with one minimized window and one fullscreen window. Each row must show the icon and the title.

## Phase 2: remove screenshots and the preview

Delete these files:

- `src/switcher/state/WindowThumbnails.swift`
- `src/events/WindowCaptureEvents.swift`
- `src/events/CaptureDiscovery.swift`
- `src/switcher/PreviewPanel.swift`

Edit these files:

- `src/switcher/state/Window.swift`, `Windows.swift`, `TrackedWindowState.swift`, and `TrackedWindowStateBridge.swift`: remove the thumbnail fields and the refresh calls.
- `src/App.swift`, `src/switcher/SwitcherSession.swift`, and `src/events/ScreenLockEvents.swift`: remove the calls to the thumbnail and preview code.
- `src/macos/api-wrappers/SkyLight.framework.swift`: remove the window capture declarations.
- `config/base.xcconfig`: remove the `-weak_framework ScreenCaptureKit` linker flag.
- `src/switcher/Appearance.swift`: delete `thumbnailsSize`, `appIconsSize`, `hideThumbnails`, and the style branches in `applyConcreteSize` and `updateFont`. Keep the values from `titlesSize`.
- Keep `AppearanceStylePreference` in this phase. The Pro code and the appearance settings still use it. Remove the enum in Phase 6, after its last users are gone.

Simplify the switcher views in `src/switcher/main-window/`:

- `TileView.swift` has 14 style checks. Keep only the row layout for `.titles`.
- `TilesView.swift` has 6 style checks. Keep one column with one row per window.
- `TileFontIconView.swift`, `TileOverView.swift`, `TileTitleView.swift`, and `TilesPanelBackgroundView.swift`: remove the other style branches.
- The traffic-light window controls in `TileOverView.swift` show only in the Thumbnails style. Remove them in this phase, with `src/kit/TrafficLightButton.swift`.
- Keep `TileGridLayout.swift`. A Titles row is 90% of the panel width, so the grid already puts one tile per row, and the arrow keys use its rows.

Remove the Screen Recording permission:

- `src/macos/SystemPermissions.swift`: remove the Screen Recording check.
- `src/macos/PermissionCalloutResolver.swift`: remove the Screen Recording callout.
- `src/secondary-windows/permission-window/PermissionsWindow.swift` and `PermissionView.swift`: show only the Accessibility permission.
- `Preferences.swift`: remove `screenRecordingPermissionSkipped`, `previewSelectedWindow`, `previewFadeInAnimation`, and `captureWindowsInBackground`.

Result: the app needs only the Accessibility permission.

## Phase 3: remove the Pro licensing and trial

Delete these folders and files:

- `src/pro/` (license, scheduling, UI, `ProFeature.swift`, `ProFeatureCopy.swift`, `ProConversionCopy.swift`)
- `src/preferences/settings-window/tabs/UpgradeTab.swift`
- `src/api/` (`Endpoints.swift`, `Secrets.swift`)

Before you delete `ProFeature.swift`, make `attemptUse()` return `true` and build once. Then inline each call site. About 33 files use `ProFeature` or `LicenseManager`.

In `Preferences.swift`, replace each `ProGatedPreferences.<name>.read()` with a direct `CachedUserDefaults` read. This affects `appearanceStyle`, `appearanceSize`, `shortcutStyle`, and `appearanceStyleOverride0`.

Also delete in this phase, because they exist only to feed the Pro prompts or to test them: `src/util/UsageStats.swift` and its tests, `src/debug/QAMenu.swift`, `QaSurfaces.swift`, `QaSheetAnimation.swift`, `Benchmark.swift`, and `src/preferences/settings-window/EmailLineWrap.swift` with its tests. Remove the license activation URL scheme (`CFBundleURLTypes`) from `Info.plist`.

Keychain warning: this phase deletes the license code. If you publish this build with the same bundle ID to people who own license keys, their keys stop working in this build. For a personal build, this does not matter.

## Phase 4: remove the extra switcher features

Search:

- `src/switcher/Search.swift` and `SearchTestable.swift`
- `src/switcher/search-discovery/`
- `src/switcher/state/SearchFieldEditing.swift` and `SearchModeResolver.swift`
- `Preferences.searchShortcut` and the search field in `TilesPanel.swift`

Input methods other than the keyboard:

- `src/events/TrackpadEvents.swift` and `GestureTriggerKernel.swift`
- `src/events/ScrollwheelEvents.swift`
- `src/switcher/main-window/DragAndDropResolver.swift` and the drop-a-file-on-a-tile feature. Keep the pass-through of a mouse-up whose mouse-down the switcher never saw, inline in `CursorEvents`, so a file drag that started before the switcher opened still ends.
- The middle-click that closes a window
- `Preferences.nextWindowGesture` and `trackpadHapticFeedbackEnabled`
- Keep `src/events/CursorEvents.swift` and `mouseHoverEnabled`. A click on a row focuses that window, and hover selection stays a preference.

Integrations:

- `src/events/CliEvents.swift` (command line control), with the QA-only hooks it drove
- `src/events/ContextMenuEvents.swift`
- Keep `src/events/DockEvents.swift`. It reads the Dock's Mission Control notifications, and the switcher uses that state to decide whether to focus a window.

Window actions inside the switcher:

- `closeWindowShortcut`, `minDeminWindowShortcut`, `toggleFullscreenWindowShortcut`, `quitAppShortcut`, and `hideShowAppShortcut` in `Preferences.swift`
- `src/switcher/ShortcutAction.swift` cases for these actions
- `src/switcher/main-window/StatusIconsView.swift`
- The action heir in `SelectionResolver` (`removalFallback`), which only served these actions

Extra shortcuts:

- Keep one hold shortcut, Cmd+Tab. Set `minShortcutCount` and `maxShortcutCount` to 1, or remove the index arrays in `Preferences.swift`.
- Remove the per-shortcut overrides: `appearanceOverrideBaseNames`, `overrideToGlobalKey`, and each `effective*` function that reads an override.
- Keep `focusWindowShortcut`, `previousWindowShortcut`, `cancelShortcut`, and the arrow keys. The switcher needs them for basic use.

Visual extras:

- Space number labels (`hideSpaceNumberLabels`)
- Colored circles (`hideColoredCircles`)
- Fade animations (`fadeOutAnimation`)
- `src/kit/WindowlessAppIndicator.swift` and `showWindowlessApps`. The list shows only real windows.

Settings for the removed features (moved here from Phase 6, because this phase removes what they configure):

- Reduce `ControlsTab.swift` to one Trigger row and the mouse hover switch. Keep its shortcut registry.
- Reduce `ShortcutEditor.swift` to the Trigger row and rename it `TriggerBinding.swift`.
- Delete `OverrideClickResolver.swift`, `AdditionalControlsSheet.swift`, `ShortcutsWhenActiveSheet.swift`, and `src/preferences/settings-window/tabs/appearance/`.
- Remove `AppearanceStylePreference`, `GesturePreference`, `WindowOrderPreference`, and `GroupAppsPreference`.

Fixed filters:

- With one shortcut, the per-shortcut filters become fixed values: all apps, all Spaces, all screens, show minimized, hidden, and fullscreen windows, and recently focused order. Remove `appsToShow`, `spacesToShow`, `screensToShow`, `showMinimizedWindows`, `showHiddenWindows`, `showFullscreenWindows`, `windowOrder`, `showAppsOrWindows`, and `showTabsAsWindows` from `Preferences.swift`. Remove the one-window-per-app mode (`ApplicationRepresentativeResolver`), which `showAppsOrWindows` turned on.

## Phase 5: remove the auxiliary product features

Delete these files:

- `src/secondary-windows/FeedbackWindow.swift`
- `src/secondary-windows/DebugWindow.swift`, `DebugMenu.swift`, and `DebugProfile.swift`
- `src/util/MoveToApplicationsFolder.swift`
- `src/vendors/SparkleDelegate.swift` and `AppCenterCrashes.swift`, with `AppCenterApplication.h` and `AppCenterApplication.m`
- `src/window-tracking/TrackingTelemetry.swift` and `TrackingTelemetryRecorder.swift`

Keep `src/debug/MainThreadStall.swift`. It is small and it helps you find latency problems.

Remove the dependencies:

- Remove `vendor/Sparkle` and `vendor/AppCenter` from the Xcode project and from the "Embed Frameworks" build phase.
- Remove the Sparkle keys from `Info.plist` (`SUPublicEDKey`, `SUEnableAutomaticChecks`, and `SUScheduledCheckInterval`).
- Remove `updatePolicy` and `crashPolicy` from `Preferences.swift`.
- Keep `vendor/ShortcutRecorder` only if the settings window still has a shortcut editor.

In `src/Menubar.swift`, remove the menu items for the deleted windows.

## Phase 6: shrink the settings window

Keep one settings page with these controls:

- Start at login
- Show the menu bar icon
- The Cmd+Tab shortcut
- Mouse hover selection
- The exceptions list (apps to ignore)

Delete these files:

- `src/preferences/settings-window/tabs/AcknowledgmentsTab.swift`
- `src/preferences/settings-window/SettingsSearch.swift`, `SettingsSearchHighlight.swift`, `SettingsSearchIndex.swift`, and `SettingsSectionSearchContent.swift`
- `src/preferences/settings-window/SidebarList.swift`, if one page replaces the sidebar

Reduce `SettingsWindow.swift` (1,344 lines) to the controls in the list above.

Delete `src/preferences/PreferencesMigrations.swift`. The app starts from the defaults and does not keep settings from an older install.

Delete the preference images for the removed styles from `resources/`. Use the `assets-optimization` skill to find unused assets.

## What to keep

Do not change these parts in the first pass. They make the list correct and fast, and they have most of the unit tests.

- `src/switcher/state/`, except the files that Phases 2 and 4 name. This holds the windows, the applications, the Spaces, the window order, and the tab groups.
- `src/window-tracking/`, except the telemetry files.
- `src/windowserver/`
- `src/events/KeyboardEvents.swift`, `RunningApplicationsEvents.swift`, `WindowServerEvents.swift`, `ScreensEvents.swift`, `SleepWakeEvents.swift`, `SystemAppearanceEvents.swift`, `PreferencesEvents.swift`, and `UserDefaultsEvents.swift`
- `src/macos/AXCallScheduler.swift`, `CGSCallScheduler.swift`, and `ProcessCallScheduler.swift`
- `src/macos/api-wrappers/`, except the capture declarations
- `src/kit/`, except the files that only deleted views use

After Phase 6, you can look at `TabGroupResolver.swift` (1,027 lines) and the exceptions code again. Tab groups and exceptions are features too, but the switcher depends on them for a correct window list.

## Localization

Keep only English. Delete every other folder in `resources/l10n/` and remove it from the Xcode project. After Phase 6, run the refresh script that the `translate-missing-l10n` skill uses to regenerate the source strings from the Swift code. Then delete the keys that no longer exist from the English file.

## Order and risk

| Phase | Risk | Why |
| --- | --- | --- |
| 1 | Low | Two return values change. No file is deleted. |
| 2 | Medium | Thumbnail state is in the window model and in the event reducer. |
| 3 | Medium | Pro gating is in about 33 files and in the preference reads. |
| 4 | Medium | Search and shortcuts connect to the keyboard event handling. |
| 5 | Low | These features are at the edge of the app. |
| 6 | Low | The settings window is separate from the switcher. |

Phases 1 to 3 give most of the result. Phases 4 to 6 reduce the code size and the number of settings.
