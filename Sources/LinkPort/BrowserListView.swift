import LinkPortCore
import SwiftUI

// Keep the property wrapper for macOS 26 builds; the SDK also exports a State macro.
private typealias BrowserSelectionState = State<Set<String>>

struct BrowserListView: View {
    let browsers: [Browser]
    let hiddenIDs: Set<String>
    let move: (IndexSet, Int) -> Void
    let moveBy: (String, Int) -> Void
    let setHidden: (String, Bool) -> Void
    @BrowserSelectionState private var selection: Set<String> = []

    var body: some View {
        List(selection: $selection) {
            ForEach(browsers) { browser in
                browserRow(browser)
                    .tag(browser.id)
            }
            .onMove(perform: move)
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    private func browserRow(_ browser: Browser) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary).accessibilityHidden(true)
            BrowserIcon(browser: browser, size: 32)
                .opacity(hiddenIDs.contains(browser.id) ? 0.4 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(browser.name).fontWeight(.medium)
                    .foregroundStyle(hiddenIDs.contains(browser.id) ? .secondary : .primary)
                Text(browser.id).font(.caption).foregroundStyle(.secondary)
            }
            .lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(browser.id)
            HStack(spacing: 2) {
                Button { moveBy(browser.id, -1) } label: {
                    Image(systemName: "chevron.up").frame(width: 24, height: 24)
                }
                .disabled(browser.id == browsers.first?.id)
                .help(L10n.text("browsers.moveUp"))
                .accessibilityLabel(L10n.format("browsers.moveUpNamed", browser.name))
                Button { moveBy(browser.id, 1) } label: {
                    Image(systemName: "chevron.down").frame(width: 24, height: 24)
                }
                .disabled(browser.id == browsers.last?.id)
                .help(L10n.text("browsers.moveDown"))
                .accessibilityLabel(L10n.format("browsers.moveDownNamed", browser.name))
            }
            .buttonStyle(.borderless).controlSize(.small)
            Toggle(L10n.format("browsers.showNamed", browser.name), isOn: Binding(
                get: { !hiddenIDs.contains(browser.id) },
                set: { setHidden(browser.id, !$0) }
            ))
            .toggleStyle(.switch).labelsHidden()
            .help(L10n.text(hiddenIDs.contains(browser.id) ? "browsers.show" : "browsers.hide"))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityActions {
            if browser.id != browsers.first?.id {
                Button(L10n.format("browsers.moveUpNamed", browser.name)) { moveBy(browser.id, -1) }
            }
            if browser.id != browsers.last?.id {
                Button(L10n.format("browsers.moveDownNamed", browser.name)) { moveBy(browser.id, 1) }
            }
        }
    }
}
