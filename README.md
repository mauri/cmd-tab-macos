# CmdTab

CmdTab replaces the macOS app switcher with a window switcher. When you press Cmd+Tab, it shows a vertical list with one row for each open window. Each row shows the app icon and the window title.

CmdTab is a reduced fork of [AltTab](https://github.com/lwouis/alt-tab-macos). It has no window screenshots, no search, no gestures, no licensing, and no automatic updates. It needs only the Accessibility permission.

## Requirements

- macOS 12 or later
- Xcode 16.2 or later, installed in `/Applications`
- An administrator account, for the one-time setup

## One-time setup

### Select Xcode

The build scripts use `xcodebuild`, which needs the full Xcode, not the Command Line Tools.

1. Open Xcode once, and let it install its components.
2. Select Xcode as the active developer directory:

   ```sh
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   ```

3. Make sure that the change took effect:

   ```sh
   xcode-select -p
   xcodebuild -version
   ```

The first command must print `/Applications/Xcode.app/Contents/Developer`.

### Create the signing certificate

Debug builds are signed with a self-signed certificate named "Local Self-Signed". macOS ties the Accessibility permission to this signature. A stable signature keeps the permission across rebuilds.

1. From the repository root, run the setup script:

   ```sh
   scripts/codesign/setup_local.sh
   ```

2. When macOS asks for your password, enter it. The script adds the certificate to your login keychain and trusts it for code signing.
3. Make sure that the certificate is valid:

   ```sh
   security find-identity -v -p codesigning
   ```

The output must list `"Local Self-Signed"`. The certificate is valid for 10 years.

The script leaves the files `codesign.conf`, `codesign.crt`, `codesign.key`, and `codesign.p12` in the repository root. Git ignores them. You can delete them after the setup.

## Build

From the repository root, run:

```sh
ai/build.sh
```

The script builds the Debug configuration. The app is written to:

```
DerivedData/Build/Products/Debug/CmdTab.app
```

If the build fails with "No certificate matching 'Local Self-Signed' found", do the certificate setup again.

## Build a release

From the repository root, run:

```sh
scripts/build_app.sh
```

The script builds the Release configuration: optimized, for Apple silicon and Intel, and signed with "Local Self-Signed". The app is written to:

```
DerivedData/Build/Products/Release/CmdTab.app
```

To make a zip file that you can share, run:

```sh
ditto -c -k --keepParent DerivedData/Build/Products/Release/CmdTab.app CmdTab.zip
```

The app is not notarized, because notarization needs an Apple Developer ID. On another Mac, Gatekeeper blocks the first launch. To open it, right-click the app and click Open, or allow it in System Settings > Privacy & Security.

## Run the tests

```sh
ai/test.sh
```

The tests run without the app and without code signing.

## Launch

1. If AltTab or another app uses Cmd+Tab, quit it. Two apps cannot use the same shortcut.
2. Open the build:

   ```sh
   open DerivedData/Build/Products/Debug/CmdTab.app
   ```

3. When the permissions window opens, click "Open Accessibility Settings".
4. In System Settings, turn on the CmdTab entry.

After a few seconds, the permissions window closes and the CmdTab icon shows in the menu bar.

To see the debug log, launch the app with this script:

```sh
ai/run.sh
```

The script shows the log in the terminal and keeps a copy in `/tmp/cmdtab-run.log`. It launches the app through `open`, because macOS judges an app started directly from a shell by the permissions of the terminal. To stop the app, quit it from its menu bar icon.

### If the Accessibility permission does not take effect

1. Quit the app.
2. Reset the permission for the bundle ID `ar.x86.cmdtab`:

   ```sh
   tccutil reset Accessibility ar.x86.cmdtab
   ```

3. Open the build again, and turn on the new CmdTab entry.

If you replace the signing certificate, the permission stops working in the same way. The reset fixes that case too.

## Use

| Action | Keys or mouse |
| --- | --- |
| Show the switcher and select the next window | Hold Cmd, then press Tab |
| Select the previous window | Shift, while you hold Cmd |
| Move the selection | Arrow keys |
| Focus the selected window | Release Cmd, or press Return |
| Close the switcher without a change | Esc |
| Focus a window with the mouse | Click its row |

The list shows the windows of all apps, on all Spaces and screens, in the order that you last used them. Minimized, hidden, and fullscreen windows are included. Apps without an open window are not shown.

## Settings

To open the settings, click the CmdTab icon in the menu bar, then click "Settings…". The settings page has these controls:

- The shortcut that shows the switcher
- Mouse hover selection
- Start at login
- The menu bar icon
- The font size of the window titles, from 11 to 24 points
- The size of the app icons, from 16 to 48 points
- The exceptions list, to hide an app from the switcher or to turn off the shortcut in an app

## Licence

GPL-3.0. See [LICENCE.md](LICENCE.md).

CmdTab is a modified version of [AltTab](https://github.com/lwouis/alt-tab-macos) by Louis Pontoise and its contributors. The modifications started on 2026-09-28 and are in the Git history of this repository. They remove features and rename the app. CmdTab is not affiliated with the AltTab project.
