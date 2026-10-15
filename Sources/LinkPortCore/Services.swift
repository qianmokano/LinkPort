import Foundation

@MainActor
public protocol BrowserSystem {
    func discoverBrowsers() -> [Browser]
    func open(_ url: URL, in browser: Browser) async throws
    func copy(_ text: String) throws
    func defaultHandlers() -> DefaultHandlers
    func setDefaultHandler(for scheme: String) async throws
}

@MainActor
public protocol PreferenceStore {
    func load() -> BrowserPreferences
    func save(_ preferences: BrowserPreferences)
}

@MainActor
public final class DefaultsPreferenceStore: PreferenceStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> BrowserPreferences {
        BrowserPreferences(
            orderedIDs: defaults.stringArray(forKey: "browserOrder") ?? [],
            hiddenIDs: Set(defaults.stringArray(forKey: "hiddenBrowsers") ?? []),
            hasSeenWelcome: defaults.bool(forKey: "hasSeenWelcome")
        )
    }

    public func save(_ preferences: BrowserPreferences) {
        defaults.set(preferences.orderedIDs, forKey: "browserOrder")
        defaults.set(preferences.hiddenIDs.sorted(), forKey: "hiddenBrowsers")
        defaults.set(preferences.hasSeenWelcome, forKey: "hasSeenWelcome")
    }
}

