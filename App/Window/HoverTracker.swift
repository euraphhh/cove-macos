import AppKit

/// Polls global mouse position (no Accessibility permission needed) and drives state.
final class HoverTracker {
    private weak var panel: NotchPanel?
    private let viewModel: NotchViewModel
    private var monitors: [Any] = []
    private var dragTimer: Timer?

    init(panel: NotchPanel, viewModel: NotchViewModel) {
        self.panel = panel
        self.viewModel = viewModel
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.update() }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { e in handler(e); return e }) { monitors.append(l) }
        // Drag sessions from other apps don't reliably deliver mouse events to monitors,
        // so poll the cursor while a mouse button is held.
        dragTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            if NSEvent.pressedMouseButtons != 0 { self?.update() }
        }
    }

    private func update() {
        guard let panel, !viewModel.pinned else { return }
        let p = NSEvent.mouseLocation
        let frame = panel.frame
        let notch = viewModel.closedSize
        // Active area: notch rect when closed, the visible expanded shape when open.
        let active: NSRect
        if viewModel.state == .expanded {
            let e = viewModel.expandedSize
            active = NSRect(x: frame.midX - e.width / 2, y: frame.maxY - e.height, width: e.width, height: e.height)
        } else {
            // Larger catch area while dragging so files are easy to drop.
            let pad: CGFloat = NSEvent.pressedMouseButtons != 0 ? 60 : 10
            active = NSRect(x: frame.midX - notch.width / 2 - pad, y: frame.maxY - notch.height - pad / 2,
                            width: notch.width + pad * 2, height: notch.height + pad / 2)
        }
        let inside = active.contains(p)
        // Keep open while a button is held after leaving (dragging a file out of the shelf).
        let holding = NSEvent.pressedMouseButtons != 0 && viewModel.state == .expanded
        if holding && !inside { return }
        panel.ignoresMouseEvents = !inside
        let dragging = NSEvent.pressedMouseButtons != 0
        let target: NotchState
        if !inside { target = .closed }
        else if viewModel.state == .expanded || dragging { target = .expanded } // drag goes straight to shelf
        else { target = .peek } // click expands (handled in NotchRootView)
        if viewModel.state != target { viewModel.state = target }
    }
}
