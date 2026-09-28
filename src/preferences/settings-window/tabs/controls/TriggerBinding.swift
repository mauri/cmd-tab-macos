import Cocoa
import ShortcutRecorder

// MARK: - Trigger row (hold + next-window recorders)

/// The Trigger row owns two recorders (hold + next-window). They have a cross-reference: the
/// next-window recorder is restricted to the modifiers of the hold key. `bind` sets both
/// recorders' identifiers, refreshes both displayed values, and syncs `shortcutControls` so other
/// modules (CustomRecorderControl, the conflict detector) find the right control.
final class TriggerBinding {
    static let triggerLabel = NSLocalizedString("Trigger", comment: "")
    /// Fixed height for the Trigger row content (recorder + labels). Pinned rather than derived
    /// from the stack's fitting size: `RecorderControl`'s intrinsic height isn't guaranteed to be
    /// set when `TableGroupView.setMainRow` snapshots it.
    private static let rowContentHeight: CGFloat = 22
    let view: NSView
    private let holdRecorder: CustomRecorderControl
    private let nextRecorder: CustomRecorderControl
    private let andPressLabel: NSTextField
    private static let holdLabelText = NSLocalizedString("Hold", comment: "")
    private static let andPressText = NSLocalizedString("and press", comment: "")
    // The next-window recorder's human-readable name, stored alongside it in `shortcutControls`.
    private static let selectNextText = NSLocalizedString("Select next window", comment: "")
    private var currentIndex: Int = -1

    init() {
        // Placeholder identifier — replaced in bind().
        holdRecorder = CustomRecorderControl(nil, false, "holdShortcut0")
        nextRecorder = CustomRecorderControl(nil, true, "nextWindowShortcut0")

        let holdLabelField = LabelAndControl.makeLabel(TriggerBinding.holdLabelText)
        andPressLabel = LabelAndControl.makeLabel(TriggerBinding.andPressText)

        let stack = NSStackView(views: [holdLabelField, holdRecorder, andPressLabel, nextRecorder])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = TableGroupView.spacing
        stack.heightAnchor.constraint(equalToConstant: TriggerBinding.rowContentHeight).isActive = true
        view = stack

        // Recorder edits need two things to happen in order:
        // 1. Persist the new shortcut into `Preferences` (via `controlWasChanged`). Otherwise
        //    the value lives only in `RecorderControl.objectValue`, and the recorder's displayed
        //    value comes from `Preferences.shortcut` on the next bind.
        // 2. Re-run `shortcutChangedCallback` so the global hotkey gets (re-)registered with
        //    the new value and modifier restrictions cascade to the sibling recorder.
        holdRecorder.onAction = { [weak self] _ in
            guard let self else { return }
            LabelAndControl.controlWasChanged(self.holdRecorder, nil)
            ControlsTab.shortcutChangedCallback(self.holdRecorder)
        }
        nextRecorder.onAction = { [weak self] _ in
            guard let self else { return }
            LabelAndControl.controlWasChanged(self.nextRecorder, nil)
            ControlsTab.shortcutChangedCallback(self.nextRecorder)
        }
    }

    func bind(toShortcut index: Int) {
        // Clear any previous mapping in `shortcutControls`.
        if currentIndex >= 0 {
            ControlsTab.shortcutControls.removeValue(forKey: Preferences.indexToName("holdShortcut", currentIndex))
            ControlsTab.shortcutControls.removeValue(forKey: Preferences.indexToName("nextWindowShortcut", currentIndex))
        }
        currentIndex = index
        let holdKey = Preferences.indexToName("holdShortcut", index)
        let nextKey = Preferences.indexToName("nextWindowShortcut", index)
        holdRecorder.identifier = NSUserInterfaceItemIdentifier(holdKey)
        nextRecorder.identifier = NSUserInterfaceItemIdentifier(nextKey)
        holdRecorder.objectValue = Preferences.shortcut(holdKey)
        nextRecorder.objectValue = Preferences.shortcut(nextKey)
        ControlsTab.shortcutControls[holdKey] = (holdRecorder, TriggerBinding.holdLabelText)
        ControlsTab.shortcutControls[nextKey] = (nextRecorder, TriggerBinding.selectNextText)
        // Reapply modifier restriction on the next-window recorder based on the hold shortcut.
        if let holdModifiers = Preferences.shortcut(holdKey)?.modifierFlags {
            nextRecorder.restrictModifiers(holdModifiers)
        } else {
            nextRecorder.restrictModifiers([])
        }
    }
}
