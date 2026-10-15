import CoreGraphics
import Foundation
import LinkPortCore
import Testing

private let ownID = "com.linkport.app"
private func browser(_ id: String, name: String? = nil) -> Browser {
    Browser(id: id, name: name ?? id, applicationURL: URL(fileURLWithPath: "/Applications/\(id).app"))
}
private func url(_ text: String = "https://example.com/a?x=1&next=%2Fwork#section") -> URL { URL(string: text)! }

@MainActor
private final class MemoryStore: PreferenceStore {
    var value: BrowserPreferences
    init(_ value: BrowserPreferences = .init()) { self.value = value }
    func load() -> BrowserPreferences { value }
    func save(_ preferences: BrowserPreferences) { value = preferences }
}

@MainActor
private final class FakeSystem: BrowserSystem {
    var browsers = [browser("safari"), browser("chrome")]
    var handlers = DefaultHandlers(http: "safari", https: "safari")
    var opened: [(URL, String)] = []
    var copied: [String] = []
    var requestedSchemes: [String] = []
    var openError: (any Error)?
    var copyError: (any Error)?
    var defaultError: (any Error)?
    var acceptsDefault = true
    var pauseOpening = false
    var continuation: CheckedContinuation<Void, any Error>?

    func discoverBrowsers() -> [Browser] { browsers }
    func defaultHandlers() -> DefaultHandlers { handlers }
    func copy(_ text: String) throws {
        if let copyError { throw copyError }
        copied.append(text)
    }
    func open(_ url: URL, in browser: Browser) async throws {
        if pauseOpening { try await withCheckedThrowingContinuation { continuation = $0 } }
        if let openError { throw openError }
        opened.append((url, browser.id))
    }
    func setDefaultHandler(for scheme: String) async throws {
        requestedSchemes.append(scheme)
        if let defaultError { throw defaultError }
        if acceptsDefault {
            if scheme == "http" { handlers.http = ownID } else { handlers.https = ownID }
        }
    }
}

@MainActor
private func fixture(_ preferences: BrowserPreferences = .init()) -> (LinkController, FakeSystem, MemoryStore) {
    let system = FakeSystem()
    let store = MemoryStore(preferences)
    return (LinkController(bundleID: ownID, system: system, store: store), system, store)
}

@Test func queuePreservesAddressesAndOrder() {
    var queue = LinkQueue()
    let first = url()
    let second = url("http://example.org/中文?emoji=%F0%9F%8C%8D#片段")
    #expect(queue.enqueue([first, second, first]) == 0)
    #expect(queue.urls == [first, second])
    #expect(queue.current?.absoluteString == first.absoluteString)
    queue.completeCurrent()
    #expect(queue.current == second)
    queue.enqueue([first])
    #expect(queue.urls == [second, first])
    queue.cancel()
    queue.completeCurrent()
    #expect(queue.current == nil)
    #expect(queue.count == 0)
}

@Test(arguments: ["file:///tmp/link", "mailto:user@example.com", "javascript:alert(1)", "https:", "/relative", "ftp://example.com"])
func rejectsUnsupportedLinks(_ value: String) {
    var queue = LinkQueue()
    #expect(queue.enqueue([url(value)]) == 1)
    #expect(queue.urls.isEmpty)
}

@Test func catalogsExcludeSelfDeduplicateAndAppendNewBrowsers() {
    let catalog = BrowserCatalog.arrange(
        [browser("safari", name: "Safari"), browser("chrome", name: "Chrome"), browser("safari"), browser(ownID), browser("brave", name: "Brave")],
        preferences: BrowserPreferences(orderedIDs: ["missing", "safari", "safari"]), excluding: ownID
    )
    #expect(catalog.map(\.id) == ["safari", "brave", "chrome"])
    #expect(catalog[0].applicationURL.isFileURL)
}

@Test @MainActor func preferencesRoundTripAndInvalidStoredTypes() {
    let name = "LinkPortTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = DefaultsPreferenceStore(defaults: defaults)
    #expect(store.load() == BrowserPreferences())
    let preferences = BrowserPreferences(orderedIDs: ["chrome", "safari"], hiddenIDs: ["chrome"], hasSeenWelcome: true)
    store.save(preferences)
    #expect(DefaultsPreferenceStore(defaults: defaults).load() == preferences)
    defaults.set(123, forKey: "browserOrder")
    defaults.set("bad value", forKey: "hiddenBrowsers")
    #expect(store.load().orderedIDs.isEmpty)
    #expect(store.load().hiddenIDs.isEmpty)
}

@Test(arguments: AppLanguage.allCases) @MainActor
func languagePreferencePersistsWithoutChangingBrowserPreferences(_ language: AppLanguage) {
    let name = "LinkPortLanguageTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    let store = DefaultsPreferenceStore(defaults: defaults)
    store.save(BrowserPreferences(orderedIDs: ["safari", "chrome"], hiddenIDs: ["chrome"], hasSeenWelcome: true))
    let model = LinkController(bundleID: ownID, system: FakeSystem(), store: store)
    model.receive([url()])
    let selected = model.selectedID
    model.setLanguage(language)
    let saved = DefaultsPreferenceStore(defaults: defaults).load()
    #expect(saved.language == language)
    #expect(model.preferences == saved)
    #expect(saved.orderedIDs == ["safari", "chrome"])
    #expect(saved.hiddenIDs == ["chrome"])
    #expect(saved.hasSeenWelcome)
    #expect(model.queue.current == url())
    #expect(model.selectedID == selected)
    #expect(LinkController(bundleID: ownID, system: FakeSystem(), store: store).preferences.language == language)
}

@Test(arguments: ["unsupported", "", "zh-Hant", "123"]) @MainActor
func invalidLanguagePreferencesFallBackToSystem(_ value: String) {
    let name = "LinkPortLanguageTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defer { defaults.removePersistentDomain(forName: name) }
    defaults.set(value, forKey: "appLanguage")
    #expect(DefaultsPreferenceStore(defaults: defaults).load().language == .system)
    defaults.set(["en"], forKey: "appLanguage")
    #expect(DefaultsPreferenceStore(defaults: defaults).load().language == .system)
}

@Test func languageSelectionOverridesSystemAndMatchesSupportedLocalizations() {
    #expect(AppLanguage.english.localizationIdentifier(preferredLanguages: ["zh-Hans-CN"]) == "en")
    #expect(AppLanguage.simplifiedChinese.localizationIdentifier(preferredLanguages: ["en-US"]) == "zh-Hans")
    #expect(AppLanguage.system.localizationIdentifier(preferredLanguages: ["zh-CN"]) == "zh-Hans")
    #expect(AppLanguage.system.localizationIdentifier(preferredLanguages: ["en-US", "zh-Hans"]) == "en")
    #expect(AppLanguage.system.localizationIdentifier(preferredLanguages: ["fr-FR", "zh-Hans-CN"]) == "zh-Hans")
    #expect(AppLanguage.system.localizationIdentifier(preferredLanguages: ["ja-JP"]) == "en")
    #expect(AppLanguage.system.localizationIdentifier(preferredLanguages: []) == "en")
}

@Test @MainActor func selectionVisibilityAndRefresh() {
    let (model, system, store) = fixture()
    #expect(model.visibleBrowsers.map(\.id) == ["chrome", "safari"])
    model.select("safari")
    #expect(model.selectedID == "safari")
    model.select("missing")
    #expect(model.selectedID == "safari")
    model.moveSelection(by: -100)
    #expect(model.selectedID == "chrome")
    model.moveSelection(by: 100)
    #expect(model.selectedID == "safari")
    model.setHidden("safari", hidden: true)
    #expect(model.selectedID == "chrome")
    model.setHidden("missing", hidden: true)
    #expect(store.value.hiddenIDs == ["safari"])
    model.setHidden("chrome", hidden: true)
    model.moveSelection(by: 1)
    #expect(model.selectedID == nil)
    model.setHidden("safari", hidden: false)
    #expect(model.visibleBrowsers.map(\.id) == ["safari"])
    system.browsers = [browser("new"), browser("chrome")]
    model.refresh()
    #expect(model.visibleBrowsers.map(\.id) == ["new"])
    #expect(store.value.orderedIDs == ["chrome", "safari", "new"])
    model.finishWelcome()
    #expect(store.value.hasSeenWelcome)
}

@Test @MainActor func browserReorderPersistsAndRejectsInvalidMoves() {
    let (model, _, store) = fixture(BrowserPreferences(orderedIDs: ["missing", "chrome", "safari"]))
    model.moveBrowsers(fromOffsets: IndexSet(integer: 1), toOffset: 0)
    #expect(model.browsers.map(\.id) == ["safari", "chrome"])
    #expect(store.value.orderedIDs == ["safari", "chrome", "missing"])
    model.moveBrowser("safari", by: 1)
    #expect(model.browsers.map(\.id) == ["chrome", "safari"])
    model.moveBrowser("chrome", by: -1)
    model.moveBrowser("missing", by: 1)
    model.moveBrowsers(fromOffsets: IndexSet(integer: 2), toOffset: 0)
    model.moveBrowsers(fromOffsets: IndexSet(integer: 0), toOffset: 3)
    model.moveBrowsers(fromOffsets: IndexSet(integer: 0), toOffset: 0)
    #expect(model.browsers.map(\.id) == ["chrome", "safari"])
}

@Test(arguments: [
    (source: [0], destination: 4, expected: ["b", "c", "d", "a"]),
    (source: [3], destination: 0, expected: ["d", "a", "b", "c"]),
    (source: [0], destination: 2, expected: ["b", "a", "c", "d"]),
    (source: [1, 2], destination: 4, expected: ["a", "d", "b", "c"]),
    (source: [0, 2], destination: 4, expected: ["b", "d", "a", "c"]),
    (source: [1], destination: 2, expected: ["a", "b", "c", "d"]),
    (source: [], destination: 0, expected: ["a", "b", "c", "d"]),
    (source: [4], destination: 0, expected: ["a", "b", "c", "d"]),
    (source: [0], destination: -1, expected: ["a", "b", "c", "d"]),
    (source: [0], destination: 5, expected: ["a", "b", "c", "d"]),
]) @MainActor
func browserRowsMoveToInsertionOffsets(_ scenario: (source: [Int], destination: Int, expected: [String])) {
    let system = FakeSystem()
    system.browsers = ["a", "b", "c", "d"].map { browser($0) }
    let store = MemoryStore(BrowserPreferences(
        orderedIDs: ["a", "b", "c", "d", "missing"], hiddenIDs: ["b"],
        hasSeenWelcome: true, language: .simplifiedChinese
    ))
    let model = LinkController(bundleID: ownID, system: system, store: store)
    model.receive([url()])
    model.select("c")
    model.moveBrowsers(fromOffsets: IndexSet(scenario.source), toOffset: scenario.destination)
    #expect(model.browsers.map(\.id) == scenario.expected)
    #expect(store.value.orderedIDs == scenario.expected + ["missing"])
    #expect(store.value.hiddenIDs == ["b"])
    #expect(store.value.language == .simplifiedChinese)
    #expect(store.value.hasSeenWelcome)
    #expect(model.selectedID == "c")
    #expect(model.queue.current == url())
    #expect(LinkController(bundleID: ownID, system: system, store: store).browsers.map(\.id) == scenario.expected)
}

@Test @MainActor func copyPreservesFullURLWithoutLaunchingBrowser() {
    let (model, system, _) = fixture()
    model.receive([url(), url("http://example.org/next")])
    model.copyCurrent()
    #expect(system.copied == [url().absoluteString])
    #expect(system.opened.isEmpty)
    #expect(model.queue.count == 1)
    model.copyCurrent()
    model.copyCurrent()
    #expect(model.queue.count == 0)
    #expect(system.copied.count == 2)
}

@Test @MainActor func copyFailureRetainsQueueAndCanRetry() {
    let (model, system, _) = fixture()
    model.receive([url()])
    system.copyError = LinkPortIssue.copyFailed
    model.copyCurrent()
    #expect(model.queue.current == url())
    #expect(model.issue == .copyFailed)
    model.dismissIssue()
    #expect(model.issue == nil)
    system.copyError = nil
    model.copyCurrent()
    #expect(model.queue.current == nil)
}

@Test @MainActor func opensChosenBrowserAndAdvancesQueue() async {
    let (model, system, _) = fixture()
    model.receive([url(), url("https://example.org")])
    await model.open("safari")
    #expect(system.opened.count == 1)
    #expect(system.opened.first?.0 == url())
    #expect(system.opened.first?.1 == "safari")
    #expect(model.queue.count == 1)
    model.select("chrome")
    await model.open()
    await model.open()
    #expect(system.opened.count == 2)
    #expect(model.queue.current == nil)
    #expect(!model.isOpening)
}

@Test(arguments: [LinkPortIssue.openFailed, .browserUnavailable]) @MainActor
func openFailuresKeepURL(_ failure: LinkPortIssue) async {
    let (model, system, _) = fixture()
    model.receive([url()])
    system.openError = failure
    await model.open("chrome")
    #expect(model.issue == failure)
    #expect(model.queue.current == url())
    #expect(!model.isOpening)
    system.openError = nil
    await model.open("safari")
    #expect(model.queue.current == nil)
}

@Test @MainActor func missingOrHiddenBrowserNeverOpens() async {
    let (model, system, _) = fixture()
    model.receive([url()])
    await model.open("missing")
    #expect(model.issue == .browserUnavailable)
    model.setHidden("chrome", hidden: true)
    await model.open("chrome")
    #expect(system.opened.isEmpty)
    #expect(model.queue.count == 1)
    model.cancel()
    #expect(model.queue.count == 0)
    #expect(model.issue == nil)
}

@Test @MainActor func mixedInputSkipsInvalidLinksAndDeduplicatesPendingOnly() {
    let (model, _, _) = fixture()
    model.receive([url("mailto:test@example.com"), url(), url()])
    model.receive([url()])
    #expect(model.issue == .invalidURL)
    #expect(model.queue.count == 1)
    model.copyCurrent()
    model.receive([url()])
    #expect(model.issue == nil)
    #expect(model.queue.count == 1)
}

@Test @MainActor func cancellationInvalidatesAnInFlightCompletion() async {
    let (model, system, _) = fixture()
    model.receive([url()])
    system.pauseOpening = true
    let task = Task { await model.open("chrome") }
    while system.continuation == nil { await Task.yield() }
    await model.open("safari")
    model.copyCurrent()
    #expect(system.copied.isEmpty)
    model.cancel()
    let next = url("https://example.org/new")
    model.receive([next])
    system.continuation?.resume()
    await task.value
    #expect(model.queue.current == next)
    #expect(!model.isOpening)
}

@Test @MainActor func defaultChangeChecksBothSchemesAndIsIdempotent() async {
    let (model, system, _) = fixture()
    #expect(!model.isDefault)
    await model.makeDefault()
    #expect(system.requestedSchemes == ["http", "https"])
    #expect(model.isDefault)
    #expect(model.issue == nil)
    #expect(!model.isSettingDefault)
    await model.makeDefault()
    #expect(system.requestedSchemes.count == 2)
}

@Test(arguments: [true, false]) @MainActor func refusalStopsAfterHTTP(throwsError: Bool) async {
    let (model, system, _) = fixture()
    system.acceptsDefault = false
    if throwsError { system.defaultError = LinkPortIssue.defaultChangeFailed }
    await model.makeDefault()
    #expect(system.requestedSchemes == ["http"])
    #expect(model.issue == .defaultChangeFailed)
    #expect(!model.isDefault)
    #expect(!model.isSettingDefault)
}

@Test @MainActor func fixesPartialDefaultState() async {
    let (model, system, _) = fixture()
    system.handlers.http = ownID
    model.refresh()
    await model.makeDefault()
    #expect(system.requestedSchemes == ["https"])
    #expect(model.isDefault)
}

@Test(arguments: [CGPoint(x: 0, y: 0), CGPoint(x: 1920, y: 1080), CGPoint(x: 1910, y: 15), CGPoint(x: 900, y: 500)])
func pickerStaysInsideScreen(_ pointer: CGPoint) {
    let screen = CGRect(x: 0, y: 30, width: 1920, height: 1010)
    let frame = PickerGeometry.frame(size: CGSize(width: 474, height: 426), pointer: pointer, visibleFrame: screen)
    #expect(screen.insetBy(dx: 12, dy: 12).contains(frame))
}

@Test func pickerHandlesNegativeMonitorCoordinatesAndOversizedContent() {
    let screen = CGRect(x: -1280, y: -800, width: 1280, height: 800)
    let frame = PickerGeometry.frame(size: CGSize(width: 2000, height: 1000), pointer: CGPoint(x: -1279, y: -799), visibleFrame: screen)
    #expect(frame == screen.insetBy(dx: 12, dy: 12))
    #expect(DefaultHandlers().isDefault(ownID) == false)
}
