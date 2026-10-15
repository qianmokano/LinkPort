import AppKit
import LinkPortCore
import SwiftUI

struct BrowserIcon: View {
    let browser: Browser
    var size: CGFloat = 44

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: browser.applicationURL.path))
            .resizable().interpolation(.high).frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct IssueBanner: View {
    let issue: LinkPortIssue
    var body: some View {
        Label(L10n.issue(issue), systemImage: "exclamationmark.circle.fill")
            .font(.callout).foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel(L10n.issue(issue))
    }
}

struct PickerView: View {
    let model: LinkController
    let open: (String) -> Void
    let copy: () -> Void
    let cancel: () -> Void
    let settings: () -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 5)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.triangle.branch").foregroundStyle(.teal)
                Text("LinkPort").fontWeight(.semibold)
                Spacer()
                if model.queue.count > 1 {
                    Text(L10n.format("picker.pending", model.queue.count))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button(action: cancel) { Image(systemName: "xmark").font(.caption.weight(.semibold)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel(L10n.text("picker.cancel"))
            }
            .font(.callout).padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.text("picker.title")).font(.system(size: 22, weight: .semibold, design: .rounded))
                HStack(spacing: 7) {
                    Image(systemName: "link").foregroundStyle(.teal)
                    Text(model.queue.current?.host ?? "").fontWeight(.medium).lineLimit(1)
                }.font(.callout)
                Text(model.queue.current?.absoluteString ?? "")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    .help(model.queue.current?.absoluteString ?? "")
                    .accessibilityLabel(model.queue.current?.absoluteString ?? "")
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 16)

            ScrollViewReader { proxy in
                ScrollView {
                    if model.visibleBrowsers.isEmpty {
                        VStack(spacing: 7) {
                            Image(systemName: "globe.badge.chevron.backward").font(.title2).foregroundStyle(.secondary)
                            Text(L10n.text("picker.empty")).font(.callout)
                            Button(L10n.text("browsers.manage"), action: settings).buttonStyle(.link)
                        }.frame(maxWidth: .infinity).padding(.vertical, 10)
                    } else {
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(Array(model.visibleBrowsers.enumerated()), id: \.element.id) { index, browser in
                                browserButton(browser, index: index)
                                    .id(browser.id)
                            }
                        }.padding(2)
                    }
                }
                .scrollIndicators(.hidden)
                .defaultScrollAnchor(.top)
                .onChange(of: model.selectedID) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .overlay {
                if model.isOpening {
                    ProgressView().controlSize(.small).padding(14).background(.regularMaterial, in: Circle())
                }
            }

            if let issue = model.issue { IssueBanner(issue: issue).padding(.top, 8) }

            Divider().padding(.top, 12).padding(.bottom, 12)
            HStack {
                Button(action: copy) {
                    Label(L10n.text("picker.copy"), systemImage: "doc.on.doc")
                    Text("⌘C").foregroundStyle(.secondary)
                }
                .buttonStyle(.bordered).controlSize(.regular).disabled(model.isOpening)
                Spacer()
                Button(action: settings) { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.plain).font(.system(size: 16)).foregroundStyle(.secondary)
                    .help(L10n.text("settings.title")).accessibilityLabel(L10n.text("settings.title"))
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.08)))
        .tint(.teal)
    }

    private func browserButton(_ browser: Browser, index: Int) -> some View {
        let selected = model.selectedID == browser.id
        return Button { open(browser.id) } label: {
            VStack(spacing: 4) {
                BrowserIcon(browser: browser)
                Text(browser.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(index < 9 ? "⌘\(index + 1)" : " ")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(selected ? Color.teal.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? .teal.opacity(0.55) : .clear))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).disabled(model.isOpening)
        .accessibilityLabel(L10n.format("picker.openIn", browser.name))
        .accessibilityHint(index < 9 ? "⌘\(index + 1)" : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
