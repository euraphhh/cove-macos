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
        let choice = UserDefaults.standard.string(forKey: Prefs.display) ?? ""
        if choice == "main" { return NSScreen.screens.first }  // the display with the menu bar
        if !choice.isEmpty, let screen = NSScreen.screens.first(where: { $0.localizedName == choice }) { return screen }
        return NSScreen.screens.first(where: hasNotch) ?? NSScreen.main
    }

    /// Physical notch size, or a compact pill that fits inside the menu bar on screens without one.
    static func notchSize(on screen: NSScreen) -> CGSize {
        guard hasNotch(screen),
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            let menuBar = max(screen.frame.maxY - screen.visibleFrame.maxY, 24)
            return CGSize(width: 110, height: menuBar - 4)
        }
        return CGSize(width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
    }

    /// Horizontal center of the physical notch. It isn't always the screen's midX: on a 1470pt-wide
    /// screen the notch spans 646–825, so its center is 735.5 and centering on 735 is 1px off.
    static func notchCenterX(on screen: NSScreen) -> CGFloat {
        guard hasNotch(screen), let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else {
            return screen.frame.midX
        }
        return (left.maxX + right.minX) / 2
    }

    static func panelFrame(on screen: NSScreen) -> NSRect {
        let s = expandedSize
        // When simulating on a notched Mac, move aside so the physical notch doesn't hide the pill.
        let shift: CGFloat = simulateNoNotch && screen.safeAreaInsets.top > 0 ? 350 : 0
        return NSRect(x: notchCenterX(on: screen) - s.width / 2 + shift,
                      y: screen.frame.maxY - s.height,
                      width: s.width, height: s.height)
    }
}
