enum MenubarIconPreference: CaseIterable, MacroPreference {
    case outlined
    case filled
    case colored

    var localizedString: LocalizedString {
        switch self {
            // these spaces are different from each other; they have to be unique
            case .outlined: return " "
            case .filled: return " "
            case .colored: return " "
        }
    }
}

enum ShortcutStylePreference: CaseIterable, MacroPreference {
    case focusOnRelease
    case doNothingOnRelease

    var localizedString: LocalizedString {
        switch self {
            case .focusOnRelease: return NSLocalizedString("Focus", comment: "")
            case .doNothingOnRelease: return NSLocalizedString("Hold", comment: "")
        }
    }
}

enum ShowHowPreference: CaseIterable, MacroPreference {
    case show
    case hide
    case showAtTheEnd

    var localizedString: LocalizedString {
        switch self {
            case .show: return NSLocalizedString("Show", comment: "")
            case .showAtTheEnd: return NSLocalizedString("Show at the end", comment: "")
            case .hide: return NSLocalizedString("Hide", comment: "")
        }
    }
}

enum AppsToShowPreference: CaseIterable, MacroPreference {
    case all
    case active
    case nonActive

    var localizedString: LocalizedString {
        switch self {
            case .all: return NSLocalizedString("All apps", comment: "")
            case .active: return NSLocalizedString("Active app", comment: "")
            case .nonActive: return NSLocalizedString("Non-active apps", comment: "")
        }
    }
}

enum SpacesToShowPreference: CaseIterable, MacroPreference {
    case all
    case visible
    case nonVisible

    var localizedString: LocalizedString {
        switch self {
            case .all: return NSLocalizedString("All Spaces", comment: "")
            case .visible: return NSLocalizedString("Visible Spaces", comment: "")
            case .nonVisible: return NSLocalizedString("Non-visible Spaces", comment: "")
        }
    }
}

enum ScreensToShowPreference: CaseIterable, MacroPreference {
    case all
    case showingAltTab

    var localizedString: LocalizedString {
        switch self {
            case .all: return NSLocalizedString("All screens", comment: "")
            case .showingAltTab: return NSLocalizedString("Screen showing CmdTab", comment: "")
        }
    }
}

enum ShowOnScreenPreference: CaseIterable, MacroPreference {
    case active
    case includingMouse
    case includingMenubar

    var localizedString: LocalizedString {
        switch self {
            case .active: return NSLocalizedString("Active screen", comment: "")
            case .includingMouse: return NSLocalizedString("Screen including mouse", comment: "")
            case .includingMenubar: return NSLocalizedString("Screen including menu bar", comment: "")
        }
    }
}

enum TitleTruncationPreference: CaseIterable, MacroPreference {
    case start
    case middle
    case end

    var localizedString: LocalizedString {
        switch self {
            case .start: return NSLocalizedString("Start", comment: "")
            case .middle: return NSLocalizedString("Middle", comment: "")
            case .end: return NSLocalizedString("End", comment: "")
        }
    }
}

/// Mirrors `showTabsAsWindows` as a 2-case enum so the per-shortcut UI renders a dropdown rather
/// than a switch. Persistence is by index (`"0"` / `"1"`), so `singleWindow` MUST stay at index 0
/// and `separateWindows` at index 1 — the migration that converts the old `"true"`/`"false"` Bool
/// strings relies on that mapping (true → separateWindows = "1", false → singleWindow = "0").
enum GroupTabsPreference: CaseIterable, MacroPreference {
    case singleWindow
    case separateWindows

    var localizedString: LocalizedString {
        switch self {
            case .singleWindow: return NSLocalizedString("Show single window for all tabs", comment: "")
            case .separateWindows: return NSLocalizedString("Show separate window for each tab", comment: "")
        }
    }
}

enum CursorFollowFocus: CaseIterable, MacroPreference {
    case never
    case always
    case differentScreen

    var localizedString: LocalizedString {
        switch self {
            case .never: return NSLocalizedString("Never", comment: "")
            case .always: return NSLocalizedString("Always", comment: "")
            case .differentScreen: return NSLocalizedString("Only on different screen", comment: "")
        }
    }
}

enum ShowTitlesPreference: CaseIterable, MacroPreference {
    case windowTitle
    case appName
    case appNameAndWindowTitle

    var localizedString: LocalizedString {
        switch self {
            case .windowTitle: return NSLocalizedString("Window Title", comment: "")
            case .appName: return NSLocalizedString("Application Name", comment: "")
            case .appNameAndWindowTitle: return NSLocalizedString("Application Name - Window Title", comment: "")
        }
    }
}

/// Point size of the window titles in the switcher. Stored by case index, so append new sizes rather than
/// inserting them, or a stored index would name a different size.
enum FontSizePreference: Int, CaseIterable, MacroPreference {
    case pt11 = 11, pt12 = 12, pt13 = 13, pt14 = 14, pt15 = 15, pt16 = 16, pt18 = 18, pt20 = 20, pt22 = 22, pt24 = 24

    var points: CGFloat { CGFloat(rawValue) }
    var localizedString: LocalizedString { String(format: NSLocalizedString("%d pt", comment: "A size in points"), rawValue) }
}

/// Point size of the app icons in the switcher. Stored by case index, like `FontSizePreference`.
enum IconSizePreference: Int, CaseIterable, MacroPreference {
    case pt16 = 16, pt18 = 18, pt20 = 20, pt24 = 24, pt28 = 28, pt30 = 30, pt32 = 32, pt36 = 36, pt40 = 40, pt48 = 48

    var points: CGFloat { CGFloat(rawValue) }
    var localizedString: LocalizedString { String(format: NSLocalizedString("%d pt", comment: "A size in points"), rawValue) }
}

enum AppearanceThemePreference: CaseIterable, MacroPreference {
    case light
    case dark
    case system

    var localizedString: LocalizedString {
        switch self {
            case .light: return NSLocalizedString("Light", comment: "")
            case .dark: return NSLocalizedString("Dark", comment: "")
            case .system: return NSLocalizedString("System", comment: "")
        }
    }
}

enum ExceptionHidePreference: String/* required for jsonEncode */, CaseIterable, MacroPreference, Codable {
    case none = "0"
    case always = "1"
    case whenNoOpenWindow = "2"
    case windowTitleContains = "3"

    var localizedString: LocalizedString {
        switch self {
            case .none: return ""
            case .always: return NSLocalizedString("Always", comment: "")
            case .whenNoOpenWindow: return NSLocalizedString("When no open window", comment: "")
            case .windowTitleContains: return NSLocalizedString("Window title contains", comment: "")
        }
    }
}

enum ExceptionIgnorePreference: String/* required for jsonEncode */, CaseIterable, MacroPreference, Codable {
    case none = "0"
    case always = "1"
    case whenFullscreen = "2"

    var localizedString: LocalizedString {
        switch self {
            case .none: return ""
            case .always: return NSLocalizedString("Always", comment: "")
            case .whenFullscreen: return NSLocalizedString("When fullscreen", comment: "")
        }
    }
}

// MacroPreference are collection of values derived from a single key
// we don't want to store every value in UserDefaults as the user could change them and contradict the macro
protocol MacroPreference {
    var localizedString: LocalizedString { get }
}

typealias LocalizedString = String
