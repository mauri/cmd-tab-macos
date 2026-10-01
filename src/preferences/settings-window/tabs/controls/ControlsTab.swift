import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

/// Coordinator for the Controls section: the shortcut trigger row and the mouse hover switch. Also keeps
/// the global shortcut-registry logic (`shortcuts` dict, `addShortcut` / `removeShortcutIfExists` /
/// `applyShortcutPreference`) and the arrow/vim helpers consumed by other modules.
class ControlsTab {
    // MARK: - Public runtime state consumed by other modules

    /// Runtime model of all globally-bound shortcuts, keyed by their identifier
    /// (`holdShortcut`, `nextWindowShortcut`, etc.). Driven by `applyShortcutPreference`.
    /// Read by KeyboardEvents, KeyRepeatTimer, ATShortcut, CustomRecorderControl, and the conflict detectors.
    static var shortcuts = [String: ATShortcut]()

    /// UI lookup: for any recorder currently displayed in Settings, its (control, label string).
    /// Populated by `TriggerBinding.bind`.
    static var shortcutControls = [String: (CustomRecorderControl, String)]()

    private static let labelMouse = NSLocalizedString("Select windows on mouse hover", comment: "")
    private static let staticManagedShortcutPreferences = [
        "focusWindowShortcut", "previousWindowShortcut", "cancelShortcut",
    ]
    /// Canonical id → localized label for the always-active ("when active") shortcuts, used by
    /// `conflictLabel(_:)` to name a conflicting shortcut.
    static let staticShortcutLabels = [
        "focusWindowShortcut": NSLocalizedString("Focus selected window", comment: ""),
        "previousWindowShortcut": NSLocalizedString("Select previous window", comment: ""),
        "cancelShortcut": NSLocalizedString("Cancel", comment: ""),
    ]
    private static let arrowKeys = ["←", "→", "↑", "↓"]
    private static let arrowKeyCodes: Set<KeyCode> = [.leftArrow, .rightArrow, .upArrow, .downArrow]
    private static let vimKeyActions = [
        "h": "vimCycleLeft",
        "l": "vimCycleRight",
        "k": "vimCycleUp",
        "j": "vimCycleDown",
    ]


    private static var trigger: TriggerBinding?

    // MARK: - Initialization / teardown

    static func initializePreferencesDependentState() {
        applyActiveShortcutPreferences()
        staticManagedShortcutPreferences.forEach { applyShortcutPreference($0) }
        applyArrowKeysPreferenceWithoutDialogs()
        applyVimKeysPreferenceWithoutDialogs()
    }

    static func initTab() -> NSView {
        let binding = TriggerBinding()
        binding.bind(toShortcut: 0)
        trigger = binding
        let table = TableGroupView(width: SettingsWindow.settingsColumnWidth)
        table.addRow(TableGroupView.Row(leftTitle: TriggerBinding.triggerLabel, rightViews: [binding.view]))
        table.addRow(leftText: labelMouse, rightViews: [LabelAndControl.makeSwitch("mouseHoverEnabled")])
        initializeShortcutRecorderState(0)
        let view = TableGroupSetView(originalViews: [table], padding: 0, bottomPadding: 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: view.fittingSize.width).isActive = true
        return view
    }

    static func cleanup() {
        shortcutControls.removeAll()
        trigger = nil
    }

    // MARK: - Preference-change routing

    static func preferenceChanged(_ key: String) {
        switch key {
        case let k where isShortcutPreferenceKey(k):
            if Preferences.nameToIndex(k) == 0 { trigger?.bind(toShortcut: 0) }
            applyShortcutPreference(k)
        case let k where staticManagedShortcutPreferences.contains(k):
            applyShortcutPreference(k)
        case "arrowKeysEnabled":
            applyArrowKeysPreferenceWithoutDialogs()
        case "vimKeysEnabled":
            applyVimKeysPreferenceWithoutDialogs()
        default:
            break
        }
    }

    static func inputSourceChanged() {
        refreshShortcutControlsDisplay()
    }

    private static func isShortcutPreferenceKey(_ key: String) -> Bool {
        return (0..<Preferences.maxShortcutCount).contains(where: { index in
            ["holdShortcut", "nextWindowShortcut"].contains { key == Preferences.indexToName($0, index) }
        })
    }

    // MARK: - Shortcut registry (global keyboard binding)

    private static func applyActiveShortcutPreferences() {
        (0..<Preferences.maxShortcutCount).forEach { index in
            ["holdShortcut", "nextWindowShortcut"].forEach { base in
                let key = Preferences.indexToName(base, index)
                if index < Preferences.shortcutCount {
                    applyShortcutPreference(key)
                } else {
                    removeShortcutIfExists(key)
                }
            }
        }
    }

    private static func addShortcut(_ triggerPhase: ShortcutTriggerPhase, _ scope: ShortcutScope, _ shortcut: Shortcut, _ controlId: String, _ index: Int?) {
        let atShortcut = ATShortcut(shortcut, controlId, scope, triggerPhase, index)
        removeShortcutIfExists(controlId)
        shortcuts[controlId] = atShortcut
        if scope == .global {
            KeyboardEvents.addGlobalShortcut(controlId, atShortcut.shortcut)
            ControlsTab.toggleNativeCommandTabIfNeeded()
        }
        recomputeEscapeAbsorption()
    }

    /// Issue #5585. The shared cghidEventTap absorbs Esc keyDown only when a configured shortcut
    /// binds Escape; otherwise Esc passes through to the active app unchanged.
    static func recomputeEscapeAbsorption() {
        KeyboardEvents.anyShortcutUsesEscape = shortcuts.values.contains { $0.shortcut.carbonKeyCode == kVK_Escape }
        KeyboardEvents.updateEscapeAbsorptionTap()
    }

    /// Thin adapter over `NativeHotkeyResolver.resolve` — builds the snapshot inputs from the live
    /// shortcut registry and applies the resolver's verdict via the symbolic-hotkey API. See
    /// `NativeHotkeyResolverSpecs.md` for the kernel's invariants and #5653's root cause.
    static func toggleNativeCommandTabIfNeeded() {
        let snapshots = shortcuts.values.map { ShortcutSnapshot(modifiers: $0.shortcut.carbonModifierFlags, keyCode: $0.shortcut.carbonKeyCode) }
        let holdShortcutModifiers: [UInt32] = (0..<Preferences.holdShortcut.count).compactMap { i in
            shortcuts[Preferences.indexToName("holdShortcut", i)]?.shortcut.carbonModifierFlags
        }
        let result = NativeHotkeyResolver.resolve(shortcuts: snapshots, holdShortcutModifiers: holdShortcutModifiers)
        setNativeCommandTabEnabled(false, Array(result.disable))
        setNativeCommandTabEnabled(true, Array(result.enable))
    }

    @objc static func shortcutChangedCallback(_ sender: NSControl) {
        let controlId = sender.identifier!.rawValue
        if isShortcutPreferenceKey(controlId) && Preferences.nameToIndex(controlId) >= Preferences.shortcutCount {
            return
        }
        if controlId.hasPrefix("holdShortcut") {
            let i = Preferences.nameToIndex(controlId)
            guard let shortcut = Preferences.shortcut(controlId) else {
                removeShortcutIfExists(controlId)
                return
            }
            addShortcut(.up, .global, shortcut, controlId, i)
            if let nextWindowShortcut = shortcutControls[Preferences.indexToName("nextWindowShortcut", i)]?.0 {
                nextWindowShortcut.restrictModifiers([(sender as! CustomRecorderControl).objectValue!.modifierFlags])
                shortcutChangedCallback(nextWindowShortcut)
            }
        } else {
            let newShortcut = combineHoldAndNextWindow(controlId, sender)
            if newShortcut == nil {
                removeShortcutIfExists(controlId)
                restrictModifiersOfHoldShortcut(controlId, [])
                (sender as! CustomRecorderControl).objectValue = nil
            } else {
                addShortcut(.down, controlId.hasPrefix("nextWindowShortcut") ? .global : .local, newShortcut!, controlId, nil)
                restrictModifiersOfHoldShortcut(controlId, [(sender as! CustomRecorderControl).objectValue!.modifierFlags])
            }
        }
    }

    private static func restrictModifiersOfHoldShortcut(_ controlId: String, _ modifiers: NSEvent.ModifierFlags) {
        if controlId.hasPrefix("nextWindowShortcut") {
            let i = Preferences.nameToIndex(controlId)
            if let holdShortcut = shortcutControls[Preferences.indexToName("holdShortcut", i)]?.0 {
                holdShortcut.restrictModifiers(modifiers)
            }
        }
    }

    static func combineHoldAndNextWindow(_ controlId: String, _ sender: NSControl) -> Shortcut? {
        guard let baseShortcut = (sender as! RecorderControl).objectValue else { return nil }
        if controlId.starts(with: "nextWindowShortcut") {
            let holdShortcut = Preferences.shortcut(Preferences.indexToName("holdShortcut", Preferences.nameToIndex(controlId)))
            return combineShortcuts(holdShortcut, baseShortcut)
        }
        return baseShortcut
    }

    /// Human-readable label for the action bound to `id`, resolved purely from the model — the id's
    /// shape plus `staticShortcutLabels` — NOT from `shortcutControls`. This is what lets the conflict
    /// dialog name a shortcut that isn't currently displayed in the recycled editor (which keeps only
    /// the on-screen shortcut in `shortcutControls`). Returns nil for ids with no known action.
    ///
    /// The shortcut's hold and "and press" both belong to its Trigger, so they resolve to "Trigger".
    static func conflictLabel(_ id: String) -> String? {
        if arrowKeys.contains(id) { return NSLocalizedString("Arrow keys", comment: "") }
        if vimKeyActions.values.contains(id) { return NSLocalizedString("Vim keys", comment: "") }
        if id.hasPrefix("holdShortcut") || id.hasPrefix("nextWindowShortcut") {
            return TriggerBinding.triggerLabel
        }
        return staticShortcutLabels[id]
    }

    /// Clear the shortcut bound to `id` and let the normal preference-change pipeline reconcile the
    /// registry and UI. Used by the conflict dialog's "Unassign existing shortcut and continue" for a
    /// shortcut that may not be on screen, so it goes through `Preferences` (cached UserDefaults)
    /// rather than mutating a live recorder. If that recorder happens to be displayed, sync it too.
    ///
    /// For a numbered shortcut's Trigger the hold can't stand alone, so "unassign" clears the "and
    /// press" (nextWindowShortcut) part — e.g. ⌥+Tab becomes ⌥+(unassigned) — whether the conflict
    /// was reported against the hold or the press.
    static func unassignShortcut(_ id: String) {
        let keyToClear = (id.hasPrefix("holdShortcut") || id.hasPrefix("nextWindowShortcut"))
            ? Preferences.indexToName("nextWindowShortcut", Preferences.nameToIndex(id))
            : id
        Preferences.setShortcut(keyToClear, nil)
        shortcutControls[keyToClear]?.0.objectValue = nil
    }

    /// The prompt both conflict detectors raise: unassign whatever holds the shortcut, or cancel
    /// (Esc). `true` means the user chose to unassign.
    static func confirmUnassigningConflict(_ informativeText: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("Conflicting shortcut", comment: "")
        alert.informativeText = informativeText
        alert.addButton(withTitle: NSLocalizedString("Unassign existing shortcut and continue", comment: "")).setAccessibilityFocused(true)
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "")).keyEquivalent = "\u{1b}"
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// An action's name must not be split across lines by the alert's own wrapping.
    static func nonBreaking(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    private static func removeShortcutIfExists(_ controlId: String) {
        if let atShortcut = shortcuts[controlId] {
            if atShortcut.scope == .global {
                KeyboardEvents.removeGlobalShortcut(controlId, atShortcut.shortcut)
            }
            shortcuts.removeValue(forKey: controlId)
            if atShortcut.scope == .global {
                ControlsTab.toggleNativeCommandTabIfNeeded()
            }
            recomputeEscapeAbsorption()
        }
    }

    private static func applyShortcutPreference(_ controlId: String) {
        if isShortcutPreferenceKey(controlId) && Preferences.nameToIndex(controlId) >= Preferences.shortcutCount {
            removeShortcutIfExists(controlId)
            return
        }
        if controlId.hasPrefix("holdShortcut") {
            applyHoldShortcutPreference(controlId)
            applyShortcutPreference(Preferences.indexToName("nextWindowShortcut", Preferences.nameToIndex(controlId)))
            return
        }
        guard let shortcut = combinedShortcut(controlId) else {
            removeShortcutIfExists(controlId)
            restrictModifiersOfHoldShortcut(controlId, [])
            return
        }
        addShortcut(.down, controlId.hasPrefix("nextWindowShortcut") ? .global : .local, shortcut, controlId, nil)
        restrictModifiersOfHoldShortcut(controlId, [shortcut.modifierFlags])
    }

    private static func applyHoldShortcutPreference(_ controlId: String) {
        let i = Preferences.nameToIndex(controlId)
        guard let shortcut = Preferences.shortcut(controlId) else {
            removeShortcutIfExists(controlId)
            return
        }
        addShortcut(.up, .global, shortcut, controlId, i)
    }

    private static func combinedShortcut(_ controlId: String) -> Shortcut? {
        guard let baseShortcut = Preferences.shortcut(controlId) else { return nil }
        if controlId.starts(with: "nextWindowShortcut") {
            let holdShortcut = Preferences.shortcut(Preferences.indexToName("holdShortcut", Preferences.nameToIndex(controlId)))
            return combineShortcuts(holdShortcut, baseShortcut)
        }
        return baseShortcut
    }

    private static func combineShortcuts(_ holdShortcut: Shortcut?, _ baseShortcut: Shortcut) -> Shortcut {
        guard let holdShortcut else { return baseShortcut }
        return Shortcut(code: baseShortcut.keyCode, modifierFlags: [holdShortcut.modifierFlags, baseShortcut.modifierFlags], characters: baseShortcut.characters, charactersIgnoringModifiers: baseShortcut.charactersIgnoringModifiers)
    }

    private static func applyArrowKeysPreferenceWithoutDialogs() {
        guard Preferences.arrowKeysEnabled else {
            arrowKeys.forEach { removeShortcutIfExists($0) }
            return
        }
        if hasArrowKeysConflictWithoutUi() {
            arrowKeys.forEach { removeShortcutIfExists($0) }
            Preferences.set("arrowKeysEnabled", "false", false)
            return
        }
        arrowKeys.forEach { addShortcut(.down, .local, Shortcut(keyEquivalent: $0)!, $0, nil) }
    }

    private static func hasArrowKeysConflictWithoutUi() -> Bool {
        return shortcuts.values.contains {
            guard arrowKeyCodes.contains($0.shortcut.keyCode) else { return false }
            return !arrowKeys.contains($0.id)
        }
    }

    private static func applyVimKeysPreferenceWithoutDialogs() {
        guard Preferences.vimKeysEnabled else {
            vimKeyActions.forEach { removeShortcutIfExists($1) }
            return
        }
        if hasVimKeysConflictWithoutUi() {
            vimKeyActions.forEach { removeShortcutIfExists($1) }
            Preferences.set("vimKeysEnabled", "false", false)
            return
        }
        vimKeyActions.forEach { addShortcut(.down, .local, Shortcut(keyEquivalent: $0)!, $1, nil) }
    }

    private static func hasVimKeysConflictWithoutUi() -> Bool {
        return shortcuts.values.contains {
            if let key = $0.shortcut.characters, vimKeyActions.keys.contains(key) {
                return !vimKeyActions.values.contains($0.id)
            }
            return false
        }
    }

    // MARK: - Recorder lifecycle

    private static func initializeShortcutRecorderState(_ index: Int) {
        guard index < Preferences.shortcutCount else { return }
        let holdControlId = Preferences.indexToName("holdShortcut", index)
        let nextControlId = Preferences.indexToName("nextWindowShortcut", index)
        if let holdShortcut = shortcutControls[holdControlId]?.0 {
            holdShortcut.objectValue = Preferences.shortcut(holdControlId)
            shortcutChangedCallback(holdShortcut)
        }
        if let nextWindowShortcut = shortcutControls[nextControlId]?.0 {
            nextWindowShortcut.objectValue = Preferences.shortcut(nextControlId)
            shortcutChangedCallback(nextWindowShortcut)
        }
    }

    private static func refreshShortcutControlsDisplay() {
        shortcutControls.values.forEach {
            $0.0.needsDisplay = true
            $0.0.invalidateIntrinsicContentSize()
        }
    }
}
