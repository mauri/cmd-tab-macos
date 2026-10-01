import Cocoa

/// The settings window: one scrolling page in two columns. The left column holds the switcher controls and
/// the general options, and the right column holds the exceptions list.
class SettingsWindow: NSWindow {
    static let settingsColumnWidth = CGFloat(440)
    static let exceptionsColumnWidth = CGFloat(640)
    private static let columnSpacing = CGFloat(30)
    private static let horizontalPadding = CGFloat(20)
    private static let topPadding = CGFloat(40)
    private static let bottomPadding = CGFloat(20)
    private static let sectionSpacing = CGFloat(30)
    private static let titleSpacing = CGFloat(10)
    private static let minWindowHeight = CGFloat(400)
    private static let defaultWindowHeight = CGFloat(700)
    static var shared: SettingsWindow!

    override var canBecomeKey: Bool { SecondaryWindows.canBecomeKey }

    convenience init() {
        let windowWidth = Self.settingsColumnWidth + Self.columnSpacing + Self.exceptionsColumnWidth + 2 * Self.horizontalPadding
        self.init(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: Self.defaultWindowHeight),
                  styleMask: [.titled, .miniaturizable, .closable, .resizable, .fullSizeContentView],
                  backing: .buffered, defer: false)
        minSize = NSSize(width: windowWidth, height: Self.minWindowHeight)
        maxSize = NSSize(width: windowWidth, height: CGFloat.greatestFiniteMagnitude)
        delegate = self
        applySecondaryWindowChrome(NSLocalizedString("Settings", comment: ""))
        isMovableByWindowBackground = true
        contentView = makeContentView()
        GeneralTab.refreshControlsFromPreferences()
        // setFrameAutosaveNameSafely applies the persisted frame (dropping a corrupt one that would
        // otherwise abort the app) and returns whether a VALID saved frame existed.
        if !setFrameAutosaveNameSafely("SettingsWindow") {
            setContentSize(NSSize(width: windowWidth, height: Self.defaultWindowHeight))
            center()
        } else if frame.width != windowWidth {
            setContentSize(NSSize(width: windowWidth, height: contentRect(forFrameRect: frame).height))
        }
        Self.shared = self
    }

    private func makeContentView() -> NSView {
        let settingsColumn = makeColumn()
        addSection(settingsColumn, NSLocalizedString("Controls", comment: ""), ControlsTab.initTab())
        addSection(settingsColumn, NSLocalizedString("General", comment: ""), GeneralTab.initTab())
        let exceptionsColumn = makeColumn()
        addSection(exceptionsColumn, NSLocalizedString("Exceptions", comment: ""), ExceptionsTab.initTab())
        let stack = NSStackView(views: [settingsColumn, exceptionsColumn])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = Self.columnSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        let documentView = FlippedView(frame: .zero)
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = documentView
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: Self.topPadding),
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: Self.horizontalPadding),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -Self.horizontalPadding),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -Self.bottomPadding),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
        ])
        return scrollView
    }

    private func makeColumn() -> NSStackView {
        let column = NSStackView()
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = Self.titleSpacing
        column.translatesAutoresizingMaskIntoConstraints = false
        return column
    }

    private func addSection(_ stack: NSStackView, _ title: String, _ view: NSView) {
        if let last = stack.arrangedSubviews.last {
            stack.setCustomSpacing(Self.sectionSpacing, after: last)
        }
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(view)
    }

    override func close() {
        hideAppIfLastWindowIsClosed()
        super.close()
    }
}

extension SettingsWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Defer to the next runloop tick: tearing down view trees, removing observers,
        // and dropping the last strong ref to `self` while AppKit is still inside its own
        // close machinery causes objc_release crashes on re-entry.
        DispatchQueue.main.async { [weak self] in
            guard let self, SettingsWindow.shared === self else { return }
            ControlsTab.cleanup()
            GeneralTab.cleanup()
            ExceptionsTab.cleanup()
            SettingsWindow.shared = nil
        }
    }
}
