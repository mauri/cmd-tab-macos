import Cocoa

/// The settings window: one scrolling page with the switcher controls, the login and menubar options, and
/// the exceptions list.
class SettingsWindow: NSWindow {
    static let contentWidth = CGFloat(710)
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
        let windowWidth = Self.contentWidth + 2 * Self.horizontalPadding
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
        }
        Self.shared = self
    }

    private func makeContentView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.titleSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSection(stack, NSLocalizedString("Controls", comment: ""), ControlsTab.initTab())
        addSection(stack, NSLocalizedString("General", comment: ""), GeneralTab.initTab())
        addSection(stack, NSLocalizedString("Exceptions", comment: ""), ExceptionsTab.initTab())
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
