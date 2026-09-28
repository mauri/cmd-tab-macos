import Cocoa
import Carbon.HIToolbox.Events
import ShortcutRecorder

class Preferences {
    static var defaultValues: [String: Any] = [
        "holdShortcut": defaultShortcut("⌘"),
        "nextWindowShortcut": defaultShortcut("⇥"),
        "focusWindowShortcut": defaultShortcut(returnKeyEquivalent()),
        "previousWindowShortcut": defaultShortcut("⇧"),
        "cancelShortcut": defaultShortcut("⎋"),
        "arrowKeysEnabled": "true",
        "vimKeysEnabled": "false",
        "mouseHoverEnabled": "false",
        "cursorFollowFocus": CursorFollowFocus.never.indexAsString,
        "windowDisplayDelay": "100",
        "shortcutStyle": ShortcutStylePreference.focusOnRelease.indexAsString,
        "appearanceSize": AppearanceSizePreference.auto.indexAsString,
        "appearanceTheme": AppearanceThemePreference.system.indexAsString,
        "showOnScreen": ShowOnScreenPreference.active.indexAsString,
        "titleTruncation": TitleTruncationPreference.end.indexAsString,
        "showTitles": ShowTitlesPreference.windowTitle.indexAsString,
        "startAtLogin": "true",
        "menubarIcon": MenubarIconPreference.outlined.indexAsString,
        "menubarIconShown": "true",
        "language": LanguagePreference.systemDefault.indexAsString,
        "exceptions": defaultExceptions(),
        "updatePolicy": UpdatePolicyPreference.autoCheck.indexAsString,
        "crashPolicy": CrashPolicyPreference.ask.indexAsString,
        "settingsWindowShownOnFirstLaunch": "false",
    ]

    static let staticShortcutKeys = [
        "focusWindowShortcut", "previousWindowShortcut", "cancelShortcut",
    ]
    static let emptyShortcut = Shortcut(code: .none, modifierFlags: [], characters: nil, charactersIgnoringModifiers: nil)
    private static let shortcutStorageStringField = "string"
    private static let shortcutStorageDataField = "secureData"

    // persisted values
    static var holdShortcut: [Shortcut?] { (0..<shortcutCount).map { CachedUserDefaults.shortcut(indexToName("holdShortcut", $0)) } }
    static var focusWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("focusWindowShortcut") }
    static var previousWindowShortcut: Shortcut? { CachedUserDefaults.shortcut("previousWindowShortcut") }
    static var cancelShortcut: Shortcut? { CachedUserDefaults.shortcut("cancelShortcut") }
    static var arrowKeysEnabled: Bool { CachedUserDefaults.bool("arrowKeysEnabled") }
    static var vimKeysEnabled: Bool { CachedUserDefaults.bool("vimKeysEnabled") }
    static var mouseHoverEnabled: Bool { CachedUserDefaults.bool("mouseHoverEnabled") }
    static var cursorFollowFocus: CursorFollowFocus { CachedUserDefaults.macroPref("cursorFollowFocus", CursorFollowFocus.allCases) }
    static var windowDisplayDelayInMs: Int { CachedUserDefaults.int("windowDisplayDelay") }
    static var windowDisplayDelay: DispatchTimeInterval { DispatchTimeInterval.milliseconds(windowDisplayDelayInMs) }
    static var startAtLogin: Bool { CachedUserDefaults.bool("startAtLogin") }
    static var exceptions: [ExceptionEntry] { CachedUserDefaults.json("exceptions", [ExceptionEntry].self) }
    static var settingsWindowShownOnFirstLaunch: Bool { CachedUserDefaults.bool("settingsWindowShownOnFirstLaunch") }

    // macro values
    static var appearanceSize: AppearanceSizePreference { CachedUserDefaults.macroPref("appearanceSize", AppearanceSizePreference.allCases) }
    static var appearanceTheme: AppearanceThemePreference { CachedUserDefaults.macroPref("appearanceTheme", AppearanceThemePreference.allCases) }
    static var showOnScreen: ShowOnScreenPreference { CachedUserDefaults.macroPref("showOnScreen", ShowOnScreenPreference.allCases) }
    static var titleTruncation: TitleTruncationPreference { CachedUserDefaults.macroPref("titleTruncation", TitleTruncationPreference.allCases) }
    static var showTitles: ShowTitlesPreference { CachedUserDefaults.macroPref("showTitles", ShowTitlesPreference.allCases) }
    static var updatePolicy: UpdatePolicyPreference { CachedUserDefaults.macroPref("updatePolicy", UpdatePolicyPreference.allCases) }
    static var crashPolicy: CrashPolicyPreference { CachedUserDefaults.macroPref("crashPolicy", CrashPolicyPreference.allCases) }
    static var shortcutStyle: ShortcutStylePreference { CachedUserDefaults.macroPref("shortcutStyle", ShortcutStylePreference.allCases) }
    static var menubarIcon: MenubarIconPreference { CachedUserDefaults.macroPref("menubarIcon", MenubarIconPreference.allCases) }
    static var menubarIconShown: Bool { CachedUserDefaults.bool("menubarIconShown") }
    static var language: LanguagePreference { CachedUserDefaults.macroPref("language", LanguagePreference.allCases) }

    /// One hold shortcut. Keys keep the indexed naming (`holdShortcut`, `nextWindowShortcut`) that the
    /// shortcut registry and the keyboard code share.
    static let shortcutCount = 1
    static let maxShortcutCount = 1

    static func initialize() {
        PreferencesMigrations.removeCorruptedPreferences()
        PreferencesMigrations.migratePreferences()
        registerDefaults()
    }

    static func resetAll() {
        UserDefaults.standard.removePersistentDomain(forName: App.bundleIdentifier)
        invalidateAllCache()
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaultValues)
        #if DEBUG
        pinToDefaultsForQa()
        #endif
    }

    #if DEBUG
    static var qaPristine: Bool { CommandLine.arguments.contains("--qa-pristine-prefs") }

    /// `--qa-pristine-prefs`: every preference reads as its default unless the launch arguments say otherwise,
    /// whatever this machine's debug build has saved. The QA suite's visual test needs Settings to look the
    /// same on every run. Nothing saved is touched: the defaults are layered under the argument domain.
    private static func pinToDefaultsForQa() {
        guard qaPristine else { return }
        let domain = UserDefaults.argumentDomain
        let args = UserDefaults.standard.volatileDomain(forName: domain)
        UserDefaults.standard.removeVolatileDomain(forName: domain)
        UserDefaults.standard.setVolatileDomain(defaultValues.merging(args) { _, arg in arg }, forName: domain)
    }
    #endif

    static func markSettingsWindowShownOnFirstLaunch() {
        set("settingsWindowShownOnFirstLaunch", "true", false)
    }

    static func defaultShortcut(_ keyEquivalent: String) -> [String: Any] {
        shortcutStorage(shortcutFromKeyEquivalent(keyEquivalent), keyEquivalent)
    }

    static func setShortcut(_ key: String, _ shortcut: Shortcut?, _ notify: Bool = true) {
        setShortcut(key, shortcut, stringRepresentation: nil, notify)
    }

    static func setShortcut(_ key: String, _ shortcut: Shortcut?, stringRepresentation: String?, _ notify: Bool = true) {
        write(key, notify) { UserDefaults.standard.set(shortcutStorage(shortcut, stringRepresentation), forKey: key) }
    }

    static func setShortcut(_ key: String, keyEquivalent: String, _ notify: Bool = true) {
        setShortcut(key, shortcutFromKeyEquivalent(keyEquivalent), stringRepresentation: keyEquivalent, notify)
    }

    static func shortcut(_ key: String) -> Shortcut? {
        CachedUserDefaults.shortcut(key)
    }

    static func set<T>(_ key: String, _ value: T, _ notify: Bool = true) where T: Encodable {
        write(key, notify) { UserDefaults.standard.set(key == "exceptions" ? jsonEncode(value) : value, forKey: key) }
    }

    static func remove(_ key: String, _ notify: Bool = true) {
        write(key, notify) { UserDefaults.standard.removeObject(forKey: key) }
    }

    /// Every mutation of a preference goes through here: the store write, then the two caches that
    /// shadow it (`CachedUserDefaults` per key, `cachedAll` for the whole domain), then the observers.
    /// Skipping either invalidation leaves readers on a stale value.
    private static func write(_ key: String, _ notify: Bool, _ mutate: () -> Void) {
        mutate()
        CachedUserDefaults.removeFromCache(key)
        invalidateAllCache()
        if notify {
            PreferencesEvents.preferenceChanged(key)
        }
    }

    static let ownedKeys: Set<String> = Set(defaultValues.keys)

    /// `persistentDomain(forName:)` rebuilds a full snapshot dictionary on every call. Cache the filtered
    /// snapshot; the only paths that mutate the domain (`set`, `setShortcut`, `remove`, `resetAll`) clear
    /// `cachedAll` below.
    private static var cachedAll: [String: Any]?

    static var all: [String: Any] {
        if let cachedAll { return cachedAll }
        let domain = UserDefaults.standard.persistentDomain(forName: App.bundleIdentifier) ?? [:]
        let filtered = domain.filter { ownedKeys.contains($0.key) }
        cachedAll = filtered
        return filtered
    }

    static func invalidateAllCache() {
        cachedAll = nil
    }

    /// key-above-tab is ` on US keyboard, but can be different on other keyboards
    static func keyAboveTabDependingOnInputSource() -> String {
        return LiteralKeyCodeTransformer.shared.transformedValue(NSNumber(value: kVK_ANSI_Grave)) ?? "`"
    }

    static func returnKeyEquivalent() -> String {
        return LiteralKeyCodeTransformer.shared.transformedValue(NSNumber(value: kVK_Return)) ?? "↩"
    }

    static func defaultExceptions() -> String {
        return jsonEncode([
            ExceptionEntry(bundleIdentifier: "com.apple.finder", hide: .whenNoOpenWindow, ignore: .none),
            ExceptionEntry(bundleIdentifier: "com.apple.ScreenSharing", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.microsoft.rdc.macos", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.teamviewer.TeamViewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "org.virtualbox.app.VirtualBoxVM", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.parallels.", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.citrix.XenAppViewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.citrix.receiver.icaviewer.mac", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.nicesoftware.dcvviewer", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.vmware.fusion", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.utmapp.UTM", hide: .none, ignore: .whenFullscreen),
            ExceptionEntry(bundleIdentifier: "com.McAfee.McAfeeSafariHost", hide: .always, ignore: .none),
        ])
    }

    static func jsonEncode<T>(_ value: T) -> String where T: Encodable {
        return String(data: try! JSONEncoder().encode(value), encoding: .utf8)!
    }

    static func archiveShortcut(_ shortcut: Shortcut?) -> Data {
        try! NSKeyedArchiver.archivedData(withRootObject: shortcut ?? emptyShortcut, requiringSecureCoding: true)
    }

    static func shortcutStorage(_ shortcut: Shortcut?, _ stringRepresentation: String?) -> [String: Any] {
        [
            shortcutStorageStringField: stringRepresentation ?? shortcut?.readableStringRepresentation(isASCII: true) ?? "",
            shortcutStorageDataField: archiveShortcut(shortcut),
        ]
    }

    static func decodeShortcutStorage(_ value: Any) -> (Bool, Shortcut?) {
        guard let storage = value as? [String: Any], let data = storage[shortcutStorageDataField] as? Data else { return (false, nil) }
        return unarchiveShortcut(data)
    }

    static func unarchiveShortcut(_ data: Data) -> (Bool, Shortcut?) {
        let shortcut: Shortcut?
        shortcut = try? NSKeyedUnarchiver.unarchivedObject(ofClass: Shortcut.self, from: data)
        guard let shortcut else { return (false, nil) }
        return (true, shortcut.keyCode == .none && shortcut.modifierFlags == [] ? nil : shortcut)
    }

    static func shortcutFromKeyEquivalent(_ keyEquivalent: String) -> Shortcut? {
        keyEquivalent.isEmpty ? nil : Shortcut(keyEquivalent: keyEquivalent)
    }

    static func indexToName(_ baseName: String, _ index: Int) -> String {
        return baseName + (index == 0 ? "" : String(index + 1))
    }

    static func nameToIndex(_ name: String) -> Int {
        let digits = String(name.reversed().prefix { $0.isNumber }.reversed())
        guard !digits.isEmpty, let number = Int(digits) else { return 0 }
        return number - 1
    }
}

/// **The cache is there because `UserDefaults` is IPC.** Every miss is a round trip to cfprefsd, and the
/// switcher reads dozens of preferences per show, so what reaches `UserDefaults` from here is what this
/// class failed to absorb.
class CachedUserDefaults {
    static var cache = ConcurrentMap<String, Any>()

    static func removeFromCache(_ key: String) {
        cache.withLock { $0.removeValue(forKey: key) }
    }

    /// retrieve strings in the globalDomain (e.g. defaults read -g KeyRepeat)
    /// these may be nil since we they don't have default values from AltTab
    ///
    /// The value is cached on the way out. It used to be cached and then DROPPED — every caller got nil on
    /// the first read and fell back to its hardcoded default, which is why the first hold-cycle of a launch
    /// repeated at AltTab's built-in rate instead of the user's `KeyRepeat` (`KeyRepeatTimer`).
    /// A missing key caches `NSNull` rather than nothing, so the absent case stops being an XPC round trip
    /// to cfprefsd on every read; `cached as? String` reads that back as nil.
    static func globalString(_ key: String) -> String? {
        if let cached = cache.withLock({ $0[key] }) {
            return cached as? String
        }
        let string = UserDefaults.standard.string(forKey: key)
        cache.withLock { $0[key] = string ?? NSNull() }
        return string
    }

    static func shortcut(_ key: String) -> Shortcut? {
        if let cachedFinalValue = cache.withLock({ $0[key] }) {
            return cachedFinalValue as? Shortcut
        }
        guard let objectValue = UserDefaults.standard.object(forKey: key) else {
            cache.withLock { $0[key] = NSNull() }
            return nil
        }
        let (isValid, finalValue) = Preferences.decodeShortcutStorage(objectValue)
        if isValid {
            cache.withLock { $0[key] = finalValue ?? NSNull() }
            return finalValue
        }
        UserDefaults.standard.removeObject(forKey: key)
        return shortcut(key)
    }

    static func int(_ key: String) -> Int {
        return getThenConvertOrReset(key, { s in Int(s) })
    }

    static func bool(_ key: String) -> Bool {
        return getThenConvertOrReset(key, { s in Bool(s) })
    }

    static func macroPref<A>(_ key: String, _ macroPreferences: [A]) -> A {
        return getThenConvertOrReset(key, { s in Int(s).flatMap { macroPreferences[safe: $0] } })
    }

    /// some UI elements (e.g. dropdown, radios) need an int. We find the right int from the MacroPreference index
    static func intFromMacroPref(_ key: String, _ macroPreferences: [MacroPreference]) -> Int {
        let macroPref = macroPref(key, macroPreferences)
        return macroPreferences.firstIndex { $0.localizedString == macroPref.localizedString }!
    }

    static func json<T>(_ key: String, _ type: T.Type) -> T where T: Decodable {
        return getThenConvertOrReset(key, { s in jsonDecode(s, type) })
    }

    private static func getThenConvertOrReset<T>(_ key: String, _ getterFn: (String) -> T?) -> T {
        if let cachedFinalValue = cache.withLock({ $0[key] }) {
            return cachedFinalValue as! T
        }
        let stringValue = UserDefaults.standard.string(forKey: key)!
        if let finalValue = getterFn(stringValue) {
            cache.withLock { $0[key] = finalValue }
            return finalValue
        }
        // value couldn't be read properly; we remove it and work with the default
        UserDefaults.standard.removeObject(forKey: key)
        let defaultStringValue = UserDefaults.standard.string(forKey: key)!
        let defaultFinalValue = getterFn(defaultStringValue)!
        cache.withLock { $0[key] = defaultFinalValue }
        return defaultFinalValue
    }

    private static func jsonDecode<T>(_ value: String, _ type: T.Type) -> T? where T: Decodable {
        return value.data(using: .utf8).flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

struct ExceptionEntry: Codable {
    var bundleIdentifier: String
    var hide: ExceptionHidePreference
    var ignore: ExceptionIgnorePreference
    var windowTitleContains: [String]?

    init(bundleIdentifier: String, hide: ExceptionHidePreference, ignore: ExceptionIgnorePreference, windowTitleContains: [String]? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.hide = hide
        self.ignore = ignore
        self.windowTitleContains = windowTitleContains
    }

    // Permissive decoder so we can read both the legacy single-string shape
    // (windowTitleContains: String?) and the current array shape ([String]?). Without this,
    // a decode failure on legacy data would cause `getThenConvertOrReset` in Preferences to
    // wipe the entry back to defaultExceptions(), losing the user's patterns.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.bundleIdentifier = try c.decode(String.self, forKey: .bundleIdentifier)
        self.hide = try c.decode(ExceptionHidePreference.self, forKey: .hide)
        self.ignore = try c.decode(ExceptionIgnorePreference.self, forKey: .ignore)
        if let array = try? c.decode([String].self, forKey: .windowTitleContains) {
            self.windowTitleContains = array.isEmpty ? nil : array
        } else if let string = try? c.decode(String.self, forKey: .windowTitleContains), !string.isEmpty {
            self.windowTitleContains = [string]
        } else {
            self.windowTitleContains = nil
        }
    }
}
