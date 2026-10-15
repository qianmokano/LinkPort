import AppKit
import LinkPortCore
import SwiftUI

@MainActor
enum SettingsPage: String, CaseIterable {
    case general, browsers, about

    var title: String { L10n.text("settings.\(rawValue)") }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .browsers: "globe"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class SettingsTabController: NSTabViewController {
    init(model: LinkController, preview: @escaping () -> Void, changeLanguage: @escaping (AppLanguage) -> Void) {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        canPropagateSelectedChildViewControllerTitle = true
        transitionOptions = []
        for page in SettingsPage.allCases {
            let pane = NSHostingController(rootView: SettingsView(page: page, model: model, preview: preview, changeLanguage: changeLanguage))
            pane.title = page.title
            pane.preferredContentSize = NSSize(width: 640, height: 600)
            let item = NSTabViewItem(viewController: pane)
            item.identifier = page.rawValue
            item.label = page.title
            item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
            addTabViewItem(item)
        }
    }

    required init?(coder: NSCoder) { nil }

    func updateLocalization() {
        for item in tabViewItems {
            guard let identifier = item.identifier as? String,
                  let page = SettingsPage(rawValue: identifier) else { continue }
            item.viewController?.title = page.title
            item.label = page.title
            item.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
        }
        viewIfLoaded?.window?.title = tabViewItems[selectedTabViewItemIndex].label
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.toolbar?.allowsUserCustomization = false
        view.window?.toolbar?.displayMode = .iconAndLabel
        view.window?.title = title ?? L10n.text("settings.general")
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        viewIfLoaded?.window?.title = tabViewItem?.label ?? "LinkPort"
    }
}

struct SettingsView: View {
    let page: SettingsPage
    let model: LinkController
    let preview: () -> Void
    let changeLanguage: (AppLanguage) -> Void

    var body: some View {
        Form {
            switch page {
            case .general: general
            case .browsers: browsers
            case .about: about
            }
            if let issue = model.issue {
                Section { IssueBanner(issue: issue) }
            }
        }
        .formStyle(.grouped)
        .controlSize(.regular)
        .environment(\.locale, L10n.locale)
        // Recreate accessibility groups to clear their cached localized labels.
        .id(L10n.locale.identifier)
    }

    @ViewBuilder
    private var general: some View {
        if !model.preferences.hasSeenWelcome {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.text("welcome.body")).foregroundStyle(.secondary)
                    Button(L10n.text("welcome.done")) { model.finishWelcome() }
                }.padding(.vertical, 4)
            } header: {
                Label(L10n.text("welcome.title"), systemImage: "hand.wave")
            }
        }
        Section {
            Picker(L10n.text("language.title"), selection: Binding(
                get: { model.preferences.language },
                set: { changeLanguage($0) }
            )) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(L10n.languageName(language)).tag(language)
                }
            }
            .pickerStyle(.menu)
        } footer: {
            Text(L10n.text("language.description"))
        }
        Section {
            LabeledContent {
                Label(L10n.text(model.isDefault ? "status.default.short" : "status.notDefault.short"),
                      systemImage: model.isDefault ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(model.isDefault ? Color.green : Color.secondary)
            } label: {
                Text(L10n.text("default.browser"))
                Text(L10n.text("default.description"))
            }
            if !model.isDefault {
                HStack {
                    Spacer()
                    if model.isSettingDefault { ProgressView().controlSize(.small) }
                    Button(L10n.text("default.make")) { Task { await model.makeDefault() } }
                        .buttonStyle(.borderedProminent).disabled(model.isSettingDefault)
                }
            }
            LabeledContent("HTTP") { handlerStatus(model.handlers.http == model.bundleID) }
            LabeledContent("HTTPS") { handlerStatus(model.handlers.https == model.bundleID) }
        } footer: {
            Text(L10n.text("default.manual")).textSelection(.enabled)
        }
        Section {
            LabeledContent {
                Button(L10n.text("picker.try"), action: preview)
            } label: {
                Text(L10n.text("picker.preview"))
                Text(L10n.text("picker.preview.description"))
            }
        }
        Section(L10n.text("shortcut.title")) {
            shortcutRow("⌘1–9", "shortcut.choose")
            shortcutRow("← ↑ ↓ →  ↩", "shortcut.navigate")
            shortcutRow("⌘C", "shortcut.copy")
            shortcutRow("Esc", "shortcut.cancel")
        }
    }

    @ViewBuilder
    private var browsers: some View {
        Section {
            LabeledContent {
                Button { model.refresh() } label: { Label(L10n.text("browsers.refresh"), systemImage: "arrow.clockwise") }
            } label: {
                Text(L10n.format("browsers.count", model.visibleBrowsers.count, model.browsers.count))
            }
        } footer: {
            Text(L10n.text("browsers.instructions"))
        }
        Section {
            if model.browsers.isEmpty {
                ContentUnavailableView(L10n.text("browsers.empty"), systemImage: "globe",
                                       description: Text(L10n.text("browsers.empty.description")))
            } else {
                ForEach(Array(model.browsers.enumerated()), id: \.element.id) { index, browser in
                    browserRow(browser, index: index)
                }
            }
        } footer: {
            if !model.browsers.isEmpty && model.visibleBrowsers.isEmpty {
                Text(L10n.text("browsers.allHidden"))
            }
        }
    }

    private func browserRow(_ browser: Browser, index: Int) -> some View {
        let hidden = model.preferences.hiddenIDs.contains(browser.id)
        return HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).font(.caption)
                .accessibilityHidden(true)
            BrowserIcon(browser: browser, size: 32).opacity(hidden ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(browser.name).foregroundStyle(hidden ? .secondary : .primary)
                Text(browser.id).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            ControlGroup {
                Button { model.moveBrowser(browser.id, by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(index == 0).help(L10n.text("browsers.moveUp"))
                    .accessibilityLabel(L10n.format("browsers.moveUpNamed", browser.name))
                Button { model.moveBrowser(browser.id, by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(index == model.browsers.count - 1).help(L10n.text("browsers.moveDown"))
                    .accessibilityLabel(L10n.format("browsers.moveDownNamed", browser.name))
            }.controlSize(.small)
            Toggle(L10n.format("browsers.showNamed", browser.name), isOn: Binding(
                get: { !model.preferences.hiddenIDs.contains(browser.id) },
                set: { model.setHidden(browser.id, hidden: !$0) }
            ))
            .toggleStyle(.switch).labelsHidden()
            .help(L10n.text(hidden ? "browsers.show" : "browsers.hide"))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .draggable("linkport-browser:\(browser.id)")
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first, value.hasPrefix("linkport-browser:") else { return false }
            let id = String(value.dropFirst("linkport-browser:".count))
            guard model.browsers.contains(where: { $0.id == id }) else { return false }
            model.moveBrowser(id, before: browser.id)
            return true
        }
    }

    @ViewBuilder
    private var about: some View {
        Section {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 80, height: 80)
                    .accessibilityHidden(true)
                Text("LinkPort").font(.title2.weight(.semibold))
                Text(L10n.format("about.version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"))
                    .foregroundStyle(.secondary)
                Text(L10n.text("app.tagline")).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity).padding(.vertical, 12)
            LabeledContent(L10n.text("about.compatibility"), value: "macOS 26+")
            LabeledContent(L10n.text("about.architectures"), value: "Apple Silicon & Intel")
        }
        Section {
            Label(L10n.text("about.privacy.body"), systemImage: "lock.shield")
                .foregroundStyle(.secondary)
        } header: {
            Text(L10n.text("about.privacy.title"))
        } footer: {
            Text(L10n.text("about.scope"))
        }
    }

    private func shortcutRow(_ keys: String, _ key: String) -> some View {
        LabeledContent(L10n.text(key)) {
            Text(keys).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
        }
    }

    private func handlerStatus(_ handled: Bool) -> some View {
        Label(L10n.text(handled ? "status.enabled" : "status.notEnabled"),
              systemImage: handled ? "checkmark.circle" : "minus.circle")
            .foregroundStyle(.secondary)
    }
}
