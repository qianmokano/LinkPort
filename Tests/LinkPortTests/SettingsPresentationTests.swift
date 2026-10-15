import AppKit
@testable import LinkPort
import LinkPortCore
import Testing

@MainActor
private final class MemoryStore: PreferenceStore {
    private var value = BrowserPreferences(hasSeenWelcome: true)
    func load() -> BrowserPreferences { value }
    func save(_ preferences: BrowserPreferences) { value = preferences }
}

@MainActor
private final class FakeSystem: BrowserSystem {
    var handlers = DefaultHandlers()
    var openingStarted: (() -> Void)?
    var continuation: CheckedContinuation<Void, Never>?

    func discoverBrowsers() -> [Browser] {
        [Browser(id: "browser", name: "Browser", applicationURL: URL(fileURLWithPath: "/Browser.app"))]
    }
    func defaultHandlers() -> DefaultHandlers { handlers }
    func copy(_ text: String) throws {}
    func setDefaultHandler(for scheme: String) async throws {}
    func open(_ url: URL, in browser: Browser) async throws {
        await withCheckedContinuation {
            continuation = $0
            openingStarted?()
        }
    }
}

@MainActor
private final class SettingsFixture {
    let system = FakeSystem()
    let model: LinkController
    let delegate: AppDelegate
    let menu = NSMenu()
    var presented: [NSWindow] = []

    init() {
        _ = NSApplication.shared
        model = LinkController(bundleID: "com.linkport.tests", system: system, store: MemoryStore())
        var recordPresentation: ((NSWindow) -> Void)?
        delegate = AppDelegate(model: model, presentWindow: { recordPresentation?($0) })
        recordPresentation = { [weak self] in self?.presented.append($0) }
        menu.delegate = delegate
        updateMenu()
    }

    func updateMenu() {
        menu.delegate?.menuNeedsUpdate?(menu)
        menu.update()
    }

    func selectSettings() throws {
        let index = try #require(menu.items.firstIndex { $0.keyEquivalent == "," })
        menu.performActionForItem(at: index)
    }

    func finishMenuAction() async {
        await withCheckedContinuation { continuation in
            RunLoop.main.perform(inModes: [.default]) { continuation.resume() }
        }
    }
}

@Suite(.serialized) @MainActor
struct SettingsPresentationTests {
    @Test func menuUpdatesBeforeTrackingAndReflectsDefaultStatus() {
        let fixture = SettingsFixture()
        #expect(fixture.menu.items.first?.title == L10n.text("status.notDefault"))
        #expect(fixture.menu.items.contains { $0.keyEquivalent == "," && $0.isEnabled })
        #expect(fixture.menu.items.contains { $0.title == L10n.text("default.make") })

        fixture.system.handlers = DefaultHandlers(http: fixture.model.bundleID, https: fixture.model.bundleID)
        fixture.updateMenu()
        #expect(fixture.menu.items.first?.keyEquivalent == ",")
        #expect(!fixture.menu.items.contains { $0.title == L10n.text("status.default") })
        #expect(!fixture.menu.items.contains { $0.title == L10n.text("status.notDefault") })
        #expect(!fixture.menu.items.contains { $0.title == L10n.text("default.make") })
        #expect(fixture.menu.items.filter { $0.keyEquivalent == "," }.count == 1)

        fixture.system.handlers = DefaultHandlers(http: fixture.model.bundleID, https: "other.browser")
        fixture.updateMenu()
        #expect(fixture.menu.items.first?.title == L10n.text("status.notDefault"))
        #expect(fixture.menu.items.contains { $0.title == L10n.text("default.make") })
    }

    @Test func oneSelectionPresentsAfterMenuActionAndReusesWindow() async throws {
        let fixture = SettingsFixture()
        try fixture.selectSettings()
        #expect(fixture.presented.isEmpty)
        await fixture.finishMenuAction()
        let first = try #require(fixture.presented.first)
        #expect(fixture.presented.count == 1)
        #expect(first.collectionBehavior.contains(.moveToActiveSpace))
        #expect(first.collectionBehavior.contains(.fullScreenAuxiliary))

        first.close()
        fixture.updateMenu()
        try fixture.selectSettings()
        await fixture.finishMenuAction()
        #expect(fixture.presented.count == 2)
        #expect(fixture.presented.last === first)
    }

    @Test func settingsCancelsPendingPickerWithoutOpeningBrowser() async throws {
        let fixture = SettingsFixture()
        fixture.model.receive([URL(string: "https://example.com/pending")!])
        try fixture.selectSettings()
        await fixture.finishMenuAction()
        #expect(fixture.presented.count == 1)
        #expect(fixture.model.queue.current == nil)
        #expect(fixture.system.continuation == nil)
    }

    @Test func settingsIsNotDroppedWhileBrowserIsOpening() async throws {
        let fixture = SettingsFixture()
        fixture.model.receive([URL(string: "https://example.com/opening")!])
        let opening = Task { await fixture.model.open("browser") }
        await withCheckedContinuation { continuation in
            fixture.system.openingStarted = { continuation.resume() }
        }
        #expect(fixture.model.isOpening)
        defer { fixture.system.continuation?.resume() }

        try fixture.selectSettings()
        await fixture.finishMenuAction()
        #expect(fixture.presented.count == 1)
        #expect(!fixture.model.isOpening)
        #expect(fixture.model.queue.current == nil)

        let next = URL(string: "https://example.com/new")!
        fixture.model.receive([next])
        fixture.system.continuation?.resume()
        fixture.system.continuation = nil
        await opening.value
        #expect(fixture.model.queue.current == next)
    }
}
