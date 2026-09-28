import Cocoa

class Menubar {
    static var statusItem: NSStatusItem!
    static var menu: NSMenu!
    private static var isVisibleObserver: NSKeyValueObservation?

    @discardableResult
    static func addMenuItem(_ title: String, _ action: Selector, _ keyEquivalent: String, _ symbolName: String?, _ color: NSColor? = nil, _ target: AnyObject? = nil) -> NSMenuItem {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: keyEquivalent)
        item.target = target
        if #available(macOS 26.0, *), let symbolName {
            item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            if let color {
                item.image = item.image?.withSymbolConfiguration(.init(paletteColors: [color]))
            }
        }
        return item
    }

    static func initialize() {
        menu = NSMenu()
        menu.title = App.name // perf: prevent going through expensive code-path within appkit
        addMenuItem(NSLocalizedString("Show", comment: "Menubar option"), #selector(App.showUiFromShortcut0), "", "eye", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(NSLocalizedString("Settings…", comment: "Menubar option"), #selector(App.showSettingsWindow), ",", "gear", nil, App.self)
        addMenuItem(NSLocalizedString("Check permissions…", comment: "Menubar option"), #selector(App.checkPermissions), "", "hand.raised", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(String(format: NSLocalizedString("About %@", comment: "Menubar option. %@ is AltTab"), App.name), #selector(App.showAboutWindow), "", "info.circle", nil, App.self)
        menu.addItem(NSMenuItem.separator())
        addMenuItem(String(format: NSLocalizedString("Quit %@", comment: "%@ is AltTab"), App.name), #selector(NSApplication.terminate(_:)), "q", nil) // "xmark.rectangle" is not necessary; macos automatically recognizes Quit
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button!.target = self
        statusItem.button!.action = #selector(statusItemOnClick)
        statusItem.button!.sendAction(on: [.leftMouseDown, .rightMouseDown])
        // Apply icon prefs eagerly here, while the status item is still being added to the
        // menubar. Doing it later (from PreferencesEvents.initialize) sets `button.image` after
        // the WindowServer has already laid the menubar out at its imageless default size, then
        // invalidates NSStatusBarContentView mid-FBS-scene-update — `_NSDetectedLayoutRecursion`.
        applyMenubarIconPreferences()
        observeRemovalFromMenubar()
    }

    @objc static func statusItemOnClick() {
        // NSApp.currentEvent == nil if the icon is "clicked" through VoiceOver
        if let type = NSApp.currentEvent?.type, type != .leftMouseDown {
            App.showUiFromShortcut0()
        } else {
            popUpMenu()
        }
    }

    /// Replaces `NSStatusItem.popUpStatusItemMenu`, deprecated in 10.14. Neither documented
    /// alternative works on its own: leaving `statusItem.menu` assigned makes macOS open the menu on
    /// every click, swallowing the right-click that must show the switcher, and `NSMenu.popUp` puts
    /// the menu at the wrong place on a status item (it lands over the menubar, offset sideways).
    /// Assigning the menu only for the duration of a synthesized click keeps the branch above while
    /// letting AppKit position the menu and highlight the icon. Clearing `menu` on the next line is
    /// safe because `performClick` doesn't return until menu tracking ends.
    static func popUpMenu() {
        statusItem.menu = menu
        statusItem.button!.performClick(nil)
        statusItem.menu = nil
    }

    static func menubarIconCallback(_: NSControl?) {
        // Guard: can be invoked before `Menubar.initialize()`, at which point `statusItem` is still nil.
        guard statusItem != nil else { return }
        applyMenubarIconPreferences()
        if let menubarIconDropdown = GeneralTab.menubarIconDropdown {
            menubarIconDropdown.isEnabled = Preferences.menubarIconShown
        }
    }

    static private func applyMenubarIconPreferences() {
        if Preferences.menubarIconShown {
            loadPreferredIcon()
        } else {
            statusItem.isVisible = false
        }
    }

    // The user can ⌘-drag the icon off the menubar (enabled by `.removalAllowed`). When that
    // happens, `isVisible` flips true→false and we persist the preference. Observing here in
    // `Menubar` rather than in `GeneralTab` means we react whether or not Settings is open.
    static private func observeRemovalFromMenubar() {
        statusItem.behavior = .removalAllowed
        isVisibleObserver = statusItem.observe(\.isVisible, options: [.old, .new]) { _, change in
            if change.oldValue == true && change.newValue == false {
                Preferences.set("menubarIconShown", "false")
                GeneralTab.menuIconShownToggle?.setSilently(.off)
            }
        }
    }

    /// `NSStatusBar.system.thickness`: the status item working area, 22pt on every macOS so far
    /// (the visible menubar is taller since Tahoe, but items stay in a centred 22pt band).
    /// The artwork is authored at 44pt. Handed over at that size it makes the button 44pt tall,
    /// and macOS then draws the selection as a tall block overflowing the strip instead of the pill
    /// every other menubar app gets. Any size <= 22 avoids that and renders identically, because
    /// `.scaleProportionallyUpOrDown` below refits the image into the 22pt button either way. 22 is
    /// the one that stays correct if that scaling mode ever changes: 44pt artwork at 22pt is an
    /// exact 2:1 downscale, so one artboard unit is one device pixel on a retina display.
    private static let iconSize = CGFloat(22)

    static private func loadPreferredIcon() {
        let i = Preferences.menubarIcon.indexAsString
        let image = NSImage(named: "menubar-\(i)")!
        image.isTemplate = i != "2"
        image.size = NSSize(width: iconSize, height: iconSize)
        statusItem.button!.image = image
        statusItem.isVisible = true
        statusItem.button!.imageScaling = .scaleProportionallyUpOrDown
    }
}
