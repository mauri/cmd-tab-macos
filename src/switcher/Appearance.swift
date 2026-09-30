import Cocoa

class Appearance {
    // size
    static var maxWidthOnScreen = CGFloat(1000)
    static var iconSize = CGFloat(1000)
    static var fontHeight = CGFloat(3)
    static var font = NSFont.systemFont(ofSize: fontHeight)

    // size: constants
    static let windowPadding = CGFloat(18)
    static let windowCornerRadius = CGFloat(23)
    static let cellCornerRadius = CGFloat(10)
    static let edgeInsetsSize = CGFloat(7)
    static let windowMinWidthInRow = CGFloat(0.6)
    static let windowMaxWidthInRow = CGFloat(0.9)
    static let maxHeightOnScreen = CGFloat(0.8)
    static let interCellPadding = CGFloat(1)
    static let intraCellPadding = CGFloat(5)
    static let appIconLabelSpacing = CGFloat(2)

    // theme
    static var fontColor = NSColor.red
    static var imagesShadowColor = NSColor.red // for icon and windowless images
    static var material = LegacyMaterial.ultraDark

    // theme: constants
    static let highlightBorderWidth = CGFloat(2)
    static let enablePanelShadow = true
    static var highlightFocusedBackgroundColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.2) } }
    static var highlightHoveredBackgroundColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.1) } }
    static var highlightFocusedBorderColor: NSColor { get { NSColor.systemAccentColor } }
    static var highlightHoveredBorderColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.7) } }

    static var currentTheme: AppearanceThemePreference {
        let theme = Preferences.appearanceTheme
        return theme == .system ? NSAppearance.currentDrawing().getThemeName() : theme
    }

    static func update() {
        updateSize()
        updateTheme()
    }

    private static func updateSize() {
        maxWidthOnScreen = AppearanceTestable.comfortableWidth(NSScreen.preferred.physicalSize().map { $0.width })
        iconSize = Preferences.iconSize.points
        fontHeight = Preferences.fontSize.points
        updateFont()
    }

    private static func updateTheme() {
        if currentTheme == .dark {
            darkTheme()
        } else {
            lightTheme()
        }
    }

    private static func updateFont() {
        if #available(macOS 26.0, *) {
            font = NSFont.systemFont(ofSize: fontHeight, weight: .medium)
        } else {
            font = NSFont.systemFont(ofSize: fontHeight)
        }
    }

    private static func lightTheme() {
        fontColor = .black.withAlphaComponent(0.8)
        imagesShadowColor = .gray.withAlphaComponent(0.8)
        material = LegacyMaterial.mediumLight
    }

    private static func darkTheme() {
        fontColor = .white.withAlphaComponent(0.85)
        imagesShadowColor = .gray.withAlphaComponent(0.8)
        material = LegacyMaterial.dark
    }
}

/// The only `NSVisualEffectView.Material` values that pin light or dark explicitly. Deprecated in
/// 10.14 in favour of semantic materials, which we can't use: those follow the view's
/// `NSAppearance`, whereas our theme comes from the user's own preference (see `updateTheme`).
/// Referenced by rawValue because naming the cases trips `SWIFT_TREAT_WARNINGS_AS_ERRORS`.
enum LegacyMaterial {
    static let dark = NSVisualEffectView.Material(rawValue: 2)!
    static let mediumLight = NSVisualEffectView.Material(rawValue: 8)!
    static let ultraDark = NSVisualEffectView.Material(rawValue: 9)!
}
