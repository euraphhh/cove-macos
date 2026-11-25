import AppKit

/// Polls global mouse position (no Accessibility permission needed) and drives state.
final class HoverTracker {
    private weak var panel: NotchPanel?
    private let viewModel: NotchViewModel
    private var monitors: [Any] = []

    init(panel: NotchPanel, viewModel: NotchViewModel) {
        self.panel = panel
        self.viewModel = viewModel
        let handler: (NSEvent) -> Void = { [weak self] _ in self?.update() }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: handler) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { e in handler(e); return e }) { monitors.append(l) }
    }

    private func update() {
        guard let panel else { return }
        let p = NSEvent.mouseLocation
        let frame = panel.frame
        let notch = viewModel.notchSize
        // Active area: notch rect when closed, the visible expanded shape when open.
        let active: NSRect
        if viewModel.state == .expanded {
            active = frame
        } else {
            active = NSRect(x: frame.midX - notch.width / 2 - 10, y: frame.maxY - notch.height - 4,
                            width: notch.width + 20, height: notch.height + 4)
        }
        let inside = active.contains(p)
        panel.ignoresMouseEvents = !inside
        let target: NotchState = inside ? .expanded : .closed
        if viewModel.state != target { viewModel.state = target }
    }
}
