import AppKit
import LinkPortCore

@MainActor
final class NativeBrowserSystem: BrowserSystem {
    private let workspace = NSWorkspace.shared

    func discoverBrowsers() -> [Browser] {
        let candidates = ["http://example.com", "https://example.com"].compactMap(URL.init(string:))
            .flatMap { workspace.urlsForApplications(toOpen: $0) }
        return candidates.compactMap { url in
            guard FileManager.default.fileExists(atPath: url.path),
                  let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier else { return nil }
            let name = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                ?? url.deletingPathExtension().lastPathComponent
            return Browser(id: id, name: name, applicationURL: url)
        }
    }

    func open(_ url: URL, in browser: Browser) async throws {
        guard browser.id != Bundle.main.bundleIdentifier else { throw LinkPortIssue.browserUnavailable }
        let target: URL
        if FileManager.default.fileExists(atPath: browser.applicationURL.path) {
            target = browser.applicationURL
        } else if let relocated = workspace.urlForApplication(withBundleIdentifier: browser.id) {
            target = relocated
        } else { throw LinkPortIssue.browserUnavailable }
        guard Bundle(url: target)?.bundleIdentifier == browser.id else { throw LinkPortIssue.browserUnavailable }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await workspace.open([url], withApplicationAt: target, configuration: configuration)
    }

    func copy(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { throw LinkPortIssue.copyFailed }
    }

    func defaultHandlers() -> DefaultHandlers {
        func handler(_ value: String) -> String? {
            guard let url = URL(string: value), let app = workspace.urlForApplication(toOpen: url) else { return nil }
            return Bundle(url: app)?.bundleIdentifier
        }
        return DefaultHandlers(http: handler("http:"), https: handler("https:"))
    }

    func setDefaultHandler(for scheme: String) async throws {
        try await workspace.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
    }
}

