import AppKit
import LinkPortCore
import SwiftUI

@main
enum LinkPortApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private lazy var model = LinkController(
        bundleID: Bundle.main.bundleIdentifier ?? "com.linkport.app",
        system: NativeBrowserSystem(), store: DefaultsPreferenceStore()
    )
    private lazy var picker = PickerWindowController(model: model, openSettings: { [weak self] in self?.showSettings() })
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var receivedLink = false
    private var lastLinkReceipt = Date.distantPast
    private var launchCompleted = false
    private var refreshObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "LinkPort")
        item.button?.toolTip = "LinkPort"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
        launchCompleted = true
        refreshObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                // Refresh default status after returning from System Settings.
                if self.settingsWindow?.isVisible == true { self.model.refresh() }
            }
        }
        if model.queue.current != nil { picker.present() }
        else if receivedLink { showSettings() }
        // The URL event for a cold launch can arrive just after didFinishLaunching.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, !self.receivedLink else { return }
            self.showSettings()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedLink = true
        lastLinkReceipt = Date()
        model.receive(urls)
        if launchCompleted {
            if model.queue.current != nil { picker.present() } else { showSettings() }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen can precede an incoming URL on a running accessory app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.model.queue.current == nil,
                  Date().timeIntervalSince(self.lastLinkReceipt) > 0.5 else { return }
            self.showSettings()
        }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        if let refreshObserver { NSWorkspace.shared.notificationCenter.removeObserver(refreshObserver) }
    }

    func menuWillOpen(_ menu: NSMenu) {
        model.refresh()
        menu.removeAllItems()
        let state = NSMenuItem(title: L10n.text(model.isDefault ? "status.default" : "status.notDefault"), action: nil, keyEquivalent: "")
        state.image = NSImage(systemSymbolName: model.isDefault ? "checkmark.circle.fill" : "circle.dashed", accessibilityDescription: nil)
        menu.addItem(state)
        if !model.isDefault { addItem("default.make", action: #selector(makeDefault), to: menu) }
        menu.addItem(.separator())
        addItem("settings.title", action: #selector(openSettings), key: ",", to: menu)
        addItem("picker.preview", action: #selector(previewPicker), to: menu)
        menu.addItem(.separator())
        addItem("app.quit", action: #selector(quit), key: "q", to: menu)
    }

    private func addItem(_ title: String, action: Selector, key: String = "", to menu: NSMenu) {
        let item = NSMenuItem(title: L10n.text(title), action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func installMainMenu() {
        let main = NSMenu()
        let app = NSMenuItem()
        let appMenu = NSMenu()
        addItem("settings.title", action: #selector(openSettings), key: ",", to: appMenu)
        appMenu.addItem(.separator())
        addItem("app.quit", action: #selector(quit), key: "q", to: appMenu)
        app.submenu = appMenu
        main.addItem(app)
        let edit = NSMenuItem(title: L10n.text("menu.edit"), action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: edit.title)
        for (title, selector, key) in [
            ("menu.copy", #selector(NSText.copy(_:)), "c"),
            ("menu.selectAll", #selector(NSText.selectAll(_:)), "a"),
        ] { editMenu.addItem(withTitle: L10n.text(title), action: selector, keyEquivalent: key) }
        edit.submenu = editMenu
        main.addItem(edit)
        NSApp.mainMenu = main
    }

    @objc private func openSettings() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func makeDefault() {
        showSettings()
        Task { await model.makeDefault() }
    }
    @objc private func previewPicker() {
        guard let url = URL(string: "https://example.com/linkport?hello=world#preview") else { return }
        model.receive([url])
        picker.present()
    }

    private func showSettings() {
        if model.isOpening { return }
        if model.queue.current != nil { picker.cancel() }
        model.refresh()
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 600),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L10n.text("settings.general")
            window.toolbarStyle = .preference
            window.isReleasedWhenClosed = false
            window.contentViewController = SettingsTabController(model: model, preview: { [weak self] in self?.previewPicker() })
            window.setContentSize(NSSize(width: 640, height: 600))
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
