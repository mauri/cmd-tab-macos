import Cocoa

class GeneralTab {
    static var menubarIconDropdown: NSPopUpButton?
    static var menuIconShownToggle: Switch?

    static func initTab() -> NSView {
        let startAtLogin = TableGroupView.Row(leftTitle: NSLocalizedString("Start at login", comment: ""),
            rightViews: [LabelAndControl.makeSwitch("startAtLogin")])
        menubarIconDropdown = LabelAndControl.makeDropdown("menubarIcon", MenubarIconPreference.allCases)
        menuIconShownToggle = LabelAndControl.makeSwitch("menubarIconShown")
        let menubarIcon = TableGroupView.Row(leftTitle: NSLocalizedString("Menubar icon", comment: ""),
            rightViews: [
                menubarIconDropdown!,
                menuIconShownToggle!,
            ])
        for i in 0..<MenubarIconPreference.allCases.count {
            let image = NSImage.initCopy("menubar-\(i)")
            image.isTemplate = i < 2
            image.size = NSSize(width: 22, height: 22)
            menubarIconDropdown!.item(at: i)!.image = image
        }
        let cell = menubarIconDropdown!.cell! as! NSPopUpButtonCell
        cell.bezelStyle = .regularSquare
        cell.arrowPosition = .arrowAtBottom
        cell.imagePosition = .imageOverlaps
        let fontSize = TableGroupView.Row(leftTitle: NSLocalizedString("Font size", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("fontSize", FontSizePreference.allCases)])
        let iconSize = TableGroupView.Row(leftTitle: NSLocalizedString("Icon size", comment: ""),
            rightViews: [LabelAndControl.makeDropdown("iconSize", IconSizePreference.allCases)])
        let table = TableGroupView(width: SettingsWindow.contentWidth)
        table.addRow(startAtLogin)
        table.addRow(menubarIcon)
        table.addNewTable()
        table.addRow(fontSize)
        table.addRow(iconSize)
        return TableGroupSetView(originalViews: [table], padding: 0, bottomPadding: 0)
    }

    static func cleanup() {
        menubarIconDropdown = nil
        menuIconShownToggle = nil
    }

    static func refreshControlsFromPreferences() {
        menubarIconDropdown?.selectItem(at: CachedUserDefaults.intFromMacroPref("menubarIcon", MenubarIconPreference.allCases))
        menubarIconDropdown?.isEnabled = Preferences.menubarIconShown
    }
}
