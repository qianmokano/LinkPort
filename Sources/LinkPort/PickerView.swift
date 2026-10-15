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
    static let columnCount = 4

    let model: LinkController
    let inputState: PickerInputState
    let open: (String) -> Void
    let cancel: () -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: PickerView.columnCount)

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(L10n.text("picker.title")).font(.title2.weight(.semibold))
                    Spacer()
                    if model.queue.count > 1 {
                        Text(L10n.format("picker.pending", model.queue.count))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Button(action: cancel) { Image(systemName: "xmark").font(.callout.weight(.medium)) }
                        .buttonStyle(.borderless).foregroundStyle(.secondary)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel(L10n.text("picker.cancel"))
                }
                HStack(spacing: 7) {
                    Image(systemName: "link").foregroundStyle(.secondary)
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
                .scrollIndicators(.automatic)
                .defaultScrollAnchor(.top)
                .scrollEdgeEffectStyle(.soft, for: .vertical)
                .onChange(of: model.selectedID) { _, id in
                    if let id, !inputState.isPointerSelection { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .overlay {
                if model.isOpening {
                    ProgressView().controlSize(.regular).padding(14).background(.background, in: Circle())
                }
            }

            if let issue = model.issue { IssueBanner(issue: issue).padding(.top, 8) }

        }
        .padding(20)
        .environment(\.locale, L10n.locale)
        .id(L10n.locale.identifier)
    }

    private func browserButton(_ browser: Browser, index: Int) -> some View {
        let selected = model.selectedID == browser.id
        return Button { open(browser.id) } label: {
            VStack(spacing: 4) {
                BrowserIcon(browser: browser, size: 48)
                Text(browser.name).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                    .frame(height: 30, alignment: .top)
                Text(index < 9 ? "⌘\(index + 1)" : " ")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(selected ? Color.gray.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain).disabled(model.isOpening)
        .onContinuousHover { phase in
            guard case .active = phase, !model.isOpening,
                  inputState.acceptPointerMovement(at: NSEvent.mouseLocation) else { return }
            model.select(browser.id)
        }
        .accessibilityLabel(L10n.format("picker.openIn", browser.name))
        .accessibilityHint(index < 9 ? "⌘\(index + 1)" : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
