import Cocoa

class TileTitleView: NSTextField {
    private var currentWidth: CGFloat = -1

    // we set their size manually; override this to remove wasteful appkit-side work
    override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    /// `NSView` is its own `CALayerDelegate`. By implementing `action(for:forKey:)` on this
    /// subclass we intercept the lookup AppKit performs when a layer property changes, and
    /// return `NSNull()` for the animation keys — the documented "no animation for this key"
    /// sentinel. Without this, the label slides smoothly to its new position, because
    /// `caTransaction { setDisableActions(true) }` in `TilesPanel.updateContents` doesn't cover the
    /// follow-up layout pass that `NSWindow.setContentSize` triggers outside the transaction.
    ///
    /// Not marked `override`: `NSView`'s `CALayerDelegate` conformance is via Objective-C and
    /// Swift doesn't expose the method as overridable. Providing it here at the Swift level
    /// installs it for the runtime to find when the layer asks the delegate for actions.
    // periphery:ignore - CALayerDelegate, called by CoreAnimation through the ObjC runtime
    @objc func action(for layer: CALayer, forKey event: String) -> CAAction? {
        switch event {
        case "position", "bounds", "frame", "hidden", "opacity", "transform":
            return NSNull()
        default:
            return nil
        }
    }

    convenience init(font: NSFont) {
        self.init(frame: .zero)
        stringValue = ""
        isEditable = false
        isSelectable = false
        isBezeled = false
        drawsBackground = false
        self.font = font
        textColor = Appearance.fontColor
        lineBreakMode = .byTruncatingTail
        allowsDefaultTighteningForTruncation = false
    }

    /// Re-apply appearance-baked font/color so a recycled instance survives an appearance change
    /// without being reallocated (which would free this tooltip owner; see TileView.reapplyAppearance).
    func reapplyAppearance() {
        font = Appearance.font
        textColor = Appearance.fontColor
        fixHeight()
    }

    /// One line, always: `TilesView.labelLineHeight()` says why the label's own content must not decide.
    func fixHeight() {
        frame.size.height = TilesView.labelLineHeight()
    }

    func setWidth(_ width: CGFloat) {
        guard currentWidth != width else { return }
        currentWidth = width
        frame.size.width = width
    }

    func updateTruncationModeIfNeeded() {
        let newLineBreakMode = getTruncationMode()
        if lineBreakMode != newLineBreakMode {
            lineBreakMode = newLineBreakMode
        }
    }

    private func getTruncationMode() -> NSLineBreakMode {
        if Preferences.titleTruncation == .end {
            return .byTruncatingTail
        }
        if Preferences.titleTruncation == .middle {
            return .byTruncatingMiddle
        }
        return .byTruncatingHead
    }
}
