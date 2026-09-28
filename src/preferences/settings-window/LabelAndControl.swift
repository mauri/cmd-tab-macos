import Cocoa
import ShortcutRecorder

typealias EventClosure = (NSEvent, NSView) -> Void

class LabelAndControl: NSObject {
    static func makeSwitch(_ rawName: String, extraAction: ActionClosure? = nil) -> Switch {
        let button = Switch(CachedUserDefaults.bool(rawName))
        _ = setupControl(button, rawName, extraAction: extraAction)
        return button
    }

    static func dropdown_(_ rawName: String, _ macroPreferences: [MacroPreference]) -> NSPopUpButton {
        let popUp = PopupButtonLikeSystemSettings()
        popUp.addItems(withTitles: macroPreferences.map {
            $0.localizedString
        })
        popUp.selectItem(at: CachedUserDefaults.intFromMacroPref(rawName, macroPreferences))
        return popUp
    }

    static func makeDropdown(_ rawName: String, _ macroPreferences: [MacroPreference], extraAction: ActionClosure? = nil) -> NSPopUpButton {
        let dropdown = dropdown_(rawName, macroPreferences)
        return setupControl(dropdown, rawName, extraAction: extraAction) as! NSPopUpButton
    }

    static func setupControl(_ control: NSControl, _ rawName: String, _ controlId: String? = nil, extraAction: ActionClosure? = nil) -> NSControl {
        control.identifier = NSUserInterfaceItemIdentifier(rawName)
        control.onAction = {
            controlWasChanged($0, controlId)
            extraAction?($0)
        }
        return control
    }

    static func controlWasChanged(_ senderControl: NSControl, _ controlId: String?) {
        if let recorderControl = senderControl as? RecorderControl {
            let key = senderControl.identifier!.rawValue
            let oldValue = Preferences.shortcut(key)
            let newValue = recorderControl.objectValue
            if oldValue == nil && newValue == nil { return }
            if let oldValue, let newValue, oldValue.isEqual(newValue) { return }
            Preferences.setShortcut(key, newValue, stringRepresentation: recorderControl.stringValue)
            return
        }
        if let newValue = LabelAndControl.getControlValue(senderControl, controlId) {
            if let oldValue = UserDefaults.standard.string(forKey: senderControl.identifier!.rawValue), newValue == oldValue {
                return
            }
            Preferences.set(senderControl.identifier!.rawValue, newValue)
        }
    }

    static func makeLabel(_ labelText: String, shouldFit: Bool = true) -> NSTextField {
        let label = TextField(labelText)
        label.isSelectable = false
        label.usesSingleLineMode = true
        label.alignment = .right
        if shouldFit {
            label.fit()
        }
        return label
    }

    static func getControlValue(_ control: NSControl, _ controlId: String?) -> String? {
        if control is NSPopUpButton {
            return String((control as! NSPopUpButton).indexOfSelectedItem)
        } else if control is NSSlider {
            return String(format: "%.0f", control.doubleValue) // we are only interested in decimals of the provided double
        } else if control is NSButton {
            if let controlId {
                return ((control as! NSButton).state == NSButton.StateValue.on) ? controlId : nil
            } else {
                return String((control as! NSButton).state == NSButton.StateValue.on)
            }
        } else if control is NSSegmentedControl {
            return String((control as! NSSegmentedControl).selectedSegment)
        } else {
            return control.stringValue
        }
    }
}
