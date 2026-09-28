import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

class TilesView {
    static var scrollView: ScrollView!
    static var contentView: EffectView!
    static var currentEffectViewKind: EffectViewKind?
    private static var cachedEffectViews: [EffectViewKind: EffectView] = [:]
    static var noWindowLabel = NSTextField(labelWithString: NSLocalizedString("No Window", comment: ""))
    static var rows = [[TileView]]()
    static var recycledViews = [TileView]()
    static var tilesWidth = CGFloat(0.0)
    static var tilesHeight = CGFloat(0.0)
    static var layoutCache = LayoutCache()
    static var tileUnderLayer = TileUnderLayer()
    static var tileOverView = TileOverView()
    private static var initialized = false

    static func initialize() {
        guard !initialized else { return }
        configureNoWindowLabel()
        updateBackgroundView()
        initialized = true
        growPoolToCoverWindows()
        Self.updateCachedSizes()
    }

    static func growPoolToCoverWindows() {
        let count = TilePool.tilesToAdd(poolSize: recycledViews.count, windowCount: Windows.list.count, uiIsBuilt: initialized)
        (0..<count).forEach { _ in recycledViews.append(TileView()) }
    }

    private static func configureNoWindowLabel() {
        noWindowLabel.textColor = .secondaryLabelColor
        noWindowLabel.font = .systemFont(ofSize: 13)
        noWindowLabel.alignment = .center
        noWindowLabel.isHidden = true
    }

    /// A title label is always drawn on one line, so its height is a property of the FONT and of nothing
    /// else. Measuring it off a tile's own label made it a property of that window's title instead:
    /// `NSCell.cellSize.height` grows by one line height per line break in the string, so a single window
    /// titled with a multi-line string made every tile in the grid that much taller (#6010). `WindowTitle`
    /// keeps such a string out of the model; this keeps the metric out of reach of whatever does get in.
    private static let labelHeightProbe = TileTitleView(font: Appearance.font)

    static func labelLineHeight() -> CGFloat {
        labelHeightProbe.font = Appearance.font
        labelHeightProbe.stringValue = "Ag"
        return labelHeightProbe.cell!.cellSize.height
    }

    static func updateCachedSizes() {
        guard !TilesView.recycledViews.isEmpty else { return }
        layoutCache.labelHeight = labelLineHeight()
        layoutCache.comfortableReadabilityWidth = TileView.widthOfComfortableReadability()
        TileFontIconView.symbolCache.removeAll()
    }

    static func updateBackgroundView() {
        let kind = requiredEffectViewKind()
        contentView = cachedEffectView(for: kind)
        currentEffectViewKind = kind
        let host = contentView.hostView
        scrollView?.removeFromSuperview()
        scrollView = ScrollView()
        host.addSubview(scrollView)
        host.addSubview(noWindowLabel)
    }

    static func swapBackgroundViewIfNeeded() {
        guard contentView != nil else { return }
        let desired = requiredEffectViewKind()
        guard desired != currentEffectViewKind else { return }
        let newView = cachedEffectView(for: desired)
        currentEffectViewKind = desired
        let host = newView.hostView
        host.addSubview(scrollView)
        host.addSubview(noWindowLabel)
        contentView = newView
        TilesPanel.shared.contentView = newView
    }

    private static func cachedEffectView(for kind: EffectViewKind) -> EffectView {
        if let cached = cachedEffectViews[kind] {
            cached.updateAppearance()
            return cached
        }
        let view = makeEffectView(for: kind)
        cachedEffectViews[kind] = view
        return view
    }

    static func reset() {
        // it would be nicer to remove this whole "reset" logic, and instead update each component to check Appearance properties before showing
        // Maybe in some Appkit willDraw() function that triggers before drawing it
        NSScreen.updatePreferred()
        Appearance.update()
        // app icons are captured once at launch; we need to manually update them if needed
        let old = TilesPanel.maxPossibleAppIconSize.width
        TilesPanel.updateMaxPossibleAppIconSize()
        if old != TilesPanel.maxPossibleAppIconSize.width {
            Applications.updateAppIcons()
        }
        updateBackgroundView()
        TilesPanel.shared.contentView = contentView
        // Reuse the pooled tiles instead of reallocating them: recreating freed the tooltip-owning
        // subviews while NSToolTipManager still referenced them, crashing when an in-flight tooltip
        // timer fired. reapplyAppearance() refreshes the construction-time appearance state in place.
        for view in TilesView.recycledViews {
            view.reapplyAppearance()
        }
        tileUnderLayer = TileUnderLayer()
        tileOverView = TileOverView()
        tileOverView.scrollView = scrollView
        Self.updateCachedSizes()
    }

    static func highlight(_ indexInRecycledViews: Int) {
        guard indexInRecycledViews >= 0, indexInRecycledViews < recycledViews.count else { return }
        let view = recycledViews[indexInRecycledViews]
        view.indexInRecycledViews = indexInRecycledViews
        guard view.frame != .zero else { return }
        let underLayer = TilesView.tileUnderLayer
        let selectedIndex = SwitcherSession.current?.selectedIndex ?? 0
        guard selectedIndex >= 0, selectedIndex < recycledViews.count else { return }
        let focusedView = recycledViews[selectedIndex]
        let hoveredView = SwitcherSession.current?.hoveredIndex.flatMap { $0 >= 0 && $0 < recycledViews.count ? recycledViews[$0] : nil }
        underLayer.updateHighlight(
            focusedView: focusedView.frame != .zero ? focusedView : nil,
            hoveredView: hoveredView != focusedView && hoveredView?.frame != .zero ? hoveredView : nil
        )
    }

    static func nextRow(_ direction: Direction, allowWrap: Bool = true) -> [TileView]? {
        let step = direction == .down ? 1 : -1
        if let currentRow = Windows.selectedWindow()?.rowIndex {
            var nextRow = currentRow + step
            if nextRow >= rows.count {
                if allowWrap {
                    nextRow = nextRow % rows.count
                } else {
                    return nil
                }
            } else if nextRow < 0 {
                if allowWrap {
                    nextRow = rows.count + nextRow
                } else {
                    return nil
                }
            }
            if ((step > 0 && nextRow < currentRow) || (step < 0 && nextRow > currentRow)) &&
                   (ATShortcut.lastEventIsARepeat || !KeyRepeatTimer.timerIsSuspended) {
                return nil
            }
            return rows[nextRow]
        }
        return nil
    }

    static func navigateUpOrDown(_ direction: Direction, allowWrap: Bool = true) {
        let selectedIndex = SwitcherSession.current?.selectedIndex ?? 0
        guard selectedIndex < TilesView.recycledViews.count else { return }
        let focusedViewFrame = TilesView.recycledViews[selectedIndex].frame
        let originCenter = NSMidX(focusedViewFrame)
        guard let targetRow = nextRow(direction, allowWrap: allowWrap), !targetRow.isEmpty else { return }
        let leftSide = originCenter < NSMidX(contentView.frame)
        let leadingSide = App.shared.userInterfaceLayoutDirection == .leftToRight ? leftSide : !leftSide
        let iterable = leadingSide ? targetRow : targetRow.reversed()
        guard let targetView = iterable.first(where: {
            if App.shared.userInterfaceLayoutDirection == .leftToRight {
                return leadingSide ? NSMaxX($0.frame) > originCenter : NSMinX($0.frame) < originCenter
            }
            return leadingSide ? NSMinX($0.frame) < originCenter : NSMaxX($0.frame) > originCenter
        }) ?? iterable.last else { return }
        guard let targetIndex = TilesView.recycledViews.firstIndex(of: targetView) else { return }
        SwitcherSession.current?.performUserSelection {
            Windows.updateSelectedAndHoveredWindowIndex(targetIndex)
        }
    }

    static func updateItemsAndLayout(_ preservedScrollOrigin: CGPoint?) {
        var widthMax = TilesPanel.maxTilesWidth().rounded()
        if Preferences.appearanceSize == .auto {
            resolveAutoSize(widthMax)
            Self.updateCachedSizes()
            widthMax = TilesPanel.maxTilesWidth().rounded()
        }
        if let (maxX, maxY) = layoutTileViews(widthMax) {
            layoutParentViews(maxX, widthMax, maxY)
            centerRows(TilesView.tilesWidth)
            highlightStartView()
            if let preservedScrollOrigin {
                restoreScrollOrigin(preservedScrollOrigin)
            }
        }
    }

    static func currentScrollOrigin() -> CGPoint {
        return scrollView.contentView.bounds.origin
    }

    private static func restoreScrollOrigin(_ scrollOrigin: CGPoint) {
        guard let documentView = scrollView.documentView else { return }
        let visibleSize = scrollView.contentView.bounds.size
        let documentSize = documentView.frame.size
        let maxX = max(0, documentSize.width - visibleSize.width)
        let maxY = max(0, documentSize.height - visibleSize.height)
        let clampedOrigin = CGPoint(x: min(max(0, scrollOrigin.x), maxX), y: min(max(0, scrollOrigin.y), maxY))
        scrollView.contentView.scroll(to: clampedOrigin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private static func resolveAutoSize(_ widthMax: CGFloat) {
        let heightMax = TilesPanel.maxTilesHeight()
        _ = TileGridLayout.firstSizeThatFits([AppearanceSizePreference.large, .medium, .small], heightMax: heightMax) { size in
            Appearance.applySize(size)
            Self.updateCachedSizes()
            return dryRunLayoutTileViews(widthMax)
        }
    }

    private static func dryRunLayoutTileViews(_ widthMax: CGFloat) -> CGFloat {
        let height = TileView.height(Self.layoutCache.labelHeight)
        let tiles = fillTiles(height).tiles
        return TileGridLayout.compute(gridInput(tiles, height, widthMax)).maxY
    }

    /// Puts this render's window on every recycled tile that has one, and releases the images the rest are
    /// still holding. Returns the tiles that will be placed, in model order, and whether the session ended
    /// half way — a caller that is about to commit a layout has nothing to commit in that case.
    private static func fillTiles(_ height: CGFloat) -> (tiles: [(index: Int, view: TileView)], aborted: Bool) {
        var tiles = [(index: Int, view: TileView)]()
        for index in 0..<TilesView.recycledViews.count {
            guard SwitcherSession.isActive else { return (tiles, true) }
            let view = TilesView.recycledViews[index]
            guard index < Windows.list.count else {
                // release images and stale window references from unused recycledViews
                view.appIcon.releaseImage()
                view.window_ = nil
                continue
            }
            let window = Windows.list[index]
            guard Windows.shouldDisplay(window) else {
                view.frame = .zero
                continue
            }
            view.updateRecycledCellWithNewContent(window, index, height)
            tiles.append((index, view))
        }
        return (tiles, false)
    }

    private static func gridInput(_ tiles: [(index: Int, view: TileView)], _ height: CGFloat, _ widthMax: CGFloat) -> TileGridLayout.Input {
        TileGridLayout.Input(widths: tiles.map { $0.view.frame.size.width }, tileHeight: height, widthMax: widthMax,
            padding: Appearance.interCellPadding,
            isLeftToRight: App.shared.userInterfaceLayoutDirection == .leftToRight)
    }

    private static func layoutTileViews(_ widthMax: CGFloat) -> (CGFloat, CGFloat)? {
        let labelHeight = Self.layoutCache.labelHeight
        let height = TileView.height(labelHeight)
        let filled = fillTiles(height)
        guard !filled.aborted else { return nil }
        let tiles = filled.tiles
        let layout = TileGridLayout.compute(gridInput(tiles, height, widthMax))
        for (position, tile) in tiles.enumerated() {
            tile.view.frame.origin = layout.origins[position]
        }
        rows = layout.rows.map { $0.map { tiles[$0].view } }
        for (rowIndex, row) in layout.rows.enumerated() {
            for position in row { Windows.list[tiles[position].index].rowIndex = rowIndex }
        }
        let newViews = tiles.map { $0.view }
        let maxX = layout.maxX
        let maxY = layout.maxY
        scrollView.documentView!.subviews = newViews
        scrollView.documentView!.addSubview(tileOverView)
        tileOverView.scrollView = scrollView
        let docLayer = scrollView.documentView!.layer!
        if tileUnderLayer.superlayer !== docLayer {
            docLayer.insertSublayer(tileUnderLayer, at: 0)
        }
        return (maxX, maxY)
    }

    private static func layoutParentViews(_ maxX: CGFloat, _ widthMax: CGFloat, _ maxY: CGFloat) {
        let heightMax = TilesPanel.maxTilesHeight()
        let minWidth = min(widthMax, 320)
        TilesView.tilesWidth = max(min(maxX, widthMax), maxX == 0 ? minWidth : 0)
        TilesView.tilesHeight = min(maxY, heightMax)
        let frameWidth = TilesView.tilesWidth + Appearance.windowPadding * 2
        let frameHeight = TilesView.tilesHeight + Appearance.windowPadding * 2
        let originX = Appearance.windowPadding
        let originY = Appearance.windowPadding
        contentView.frame.size = NSSize(width: frameWidth, height: frameHeight)
        let host = contentView.hostView
        if host !== contentView {
            host.frame = CGRect(origin: .zero, size: NSSize(width: frameWidth, height: frameHeight))
        }
        scrollView.frame.size = NSSize(width: TilesView.tilesWidth, height: max(0, min(maxY, heightMax)))
        scrollView.frame.origin = CGPoint(x: originX, y: originY)
        scrollView.contentView.frame.size = scrollView.frame.size
        if App.shared.userInterfaceLayoutDirection == .rightToLeft {
            let croppedWidth = max(0, TilesView.tilesWidth - maxX)
            scrollView.documentView!.subviews.forEach { $0.frame.origin.x -= croppedWidth }
        }
        scrollView.documentView!.frame.size = NSSize(width: maxX, height: maxY)
        let docSize = scrollView.documentView!.frame.size
        tileOverView.frame = CGRect(origin: .zero, size: docSize)
        tileUnderLayer.frame = CGRect(origin: .zero, size: docSize)
        let isEmpty = maxX == 0
        noWindowLabel.isHidden = !isEmpty
        if isEmpty {
            noWindowLabel.sizeToFit()
            let labelX = originX + (TilesView.tilesWidth - noWindowLabel.frame.width) * 0.5
            let labelY = scrollView.frame.origin.y + (scrollView.frame.height - noWindowLabel.frame.height) * 0.5
            noWindowLabel.frame.origin = CGPoint(x: labelX, y: labelY)
        }
    }

    static func centerRows(_ maxX: CGFloat) {
        let offsets = TileGridLayout.centeringOffsets(rowWidths: rows.map { $0.map { $0.frame.size.width } },
            padding: Appearance.interCellPadding, within: maxX)
        let sign: CGFloat = App.shared.userInterfaceLayoutDirection == .leftToRight ? 1 : -1
        for (rowIndex, row) in rows.enumerated() {
            guard SwitcherSession.isActive else { return }
            guard offsets[rowIndex] > 0 else { continue }
            for view in row { view.frame.origin.x += sign * offsets[rowIndex] }
        }
    }

    private static func highlightStartView() {
        let session = SwitcherSession.current
        if Windows.selectedWindow() != nil {
            TilesView.highlight(session?.selectedIndex ?? 0)
        } else {
            tileUnderLayer.updateHighlight(focusedView: nil, hoveredView: nil)
        }
        if let hoveredWindowIndex = session?.hoveredIndex,
           hoveredWindowIndex >= 0,
           hoveredWindowIndex < Windows.list.count,
           Windows.shouldDisplay(Windows.list[hoveredWindowIndex]) {
            TilesView.highlight(hoveredWindowIndex)
        }
    }

    static func clearNeedsLayout() {
        var views = [NSView]()
        if let contentView { views.append(contentView as NSView) }
        views.append(noWindowLabel)
        if let scrollView {
            views.append(scrollView)
            views.append(scrollView.contentView)
            if let documentView = scrollView.documentView { views.append(documentView) }
        }
        for view in views {
            view.needsLayout = false
            view.needsDisplay = false
            view.needsUpdateConstraints = false
        }
    }

    struct LayoutCache {
        var labelHeight = CGFloat(0)
        var comfortableReadabilityWidth: CGFloat?
    }

    
}

class ScrollView: NSScrollView {
    // overriding scrollWheel() turns this false; we force it to be true to enable responsive scrolling
    override class var isCompatibleWithResponsiveScrolling: Bool { true }

    var isCurrentlyScrolling = false

    convenience init() {
        self.init(frame: .zero)
        documentView = TilesDocumentView(frame: .zero)
        documentView!.wantsLayer = true
        drawsBackground = false
        hasVerticalScroller = true
        verticalScrollElasticity = .none
        scrollerStyle = .overlay
        scrollerKnobStyle = .light
        horizontalScrollElasticity = .none
        usesPredominantAxisScrolling = true
        observeScrollingEvents()
    }

    private func observeScrollingEvents() {
        NotificationCenter.default.addObserver(self, selector: #selector(scrollingStarted), name: NSScrollView.willStartLiveScrollNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(scrollingEnded), name: NSScrollView.didEndLiveScrollNotification, object: nil)
    }

    @objc private func scrollingStarted() { isCurrentlyScrolling = true }
    @objc private func scrollingEnded() { isCurrentlyScrolling = false }

    /// holding shift and using the scrolling wheel will generate a horizontal movement
    /// shift can be part of shortcuts so we force shift scrolls to be vertical
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.shift) && event.scrollingDeltaY == 0 {
            let cgEvent = event.cgEvent!
            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: cgEvent.getDoubleValueField(.scrollWheelEventDeltaAxis2))
            cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: 0)
            super.scrollWheel(with: NSEvent(cgEvent: cgEvent)!)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

class TilesDocumentView: FlippedView {
    // periphery:ignore - AppKit private overrides, found by the ObjC runtime rather than called
    @objc func _windowChangedKeyState() {}
    // periphery:ignore - AppKit private overrides, found by the ObjC runtime rather than called
    @objc func _layoutSubtreeWithOldSize(_ oldSize: NSSize) {}
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}


enum Direction {
    case right
    case left
    case leading
    case trailing
    case up
    case down

    func step() -> Int {
        if self == .left {
            return App.shared.userInterfaceLayoutDirection == .leftToRight ? -1 : 1
        } else if self == .right {
            return App.shared.userInterfaceLayoutDirection == .leftToRight ? 1 : -1
        }
        return self == .leading ? 1 : -1
    }
}
