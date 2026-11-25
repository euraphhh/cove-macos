import Foundation
import IOBluetooth
import SwiftUI

/// Shows an island alert when Bluetooth headphones (AirPods etc.) connect.
final class BluetoothMonitor: NSObject {
    private let viewModel: NotchViewModel
    private var connectNote: IOBluetoothUserNotification?
    private var startedAt = Date()

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        startedAt = Date()
        connectNote = IOBluetoothDevice.register(forConnectNotifications: self,
                                                 selector: #selector(connected(_:device:)))
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Registration replays already-connected devices; ignore those at launch.
        guard Date().timeIntervalSince(startedAt) > 3 else { return }
        let isAudio = device.deviceClassMajor == kBluetoothDeviceClassMajorAudio
        let name = device.name ?? ""
        guard isAudio || name.localizedCaseInsensitiveContains("airpods") else { return }

        let icon = Self.icon(for: name)
        // Battery shows up in system_profiler a moment after the connection.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) { [weak self] in
            let battery = BluetoothBattery.level(forDeviceNamed: name)
            DispatchQueue.main.async {
                let text = battery.map { "\($0)%" } ?? "On"
                let color: Color = (battery ?? 100) <= 20 ? .red : .green
                self?.viewModel.show(IslandAlert(icon: icon, iconColor: .white, text: text, textColor: color))
            }
        }
    }

    private static func icon(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpodsmax" }
        if n.contains("airpods pro") { return "airpodspro" }
        if n.contains("airpods") { return "airpods" }
        if n.contains("beats") { return "beats.headphones" }
        return "headphones"
    }
}
