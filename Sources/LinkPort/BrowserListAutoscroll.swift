import AppKit
import LinkPortCore
import SwiftUI

@MainActor
final class BrowserListAutoscrollState {
    weak var scrollView: NSScrollView?
    private var timer: Timer?

    func update(_ session: DragSession) {
        switch session.phase {
        case .active:
            start()
        default:
            stop()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func start() {
        guard timer == nil else { return }
        // Leave destination handling to List; scrolling only observes the source.
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated { self.advance() }
        }
        // Native dragging runs an event-tracking loop, so default-mode timers pause.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private var pointerDirection: Int? {
        guard let scrollView, let window = scrollView.window else { return nil }
        let clip = scrollView.contentView
        let point = clip.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let local = CGPoint(x: point.x - clip.bounds.minX,
                            y: clip.isFlipped ? point.y - clip.bounds.minY : clip.bounds.maxY - point.y)
        return DragAutoscroll.direction(at: local, in: clip.bounds.size)
    }

    private func advance() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else { stop(); return }
        // Source phase updates need not fire on every pointer movement.
        guard let direction = pointerDirection, direction != 0 else { return }
        guard let scrollView, let document = scrollView.documentView else { return }
        let clip = scrollView.contentView
        let delta = CGFloat(direction) * 10 * (document.isFlipped ? 1 : -1)
        let bounds = clip.constrainBoundsRect(clip.bounds.offsetBy(dx: 0, dy: delta))
        guard bounds.origin != clip.bounds.origin else { return }
        clip.scroll(to: bounds.origin)
        scrollView.reflectScrolledClipView(clip)
    }
}

struct BrowserListScrollProbe: NSViewRepresentable {
    let state: BrowserListAutoscrollState

    func makeNSView(context: Context) -> NSView {
        let view = ScrollProbeView()
        view.foundScrollView = { [weak state] in state?.scrollView = $0 }
        view.setAccessibilityElement(false)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? ScrollProbeView)?.resolveScrollView()
    }
}

@MainActor
private final class ScrollProbeView: NSView {
    var foundScrollView: ((NSScrollView) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resolveScrollView()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        resolveScrollView()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func resolveScrollView() {
        guard let enclosingScrollView else { return }
        // List still owns its data source, delegate, drag gesture and onMove.
        // Ask the native table to make room for the drop using its gap feedback.
        (enclosingScrollView.documentView as? NSTableView)?.draggingDestinationFeedbackStyle = .gap
        foundScrollView?(enclosingScrollView)
    }
}
