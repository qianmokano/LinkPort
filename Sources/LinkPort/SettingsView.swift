import AppKit
import LinkPortCore
import Observation
import SwiftUI

private enum SettingsPage: String, CaseIterable {
    case general, browsers, about
    var title: String { L10n.text("settings.\(rawValue)") }
    var symbol: String {
        switch self {
        case .general: "switch.2"
        case .browsers: "globe"
        case .about: "info.circle"
        }
    }
}

@MainActor @Observable
private final class SettingsNavigation {
    var page: SettingsPage = .general
}

struct SettingsView: View {
    let model: LinkController
    let preview: () -> Void
    private let navigation = SettingsNavigation()
    private var page: SettingsPage { navigation.page }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LinkPort").font(.headline)
                        Text(L10n.text("app.tagline")).font(.caption2).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 20).padding(.bottom, 12)
                ForEach(SettingsPage.allCases, id: \.self) { item in
                    Button { navigation.page = item } label: {
                        Label(item.title, systemImage: item.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 10)
                            .background(page == item ? Color.teal.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(page == item ? Color.teal : Color.primary)
                    }.buttonStyle(.plain)
                        .accessibilityAddTraits(page == item ? [.isSelected] : [])
                }
                Spacer()
                Label(L10n.text("privacy.local"), systemImage: "lock.shield")
                    .font(.caption2).foregroundStyle(.secondary).padding(.bottom, 18)
            }
            .padding(.horizontal, 14).frame(width: 182).background(.thinMaterial)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(page.title).font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text(L10n.text("settings.\(page.rawValue).subtitle")).foregroundStyle(.secondary).font(.callout)
                    }
                    switch page {
                    case .general: general
                    case .browsers: browsers
                    case .about: about
                    }
                    if let issue = model.issue { IssueBanner(issue: issue) }
                }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
            }.background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(.teal)
    }

    private var general: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !model.preferences.hasSeenWelcome {
                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.text("welcome.title"), systemImage: "sparkles").font(.headline)
                    Text(L10n.text("welcome.body")).font(.callout).foregroundStyle(.secondary)
                    Button(L10n.text("welcome.done")) { model.finishWelcome() }.buttonStyle(.bordered)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: model.isDefault ? "checkmark.circle.fill" : "arrow.triangle.branch")
                        .font(.system(size: 25)).foregroundStyle(.teal).frame(width: 34)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text(model.isDefault ? "status.default" : "status.notDefault")).font(.headline)
                        Text(L10n.text("default.description")).font(.callout).foregroundStyle(.secondary)
                    }
                }
                if !model.isDefault {
                    Button {
                        Task { await model.makeDefault() }
                    } label: {
                        HStack(spacing: 8) {
                            if model.isSettingDefault { ProgressView().controlSize(.mini) }
                            Text(L10n.text("default.make"))
                        }
                    }.buttonStyle(.borderedProminent).disabled(model.isSettingDefault)
                }
                HStack {
                    Label("HTTP", systemImage: model.handlers.http == model.bundleID ? "checkmark.circle.fill" : "circle")
                    Label("HTTPS", systemImage: model.handlers.https == model.bundleID ? "checkmark.circle.fill" : "circle")
                }.font(.caption).foregroundStyle(.secondary)
                Text(L10n.text("default.manual")).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }.settingsCard()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L10n.text("picker.preview"), systemImage: "cursorarrow.click").font(.headline)
                    Spacer()
                    Button(L10n.text("picker.try"), action: preview).buttonStyle(.bordered)
                }
                Text(L10n.text("picker.preview.description")).font(.callout).foregroundStyle(.secondary)
                Divider()
                shortcutRow("⌘1–9", "shortcut.choose")
                shortcutRow("← ↑ ↓ →  ↩", "shortcut.navigate")
                shortcutRow("⌘C", "shortcut.copy")
                shortcutRow("Esc", "shortcut.cancel")
            }.settingsCard()
        }
    }

    private var browsers: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.format("browsers.count", model.visibleBrowsers.count, model.browsers.count))
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button { model.refresh() } label: { Label(L10n.text("browsers.refresh"), systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered)
            }
            Text(L10n.text("browsers.instructions")).font(.caption).foregroundStyle(.secondary)
            if model.browsers.isEmpty {
                ContentUnavailableView(L10n.text("browsers.empty"), systemImage: "globe",
                                       description: Text(L10n.text("browsers.empty.description")))
            } else {
                VStack(spacing: 1) {
                    ForEach(Array(model.browsers.enumerated()), id: \.element.id) { index, browser in
                        browserRow(browser, index: index)
                    }
                }
            }
            if !model.browsers.isEmpty && model.visibleBrowsers.isEmpty {
                Label(L10n.text("browsers.allHidden"), systemImage: "eye.slash").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func browserRow(_ browser: Browser, index: Int) -> some View {
        let hidden = model.preferences.hiddenIDs.contains(browser.id)
        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary).font(.caption)
            BrowserIcon(browser: browser, size: 32).opacity(hidden ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(browser.name).fontWeight(.medium).foregroundStyle(hidden ? .secondary : .primary)
                Text(hidden ? L10n.text("browsers.hidden") : browser.id).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Button { model.moveBrowser(browser.id, by: -1) } label: { Image(systemName: "chevron.up") }
                    .disabled(index == 0).help(L10n.text("browsers.moveUp"))
                    .accessibilityLabel(L10n.format("browsers.moveUpNamed", browser.name))
                Button { model.moveBrowser(browser.id, by: 1) } label: { Image(systemName: "chevron.down") }
                    .disabled(index == model.browsers.count - 1).help(L10n.text("browsers.moveDown"))
                    .accessibilityLabel(L10n.format("browsers.moveDownNamed", browser.name))
                Button { model.setHidden(browser.id, hidden: !hidden) } label: {
                    Image(systemName: hidden ? "eye.slash" : "eye").frame(width: 20)
                }.help(L10n.text(hidden ? "browsers.show" : "browsers.hide"))
                    .accessibilityLabel(L10n.format(hidden ? "browsers.showNamed" : "browsers.hideNamed", browser.name))
            }.buttonStyle(.borderless).foregroundStyle(.secondary)
        }
        .padding(12).background(.background, in: RoundedRectangle(cornerRadius: 10))
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

    private var about: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 6) {
                    Text("LinkPort").font(.title2.weight(.semibold))
                    Text(L10n.format("about.version", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"))
                        .foregroundStyle(.secondary)
                    Text("macOS 26+ · Apple Silicon & Intel").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                Label(L10n.text("about.privacy.title"), systemImage: "lock.shield").font(.headline)
                Text(L10n.text("about.privacy.body")).foregroundStyle(.secondary).font(.callout)
                Divider()
                Text(L10n.text("about.scope")).foregroundStyle(.secondary).font(.callout)
            }.settingsCard()
        }
    }

    private func shortcutRow(_ keys: String, _ key: String) -> some View {
        HStack {
            Text(L10n.text(key)).foregroundStyle(.secondary)
            Spacer()
            Text(keys).font(.system(.caption, design: .monospaced))
        }.font(.callout)
    }
}

private extension View {
    func settingsCard() -> some View {
        padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.06)))
    }
}

