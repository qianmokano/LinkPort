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
        Group {
            if page == .browsers {
                browsers
            } else {
                Form {
                    if page == .general { general } else { about }
                    issueSection
                }
                .formStyle(.grouped)
            }
        }
        .controlSize(.regular)
        .environment(\.locale, L10n.locale)
        // Recreate accessibility groups to clear their cached localized labels.
        .id(L10n.locale.identifier)
    }

    @ViewBuilder
    private var issueSection: some View {
        if let issue = model.issue {
            Section { IssueBanner(issue: issue) }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.format("browsers.count", model.visibleBrowsers.count, model.browsers.count))
                Spacer()
                Button { model.refresh() } label: { Label(L10n.text("browsers.refresh"), systemImage: "arrow.clockwise") }
            }
            .padding(.horizontal, 24)
            Text(L10n.text("browsers.instructions"))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            if model.browsers.isEmpty {
                ContentUnavailableView(L10n.text("browsers.empty"), systemImage: "globe",
                                       description: Text(L10n.text("browsers.empty.description")))
            } else {
                BrowserListView(
                    browsers: model.browsers, hiddenIDs: model.preferences.hiddenIDs,
                    move: { model.moveBrowsers(fromOffsets: $0, toOffset: $1) },
                    moveBy: { model.moveBrowser($0, by: $1) },
                    setHidden: { model.setHidden($0, hidden: $1) }
                )
            }
            if !model.browsers.isEmpty && model.visibleBrowsers.isEmpty {
                Text(L10n.text("browsers.allHidden"))
                    .font(.callout).foregroundStyle(.secondary).padding(.horizontal, 24)
            }
            if let issue = model.issue { IssueBanner(issue: issue).padding(.horizontal, 24) }
        }
        .padding(.top, 20).padding(.bottom, 16)
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
