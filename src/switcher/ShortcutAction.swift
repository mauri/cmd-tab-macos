import Cocoa

struct ShortcutAction {
    let id: String
    let perform: () -> Void
}

enum ShortcutActions {
    static let all: [ShortcutAction] = [
        ShortcutAction(id: "focusWindowShortcut", perform: { App.focusTarget() }),
        ShortcutAction(id: "previousWindowShortcut", perform: { App.previousWindowShortcutWithRepeatingKey() }),
        ShortcutAction(id: "→", perform: { App.cycleSelection(.right) }),
        ShortcutAction(id: "←", perform: { App.cycleSelection(.left) }),
        ShortcutAction(id: "↑", perform: { App.cycleSelection(.up) }),
        ShortcutAction(id: "↓", perform: { App.cycleSelection(.down) }),
        ShortcutAction(id: "vimCycleRight", perform: { App.cycleSelection(.right) }),
        ShortcutAction(id: "vimCycleLeft", perform: { App.cycleSelection(.left) }),
        ShortcutAction(id: "vimCycleUp", perform: { App.cycleSelection(.up) }),
        ShortcutAction(id: "vimCycleDown", perform: { App.cycleSelection(.down) }),
        ShortcutAction(id: "cancelShortcut", perform: { App.hideUi() }),
    ]

    private static let byId: [String: ShortcutAction] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func find(_ id: String) -> ShortcutAction? {
        byId[id]
    }

    static func execute(_ id: String) {
        if let action = find(id) {
            action.perform()
            return
        }
        if id.hasPrefix("holdShortcut") {
            App.focusTarget()
            return
        }
        if id.hasPrefix("nextWindowShortcut") {
            App.showUiOrCycleSelection(Preferences.nameToIndex(id), false)
        }
    }
}
