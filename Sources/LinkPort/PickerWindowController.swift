import AppKit
import LinkPortCore
import SwiftUI

@MainActor
private final class PickerPanel: NSPanel {
    var handleKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleKey?(event) == true { return }
        super.sendEvent(event)
    }
}

@MainActor
final class PickerInputState {
    private(set) var isPointerSelection = false
    private var lastPointerLocation: CGPoint?

    func reset(at location: CGPoint) {
        lastPointerLocation = location
        isPointerSelection = false
    }

    func acceptPointerMovement(at location: CGPoint) -> Bool {
        // Keyboard scrolling can move a browser under a stationary pointer.
        guard lastPointerLocation != location else { return false }
        lastPointerLocation = location
        isPointerSelection = true
        return true
    }
}

@MainActor
final class PickerWindowController: NSObject, NSWindowDelegate {
    private let model: LinkController
    private let openSettings: () -> Void
    private var panel: PickerPanel?
    private var isDismissing = false
    private let inputState = PickerInputState()

    init(model: LinkController, openSettings: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
    }

    func present() {
        guard model.queue.current != nil else { dismiss(); return }
        if panel == nil { buildPanel() }
        guard let panel else { return }
        if !panel.isVisible {
            let pointer = NSEvent.mouseLocation
            inputState.reset(at: pointer)
            let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
            let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
            let rows = min(max(Int(ceil(Double(model.visibleBrowsers.count) / Double(PickerView.columnCount))), 1), 2)
            let height = CGFloat(132 + rows * 112)
            panel.setFrame(PickerGeometry.frame(size: CGSize(width: 474, height: height), pointer: pointer, visibleFrame: visible), display: true)
        }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func cancel() {
        model.cancel()
        dismiss()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !isDismissing, !model.isOpening else { return }
        cancel()
    }

    private func dismiss() {
        isDismissing = true
        panel?.orderOut(nil)
        isDismissing = false
    }

    private func buildPanel() {
        let panel = PickerPanel(contentRect: .zero, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        panel.isMovableByWindowBackground = true
        panel.handleKey = { [weak self] event in self?.handleKey(event) ?? false }
        let content = NSHostingView(rootView: PickerView(
            model: model,
            inputState: inputState,
            open: { [weak self] id in self?.open(id) },
            cancel: { [weak self] in self?.cancel() }
        ))
        let glass = NSGlassEffectView()
        glass.style = .regular
        glass.cornerRadius = 26
        if #available(macOS 27.0, *) { glass.effectIsInteractive = true }
        glass.contentView = content
        // Match the window's alpha shape to the glass instead of shadowing its rectangular backing.
        let surface = NSView()
        surface.wantsLayer = true
        surface.layer?.cornerRadius = glass.cornerRadius
        surface.layer?.masksToBounds = true
        glass.frame = surface.bounds
        glass.autoresizingMask = [.width, .height]
        surface.addSubview(glass)
        panel.contentView = surface
        self.panel = panel
    }

    private func open(_ id: String? = nil) {
        guard !model.isOpening else { return }
        inputState.reset(at: NSEvent.mouseLocation)
        Task {
            await model.open(id)
            present()
        }
    }

    private func copyLink() {
        inputState.reset(at: NSEvent.mouseLocation)
        model.copyCurrent()
        present()
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        if modifiers == .command {
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "c" { copyLink(); return true }
            if key == "," { cancel(); openSettings(); return true }
            if let key, let number = Int(key), (1...9).contains(number) {
                let visible = model.visibleBrowsers
                if visible.indices.contains(number - 1) { open(visible[number - 1].id) }
                return true
            }
        }
        guard modifiers.isEmpty else { return false }
        if [123, 124, 125, 126].contains(event.keyCode) {
            inputState.reset(at: NSEvent.mouseLocation)
        }
        switch event.keyCode {
        case 53: cancel()
        case 36, 76: open()
        case 123: model.moveSelection(by: -1)
        case 124: model.moveSelection(by: 1)
        case 125: model.moveSelection(by: PickerView.columnCount)
        case 126: model.moveSelection(by: -PickerView.columnCount)
        default: return false
        }
        return true
    }
}
