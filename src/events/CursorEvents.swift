import Cocoa
import Carbon.HIToolbox.Events

class CursorEvents {
    private static var eventTap: CFMachPort!
    private static var shouldBeEnabled: Bool!
    private static var mouseDownTarget: AnyObject?
    /// true once the tap has observed a leftMouseDown since the switcher showed (reset per gesture and on
    /// each show). A drag from another app started before the switcher showed, so its down was never seen —
    /// that is how `handleLeftMouseUp` recognizes a drop's up and yields it.
    private static var sawLeftMouseDown = false
    static var deadZoneInitialPosition: CGPoint?
    static var isAllowedToMouseHover = true

    static func toggle(_ enabled: Bool) {
        guard enabled != shouldBeEnabled else { return }
        shouldBeEnabled = enabled
        if !enabled {
            deadZoneInitialPosition = nil
        } else {
            sawLeftMouseDown = false // fresh session: a drag in flight when we show has no down we saw
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: enabled)
        }
    }

    static func reEnableTapIfNeeded() {
        if CGEvent.reEnableTapIfNeeded(eventTap, wanted: shouldBeEnabled) {
            Logger.warning { "" }
        }
    }

    static func observe() {
        let eventMask = [CGEventType.leftMouseDown, CGEventType.leftMouseUp, CGEventType.rightMouseDown, CGEventType.rightMouseUp, CGEventType.mouseMoved].reduce(CGEventMask(0), { $0 | (1 << $1.rawValue) })
        eventTap = CGEvent.createTapOrRestart(
            tap: .cgSessionEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: handleEvent,
            // we run on main-thread directly since all we do is check NSEvent and UI coordinates, which we must do on main-thread
            runLoop: CFRunLoopGetMain())
        if eventTap != nil {
            toggle(false)
        }
    }

    private static let handleEvent: CGEventTapCallBack = { _, type, cgEvent, _ in
        switch type {
            case .leftMouseDown: return handleLeftMouseDown(cgEvent)
            case .leftMouseUp: return handleLeftMouseUp(cgEvent)
            case .rightMouseDown: return handleRightMouseDown(cgEvent)
            case .rightMouseUp: return handleRightMouseUp(cgEvent)
            case .mouseMoved: return handleMouseMoved(cgEvent)
            case .tapDisabledByUserInput, .tapDisabledByTimeout:
                if shouldBeEnabled { CGEvent.tapEnable(tap: eventTap!, enable: true) }
                return Unmanaged.passUnretained(cgEvent)
            default: return Unmanaged.passUnretained(cgEvent)
        }
    }

    private static func handleLeftMouseDown(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        sawLeftMouseDown = true // this gesture's down is ours; its up is a click, not a foreign drop
        guard isPointerInsideUi() else { return nil }
        mouseDownTarget = findTileViewUnderPointer()
        return nil
    }

    private static func handleLeftMouseUp(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        let sawDown = sawLeftMouseDown
        sawLeftMouseDown = false
        // a drag from another app ends with a leftMouseUp whose matching down we never saw (it happened
        // before the switcher showed; downs outside the panel are swallowed and tiles are not drag sources).
        // Don't swallow it, or the drop never concludes and the file stays stuck on the cursor. Let AppKit /
        // the source app conclude the drop.
        if !sawDown {
            return Unmanaged.passUnretained(cgEvent)
        }
        guard isPointerInsideUi() else {
            if mouseDownTarget == nil { App.hideUi() }
            mouseDownTarget = nil
            return nil
        }
        let downTarget = mouseDownTarget
        mouseDownTarget = nil
        if let target = findTileViewUnderPointer(), target === downTarget {
            target.mouseUpCallback()
            return nil
        }
        return nil
    }

    private static func handleRightMouseDown(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        if isPointerInsideUi() { return Unmanaged.passUnretained(cgEvent) }
        return nil
    }

    private static func handleRightMouseUp(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        if isPointerInsideUi() { return Unmanaged.passUnretained(cgEvent) }
        return nil
    }

    private static func handleMouseMoved(_ cgEvent: CGEvent) -> Unmanaged<CGEvent>? {
        if isAllowedToReactToPointerMovement(cgEvent.location) {
            TilesView.tileOverView.updateHover()
        }
        return Unmanaged.passUnretained(cgEvent)
    }

    static func resetDeadzone() {
        deadZoneInitialPosition = nil
        isAllowedToMouseHover = false
    }

    static func isAllowedToReactToPointerMovement(_ location: CGPoint) -> Bool {
        updateDeadzoneSituation(location)
        return isAllowedToMouseHover
    }

    private static func pointerLocationInWindow() -> NSPoint {
        TilesPanel.shared.mouseLocationOutsideOfEventStream
    }

    private static func isPointerInsideUi() -> Bool {
        TilesPanel.shared.contentLayoutRect.contains(pointerLocationInWindow())
    }

    private static func pointerInOverlay() -> (TileOverView, NSPoint) {
        let overlay = TilesView.tileOverView
        return (overlay, overlay.convert(pointerLocationInWindow(), from: nil))
    }

    private static func findTileViewUnderPointer() -> TileView? {
        let (overlay, point) = pointerInOverlay()
        return overlay.findTarget(point)
    }

    /// when using the trackpad, the user may swipe with a slight mistake. This will create a small cursor movement
    /// we ignore those, as they are not intended. Intended movements will be larger and not ignored
    private static func updateDeadzoneSituation(_ location: CGPoint) {
        guard let deadZoneInitialPosition else {
            deadZoneInitialPosition = location
            isAllowedToMouseHover = false
            return
        }
        let deltaX = location.x - deadZoneInitialPosition.x
        let deltaY = location.y - deadZoneInitialPosition.y
        if hypot(deltaX, deltaY) > 25 { isAllowedToMouseHover = true }
    }
}
