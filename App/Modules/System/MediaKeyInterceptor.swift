import AppKit
import ApplicationServices

/// Swallows volume/brightness keys so the island replaces the system HUD.
/// Requires Accessibility. Any key we can't handle is passed through to macOS.
final class MediaKeyInterceptor {
    static let shared = MediaKeyInterceptor()
    static let defaultsKey = "replaceSystemHUD"

    weak var volume: VolumeMonitor?
    weak var viewModel: NotchViewModel?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var permissionTimer: Timer?

    private enum Key: Int { case soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7 }
    private static let step: Float = 1 / 16

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.defaultsKey) }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: Self.defaultsKey)
        enabled ? start() : stop()
    }

    /// Starts if the setting is on; asks for Accessibility when needed.
    func start() {
        guard isEnabled, tap == nil else { return }
        if AXIsProcessTrusted() { install(); return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
            guard AXIsProcessTrusted() else { return }
            t.invalidate()
            self?.install()
        }
    }

    func stop() {
        permissionTimer?.invalidate()
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        tap = nil
        source = nil
    }

    private func install() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << 14) // NSEventTypeSystemDefined
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<MediaKeyInterceptor>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }, userInfo: refcon) else {
            Log.app.error("Could not create event tap")
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let ns = NSEvent(cgEvent: event), ns.subtype.rawValue == 8,
              let key = Key(rawValue: (ns.data1 & 0xFFFF0000) >> 16) else {
            return Unmanaged.passUnretained(event)
        }
        // Leave modified presses (e.g. Option+volume opens Sound settings) to macOS.
        if !ns.modifierFlags.intersection([.option, .shift, .control, .command]).isEmpty {
            return Unmanaged.passUnretained(event)
        }
        let keyDown = ((ns.data1 & 0xFF00) >> 8) == 0xA
        guard keyDown else { return canHandle(key) ? nil : Unmanaged.passUnretained(event) }
        return perform(key) ? nil : Unmanaged.passUnretained(event)
    }

    private func canHandle(_ key: Key) -> Bool {
        switch key {
        case .soundUp, .soundDown, .mute: return volume != nil
        case .brightnessUp, .brightnessDown: return DisplayBrightness.get() != nil
        }
    }

    /// Returns true when handled (event swallowed).
    private func perform(_ key: Key) -> Bool {
        switch key {
        case .soundUp: return volume?.step(Self.step) ?? false
        case .soundDown: return volume?.step(-Self.step) ?? false
        case .mute: return volume?.toggleMute() ?? false
        case .brightnessUp, .brightnessDown:
            guard let value = DisplayBrightness.step(key == .brightnessUp ? Self.step : -Self.step) else { return false }
            viewModel?.show(IslandAlert(icon: value < 0.5 ? "sun.min.fill" : "sun.max.fill",
                                        iconColor: .white, text: "", progress: Double(value)), for: 1.5)
            return true
        }
    }
}
