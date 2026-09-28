import Cocoa

/// Transparent overlay above the tiles that tracks which tile is under the pointer.
class TileOverView: FlippedView {
    weak var scrollView: ScrollView?
    var previousTarget: TileView?

    // periphery:ignore - AppKit private overrides, found by the ObjC runtime rather than called
    @objc func _windowChangedKeyState() {}
    // periphery:ignore - AppKit private overrides, found by the ObjC runtime rather than called
    @objc func _layoutSubtreeWithOldSize(_ oldSize: NSSize) {}

    convenience init() {
        self.init(frame: .zero)
        wantsLayer = true
        layer!.masksToBounds = false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    // MARK: - Mouse hover management

    func updateHover() {
        guard let scrollView, !scrollView.isCurrentlyScrolling else { return }
        let location = convert(TilesPanel.shared.mouseLocationOutsideOfEventStream, from: nil)
        let newTarget = findTarget(location)
        guard newTarget !== previousTarget else { return }
        caTransaction {
            if let newTarget {
                newTarget.mouseMoved()
            } else {
                resetHoveredWindow()
            }
            previousTarget = newTarget
        }
    }

    func findTarget(_ location: NSPoint) -> TileView? {
        guard let documentView = superview else { return nil }
        for case let view as TileView in documentView.subviews {
            let frame = view.frame
            let expandedFrame = CGRect(x: frame.minX - (App.shared.userInterfaceLayoutDirection == .leftToRight ? 0 : 1), y: frame.minY, width: frame.width + 1, height: frame.height + 1)
            if expandedFrame.contains(location) {
                return view
            }
        }
        return nil
    }

    func resetHoveredWindow() {
        previousTarget = nil
        SwitcherSession.current?.hoveredTarget = nil
        if let oldIndex = SwitcherSession.current?.hoveredIndex {
            SwitcherSession.current?.hoveredIndex = nil
            TilesView.highlight(oldIndex)
        }
    }
}
