import AppKit
import Foundation
import IOKit.ps
import SwiftUI

/// Watches power source changes and shows a charging alert when the charger is (un)plugged.
final class PowerMonitor {
    private let viewModel: NotchViewModel
    private var source: CFRunLoopSource?
    private var wasCharging: Bool?
    private var lastPercent: Int?
    private static let lowThresholds = [20, 10]

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        let initial = Self.read()
        wasCharging = initial?.onAC
        lastPercent = initial?.percent
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue().changed()
        }, context)?.takeRetainedValue() else { return }
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.showLowPowerMode(ProcessInfo.processInfo.isLowPowerModeEnabled)
        }
    }

    private func changed() {
        guard let info = Self.read() else { return }
        defer { wasCharging = info.onAC; lastPercent = info.percent }
        guard Prefs.on(Prefs.battery) else { return }

        if info.onAC != wasCharging {
            info.onAC ? showCharging(info.percent) : showUnplugged(info.percent)
        } else if !info.onAC, let last = lastPercent,
                  Self.lowThresholds.contains(where: { last > $0 && info.percent <= $0 }) {
            showLowBattery(info.percent)
        }
    }

    func showCharging(_ percent: Int) {
        viewModel.show(IslandAlert(icon: "bolt.fill", iconColor: .green, text: "\(percent)%", textColor: .green))
    }

    func showUnplugged(_ percent: Int) {
        let low = percent <= 20
        viewModel.show(IslandAlert(icon: Self.batteryIcon(percent), iconColor: low ? .red : .white,
                                   text: "\(percent)%", textColor: low ? .red : .white))
    }

    /// Yellow battery like iOS Low Power Mode.
    func showLowPowerMode(_ on: Bool) {
        guard Prefs.on(Prefs.lowPower) else { return }
        let percent = Self.read()?.percent ?? 50
        viewModel.show(IslandAlert(icon: Self.batteryIcon(percent), iconColor: on ? .yellow : .white,
                                   text: on ? "On" : "Off", textColor: on ? .yellow : .white))
    }

    /// Like iOS: red battery and a longer, more noticeable alert.
    func showLowBattery(_ percent: Int) {
        viewModel.show(IslandAlert(icon: Self.batteryIcon(percent), iconColor: .red,
                                   text: "\(percent)%", textColor: .red), for: 5)
        NSSound(named: "Funk")?.play()
    }

    private static func batteryIcon(_ percent: Int) -> String {
        switch percent {
        case ..<5: "battery.0"
        case ..<38: "battery.25"
        case ..<63: "battery.50"
        case ..<88: "battery.75"
        default: "battery.100"
        }
    }

    static func read() -> (onAC: Bool, percent: Int)? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return nil }
        let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
        let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] ?? []
        var percent = 0
        for ps in list {
            if let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any],
               let cap = desc[kIOPSCurrentCapacityKey] as? Int { percent = cap }
        }
        return (type == kIOPSACPowerValue, percent)
    }
}
