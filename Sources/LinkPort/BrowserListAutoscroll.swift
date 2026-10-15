import AppKit
import LinkPortCore
import SwiftUI

@MainActor
final class BrowserListAutoscrollState {
    weak var scrollView: NSScrollView?
    var direction = 0 {
        didSet {
            guard direction != oldValue else { return }
            if direction == 0 {
                timer?.invalidate()
                timer = nil
            } else if timer == nil {
                let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] timer in
                    guard let self else { timer.invalidate(); return }
                    MainActor.assumeIsolated { self.advance() }
                }
                // Native dragging runs an event-tracking loop, so default-mode timers pause.
                RunLoop.main.add(timer, forMode: .common)
                self.timer = timer
            }
        }
    }
    private var timer: Timer?

    func update(_ session: DropSession) {
        switch session.phase {
        case .entering, .active:
            direction = pointerDirection ?? DragAutoscroll.direction(at: session.location, in: session.size)
        default:
            direction = 0
        }
    }

    func update(_ session: DragSession) {
        switch session.phase {
        case .active: direction = pointerDirection ?? 0
        default: direction = 0
        }
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
        if let enclosingScrollView { foundScrollView?(enclosingScrollView) }
    }
}
