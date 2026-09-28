import Cocoa

/// Side-effect dispatcher for preference changes. Each branch of `preferenceChanged(_:)`
/// calls into a domain-specific owner (Menubar, LoginItem)
/// rather than implementing the side effect inline. Over time each call-site
/// should subscribe directly to its own preference; this file is a transition scaffold.
class PreferencesEvents {
    private static var initialized = false
    private static let preferencesRequiringUiReset = [
        "appearanceSize",
        "appearanceTheme",
        "showOnScreen",
    ]

    static func initialize() {
        guard !initialized else { return }
        initialized = true
        ControlsTab.initializePreferencesDependentState()
        #if DEBUG
        guard !Preferences.qaPristine else { return }
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            LoginItem.applyCurrentPreference()
        }
    }

    static func preferenceChanged(_ key: String) {
        if !initialized {
            if key == "startAtLogin" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    LoginItem.applyCurrentPreference()
                }
            }
            return
        }
        ControlsTab.preferenceChanged(key)
        switch key {
        case "menubarIcon", "menubarIconShown": applyMenubarPreferencesIfReady()
        case "startAtLogin": LoginItem.applyCurrentPreference()
        case let k where preferencesRequiringUiReset.contains(k): App.resetPreferencesDependentComponents()
        default: break
        }
    }

    private static func applyMenubarPreferencesIfReady() {
        guard Menubar.statusItem != nil else { return }
        Menubar.menubarIconCallback(nil)
    }
}
