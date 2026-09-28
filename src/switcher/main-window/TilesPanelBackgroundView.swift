protocol EffectView: NSView {
    func updateAppearance(cornerRadius: CGFloat)
    /// Where `TilesView` places its content (scroll view, search field, empty-state label).
    /// For `NSVisualEffectView` that's the view itself; for `NSGlassEffectView` it's `contentView`,
    /// the only place Apple guarantees rendering for embedded views.
    var hostView: NSView { get }
}

extension EffectView {
    func updateAppearance() { updateAppearance(cornerRadius: Appearance.windowCornerRadius) }
}

// `NSGlassEffectView` exists only in the macOS 26 SDK (Swift 6.2 / Xcode 26). Older toolchains build the frosted fallback only.
#if compiler(>=6.2)
@available(macOS 26.0, *)
extension NSGlassEffectView: EffectView {
    func updateAppearance(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        // Left rectangular, the clip set in `makeGlassEffectView` draws a straight outline outside the
        // glass shape on macOS 27 (#5757). Set here, not there: cached views are reused across style
        // and size changes.
        layer!.cornerRadius = cornerRadius
    }

    var hostView: NSView { contentView! }
}
#endif

class FrostedGlassEffectView: NSVisualEffectView, EffectView {
    var hostView: NSView { self }

    convenience init() {
        self.init(frame: .zero)
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        updateAppearance()
    }

    func updateAppearance(cornerRadius: CGFloat) {
        material = Appearance.material
        updateRoundedCorners(cornerRadius)
    }

    /// using layer!.cornerRadius works but the corners are aliased; this custom approach gives smooth rounded corners
    /// see https://stackoverflow.com/a/29386935/2249756
    private func updateRoundedCorners(_ cornerRadius: CGFloat) {
        if cornerRadius == 0 {
            maskImage = nil
        } else {
            let edgeLength = 2.0 * cornerRadius + 1.0
            let mask = NSImage(size: NSSize(width: edgeLength, height: edgeLength), flipped: false) { rect in
                let bezierPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
                NSColor.black.set()
                bezierPath.fill()
                return true
            }
            mask.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
            mask.resizingMode = .stretch
            maskImage = mask
        }
    }
}

enum EffectViewKind {
    case frosted
    case liquidGlass
}

func requiredEffectViewKind() -> EffectViewKind {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
        return .liquidGlass
    }
    #endif
    return .frosted
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private func makeGlassEffectView() -> NSGlassEffectView {
    let glass = NSGlassEffectView()
    glass.style = .regular
    // NSGlassEffectView only renders views embedded in `contentView`; this single host holds the
    // scroll view, search field and empty-state label so they all sit inside the glass.
    glass.contentView = NSView()
    // without this, there are weird shadows around the corners
    glass.wantsLayer = true
    glass.layer!.masksToBounds = true
    glass.layer!.cornerCurve = .continuous
    // after the layer exists: `updateAppearance` rounds the clip through it
    glass.updateAppearance()
    return glass
}
#endif

func makeEffectView(for kind: EffectViewKind) -> EffectView {
    #if compiler(>=6.2)
    if #available(macOS 26.0, *), kind == .liquidGlass {
        return makeGlassEffectView()
    }
    #endif
    return FrostedGlassEffectView()
}
