import AppKit
import LinkPortCore
import SwiftUI

struct BrowserListView: NSViewRepresentable {
    let browsers: [Browser]
    let hiddenIDs: Set<String>
    let move: (IndexSet, Int) -> Void
    let moveBy: (String, Int) -> Void
    let setHidden: (String, Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        table.headerView = nil
        table.style = .inset
        table.backgroundColor = .clear
        table.rowHeight = 56
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.allowsMultipleSelection = true
        table.verticalMotionCanBeginDrag = true
        table.draggingDestinationFeedbackStyle = .gap
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.setDraggingSourceOperationMask([], forLocal: false)
        table.registerForDraggedTypes([Coordinator.pasteboardType])
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.autoresizingMask = [.width]
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("browser"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = table
        table.reloadData()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        context.coordinator.update(self, in: table)
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        static let pasteboardType = NSPasteboard.PasteboardType("com.linkport.browser-row")
        private var parent: BrowserListView

        init(parent: BrowserListView) { self.parent = parent }

        func numberOfRows(in tableView: NSTableView) -> Int { parent.browsers.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let identifier = NSUserInterfaceItemIdentifier("browser-cell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? BrowserCellView ?? BrowserCellView()
            cell.identifier = identifier
            configure(cell, at: row)
            return cell
        }

        func update(_ parent: BrowserListView, in table: NSTableView) {
            let oldIDs = self.parent.browsers.map(\.id)
            let newIDs = parent.browsers.map(\.id)
            let selectedIDs = Set(table.selectedRowIndexes.compactMap { oldIDs.indices.contains($0) ? oldIDs[$0] : nil })
            self.parent = parent
            if oldIDs != newIDs {
                if Set(oldIDs) == Set(newIDs) {
                    var order = oldIDs
                    table.beginUpdates()
                    for (destination, id) in newIDs.enumerated() {
                        guard let source = order.firstIndex(of: id), source != destination else { continue }
                        table.moveRow(at: source, to: destination)
                        order.insert(order.remove(at: source), at: destination)
                    }
                    table.endUpdates()
                } else {
                    table.reloadData()
                }
                table.selectRowIndexes(IndexSet(newIDs.indices.filter { selectedIDs.contains(newIDs[$0]) }), byExtendingSelection: false)
            }
            for row in parent.browsers.indices {
                if let cell = table.view(atColumn: 0, row: row, makeIfNecessary: false) as? BrowserCellView {
                    configure(cell, at: row)
                }
            }
        }

        private func configure(_ cell: BrowserCellView, at row: Int) {
            let browser = parent.browsers[row]
            cell.configure(browser, index: row, count: parent.browsers.count, hidden: parent.hiddenIDs.contains(browser.id),
                           move: { [weak self] offset in self?.parent.moveBy(browser.id, offset) },
                           setHidden: { [weak self] hidden in self?.parent.setHidden(browser.id, hidden) })
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
            guard parent.browsers.indices.contains(row) else { return nil }
            let item = NSPasteboardItem()
            item.setString(parent.browsers[row].id, forType: Self.pasteboardType)
            return item
        }

        func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession,
                       willBeginAt screenPoint: NSPoint, forRowIndexes rowIndexes: IndexSet) {
            session.animatesToStartingPositionsOnCancelOrFail = true
        }

        func tableView(_ tableView: NSTableView, validateDrop info: any NSDraggingInfo,
                       proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
            guard (0...parent.browsers.count).contains(row), draggedRows(info, in: tableView) != nil else { return [] }
            tableView.setDropRow(row, dropOperation: .above)
            return .move
        }

        func tableView(_ tableView: NSTableView, acceptDrop info: any NSDraggingInfo,
                       row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard dropOperation == .above, (0...parent.browsers.count).contains(row),
                  let source = draggedRows(info, in: tableView) else { return false }
            parent.move(source, row)
            return true
        }

        private func draggedRows(_ info: any NSDraggingInfo, in table: NSTableView) -> IndexSet? {
            guard (info.draggingSource as? NSTableView) === table,
                  let items = info.draggingPasteboard.pasteboardItems, !items.isEmpty else { return nil }
            var rows = IndexSet()
            for item in items {
                guard let id = item.string(forType: Self.pasteboardType),
                      let row = parent.browsers.firstIndex(where: { $0.id == id }) else { return nil }
                rows.insert(row)
            }
            return rows
        }
    }
}

@MainActor
private final class BrowserCellView: NSTableCellView {
    private let icon = NSImageView()
    private let name = NSTextField(labelWithString: "")
    private let bundleID = NSTextField(labelWithString: "")
    private let up = NSButton()
    private let down = NSButton()
    private let visibility = NSSwitch()
    private var move: ((Int) -> Void)?
    private var setHidden: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView = icon
        textField = name
        icon.imageScaling = .scaleProportionallyUpOrDown
        name.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        bundleID.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        bundleID.textColor = .secondaryLabelColor
        for field in [name, bundleID] {
            field.maximumNumberOfLines = 1
            field.cell?.usesSingleLineMode = true
            field.lineBreakMode = .byTruncatingTail
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let handle = NSImageView()
        handle.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: nil)
        handle.contentTintColor = .tertiaryLabelColor
        handle.setAccessibilityElement(false)
        for (button, symbol, action) in [(up, "chevron.up", #selector(moveRowUp)), (down, "chevron.down", #selector(moveRowDown))] {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            button.bezelStyle = .rounded
            button.controlSize = .small
            button.target = self
            button.action = action
            button.setButtonType(.momentaryPushIn)
        }
        visibility.target = self
        visibility.action = #selector(toggleVisibility)
        let controls = NSStackView(views: [up, down])
        controls.spacing = 2
        for view in [handle, icon, name, bundleID, controls, visibility] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            handle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            handle.centerYAnchor.constraint(equalTo: centerYAnchor),
            handle.widthAnchor.constraint(equalToConstant: 12),
            handle.heightAnchor.constraint(equalToConstant: 12),
            icon.leadingAnchor.constraint(equalTo: handle.trailingAnchor, constant: 12),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 32),
            icon.heightAnchor.constraint(equalToConstant: 32),
            name.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            name.trailingAnchor.constraint(equalTo: controls.leadingAnchor, constant: -12),
            name.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            bundleID.leadingAnchor.constraint(equalTo: name.leadingAnchor),
            bundleID.trailingAnchor.constraint(equalTo: name.trailingAnchor),
            bundleID.topAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            controls.trailingAnchor.constraint(equalTo: visibility.leadingAnchor, constant: -12),
            controls.centerYAnchor.constraint(equalTo: centerYAnchor),
            controls.widthAnchor.constraint(equalToConstant: 50),
            visibility.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            visibility.centerYAnchor.constraint(equalTo: centerYAnchor),
            up.widthAnchor.constraint(equalToConstant: 24),
            down.widthAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) { nil }

    func configure(_ browser: Browser, index: Int, count: Int, hidden: Bool,
                   move: @escaping (Int) -> Void, setHidden: @escaping (Bool) -> Void) {
        self.move = move
        self.setHidden = setHidden
        name.stringValue = browser.name
        bundleID.stringValue = browser.id
        bundleID.toolTip = browser.id
        icon.image = NSWorkspace.shared.icon(forFile: browser.applicationURL.path)
        icon.alphaValue = hidden ? 0.4 : 1
        name.textColor = hidden ? .secondaryLabelColor : .labelColor
        up.isEnabled = index > 0
        down.isEnabled = index < count - 1
        up.toolTip = L10n.text("browsers.moveUp")
        down.toolTip = L10n.text("browsers.moveDown")
        up.setAccessibilityLabel(L10n.format("browsers.moveUpNamed", browser.name))
        down.setAccessibilityLabel(L10n.format("browsers.moveDownNamed", browser.name))
        visibility.state = hidden ? .off : .on
        visibility.toolTip = L10n.text(hidden ? "browsers.show" : "browsers.hide")
        visibility.setAccessibilityLabel(L10n.format("browsers.showNamed", browser.name))
    }

    @objc private func moveRowUp() { move?(-1) }
    @objc private func moveRowDown() { move?(1) }
    @objc private func toggleVisibility() { setHidden?(visibility.state == .off) }
}
