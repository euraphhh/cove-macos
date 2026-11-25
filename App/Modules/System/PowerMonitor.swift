import Foundation
import IOKit.ps
import SwiftUI

/// Watches power source changes and shows a charging alert when the charger is (un)plugged.
final class PowerMonitor {
    private let viewModel: NotchViewModel
    private var source: CFRunLoopSource?
    private var wasCharging: Bool?

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        wasCharging = Self.read()?.onAC
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let src = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue().changed()
        }, context)?.takeRetainedValue() else { return }
        source = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
    }

    private func changed() {
        guard let info = Self.read(), info.onAC != wasCharging else { return }
        wasCharging = info.onAC
        let pct = "\(info.percent)%"
        if info.onAC {
            viewModel.show(IslandAlert(icon: "bolt.fill", iconColor: .green, text: pct, textColor: .green))
        } else {
            let color: Color = info.percent <= 20 ? .red : .white
            viewModel.show(IslandAlert(icon: "battery.100", iconColor: color, text: pct, textColor: color))
        }
    }

    private static func read() -> (onAC: Bool, percent: Int)? {
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
