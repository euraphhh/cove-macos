import AppKit

struct NotchGeometry {
    /// Panel size: big enough for the largest expanded layout plus the top "ears".
    static let expandedSize = CGSize(width: 680, height: 240)

    /// Debug: `defaults write com.euraphhh.cove simulateNoNotch -bool true` to preview the pill layout.
    static var simulateNoNotch: Bool { UserDefaults.standard.bool(forKey: "simulateNoNotch") }

    static func hasNotch(_ screen: NSScreen) -> Bool {
        !simulateNoNotch && screen.safeAreaInsets.top > 0
    }

    /// Screen with a notch if any, otherwise the main screen (floating island fallback).
    static var targetScreen: NSScreen? {
        NSScreen.screens.first(where: hasNotch) ?? NSScreen.main
    }

    /// Physical notch size, or a compact pill that fits inside the menu bar on screens without one.
    static func notchSize(on screen: NSScreen) -> CGSize {
        guard hasNotch(screen),
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            let menuBar = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
            return CGSize(width: 110, height: menuBar - 4)
        }
        let width = screen.frame.width - left.width - right.width
        return CGSize(width: width, height: screen.safeAreaInsets.top)
    }

    static func panelFrame(on screen: NSScreen) -> NSRect {
        let s = expandedSize
        // When simulating on a notched Mac, move aside so the physical notch doesn't hide the pill.
        let shift: CGFloat = simulateNoNotch && screen.safeAreaInsets.top > 0 ? 350 : 0
        return NSRect(x: screen.frame.midX - s.width / 2 + shift,
                      y: screen.frame.maxY - s.height,
                      width: s.width, height: s.height)
    }
}
