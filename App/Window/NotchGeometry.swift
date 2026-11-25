import AppKit

struct NotchGeometry {
    static let expandedSize = CGSize(width: 520, height: 180)

    /// Screen with a notch if any, otherwise the main screen (floating island fallback).
    static var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    /// Physical notch size, or a fallback pill size for screens without a notch.
    static func notchSize(on screen: NSScreen) -> CGSize {
        guard screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else {
            return CGSize(width: 200, height: 32)
        }
        let width = screen.frame.width - left.width - right.width
        return CGSize(width: width, height: screen.safeAreaInsets.top)
    }

    static func panelFrame(on screen: NSScreen) -> NSRect {
        let s = expandedSize
        return NSRect(x: screen.frame.midX - s.width / 2,
                      y: screen.frame.maxY - s.height,
                      width: s.width, height: s.height)
    }
}
