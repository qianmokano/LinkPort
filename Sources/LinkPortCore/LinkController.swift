import Foundation
import Observation

@MainActor @Observable
public final class LinkController {
    public let bundleID: String
    public private(set) var browsers: [Browser] = []
    public private(set) var preferences: BrowserPreferences
    public private(set) var queue = LinkQueue()
    public private(set) var selectedID: String?
    public private(set) var issue: LinkPortIssue?
    public private(set) var isOpening = false
    public private(set) var isSettingDefault = false
    public private(set) var handlers = DefaultHandlers()
    @ObservationIgnored private let system: any BrowserSystem
    @ObservationIgnored private let store: any PreferenceStore
    @ObservationIgnored private var activeOperation: UUID?

    public var visibleBrowsers: [Browser] { browsers.filter { !preferences.hiddenIDs.contains($0.id) } }
    public var isDefault: Bool { handlers.isDefault(bundleID) }

    public init(bundleID: String, system: any BrowserSystem, store: any PreferenceStore) {
        self.bundleID = bundleID
        self.system = system
        self.store = store
        self.preferences = store.load()
        refresh()
    }

    public func refresh() {
        browsers = BrowserCatalog.arrange(system.discoverBrowsers(), preferences: preferences, excluding: bundleID)
        let known = Set(preferences.orderedIDs)
        let additions = browsers.map(\.id).filter { !known.contains($0) }
        if !additions.isEmpty {
            preferences.orderedIDs.append(contentsOf: additions)
            store.save(preferences)
        }
        if !visibleBrowsers.contains(where: { $0.id == selectedID }) { selectedID = visibleBrowsers.first?.id }
        handlers = system.defaultHandlers()
    }

    public func receive(_ urls: [URL]) {
        let wasEmpty = queue.current == nil
        let invalid = queue.enqueue(urls)
        refresh()
        if wasEmpty { issue = nil; selectedID = visibleBrowsers.first?.id }
        if invalid > 0 { issue = .invalidURL }
    }

    public func select(_ id: String) {
        guard visibleBrowsers.contains(where: { $0.id == id }) else { return }
        selectedID = id
    }

    public func moveSelection(by offset: Int) {
        let visible = visibleBrowsers
        guard !visible.isEmpty else { return }
        let index = visible.firstIndex(where: { $0.id == selectedID }) ?? 0
        selectedID = visible[min(max(index + offset, 0), visible.count - 1)].id
    }

    public func setHidden(_ id: String, hidden: Bool) {
        guard browsers.contains(where: { $0.id == id }) else { return }
        if hidden { preferences.hiddenIDs.insert(id) } else { preferences.hiddenIDs.remove(id) }
        store.save(preferences)
        refresh()
    }

    public func moveBrowsers(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !source.isEmpty, source.allSatisfy({ browsers.indices.contains($0) }),
              (0...browsers.count).contains(destination) else { return }
        let moving = source.map { browsers[$0] }
        var reordered = browsers.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertion = destination - source.filter { $0 < destination }.count
        reordered.insert(contentsOf: moving, at: insertion)
        guard reordered != browsers else { return }
        persistOrder(reordered)
    }

    public func moveBrowser(_ id: String, by offset: Int) {
        guard let source = browsers.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard browsers.indices.contains(destination) else { return }
        var reordered = browsers
        reordered.swapAt(source, destination)
        persistOrder(reordered)
    }

    public func finishWelcome() {
        preferences.hasSeenWelcome = true
        store.save(preferences)
    }

    public func setLanguage(_ language: AppLanguage) {
        preferences.language = language
        store.save(preferences)
    }

    public func dismissIssue() { issue = nil }

    public func open(_ id: String? = nil) async {
        guard !isOpening, let url = queue.current else { return }
        let target = id ?? selectedID
        guard let browser = visibleBrowsers.first(where: { $0.id == target }) else {
            issue = .browserUnavailable
            return
        }
        isOpening = true
        issue = nil
        let token = UUID()
        activeOperation = token
        do {
            try await system.open(url, in: browser)
            guard activeOperation == token else { return }
            completeCurrent()
        } catch {
            guard activeOperation == token else { return }
            isOpening = false
            activeOperation = nil
            refresh()
            issue = (error as? LinkPortIssue) == .browserUnavailable ? .browserUnavailable : .openFailed
        }
    }

    public func copyCurrent() {
        guard !isOpening, let url = queue.current else { return }
        do {
            try system.copy(url.absoluteString)
            completeCurrent()
        } catch { issue = .copyFailed }
    }

    public func cancel() {
        activeOperation = nil
        isOpening = false
        issue = nil
        queue.cancel()
    }

    public func makeDefault() async {
        guard !isSettingDefault else { return }
        isSettingDefault = true
        issue = nil
        defer { isSettingDefault = false; handlers = system.defaultHandlers() }
        do {
            handlers = system.defaultHandlers()
            if handlers.http != bundleID {
                try await system.setDefaultHandler(for: "http")
                handlers = system.defaultHandlers()
                guard handlers.http == bundleID else { issue = .defaultChangeFailed; return }
            }
            if handlers.https != bundleID { try await system.setDefaultHandler(for: "https") }
            if !system.defaultHandlers().isDefault(bundleID) { issue = .defaultChangeFailed }
        } catch { issue = .defaultChangeFailed }
    }

    private func completeCurrent() {
        queue.completeCurrent()
        isOpening = false
        activeOperation = nil
        issue = nil
        selectedID = visibleBrowsers.first?.id
    }

    private func persistOrder(_ reordered: [Browser]) {
        browsers = reordered
        let present = Set(reordered.map(\.id))
        preferences.orderedIDs = reordered.map(\.id) + preferences.orderedIDs.filter { !present.contains($0) }
        store.save(preferences)
    }
}
