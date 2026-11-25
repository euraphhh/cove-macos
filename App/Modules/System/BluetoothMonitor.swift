import Foundation
import IOBluetooth
import SwiftUI

/// Shows an island alert when Bluetooth headphones (AirPods etc.) connect.
final class BluetoothMonitor: NSObject {
    private let viewModel: NotchViewModel
    private var connectNote: IOBluetoothUserNotification?
    private var startedAt = Date()
    /// Devices already connected at launch: their replayed connect events are not real connections.
    private var connectedAtLaunch = Set<String>()

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        startedAt = Date()
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        connectedAtLaunch = Set(paired.filter { $0.isConnected() }.compactMap(\.addressString))
        connectNote = IOBluetoothDevice.register(forConnectNotifications: self,
                                                 selector: #selector(connected(_:device:)))
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Registration replays already-connected devices; ignore those at launch.
        if let address = device.addressString, connectedAtLaunch.remove(address) != nil { return }
        guard Date().timeIntervalSince(startedAt) > 3, Prefs.on(Prefs.headphones) else { return }
        let isAudio = device.deviceClassMajor == kBluetoothDeviceClassMajorAudio
        let name = device.name ?? ""
        guard isAudio || name.localizedCaseInsensitiveContains("airpods") else { return }

        let icon = Self.icon(for: name)
        // Show right away, then fill in the battery once system_profiler reports it.
        viewModel.show(IslandAlert(icon: icon, iconColor: .white, text: "", textColor: .green), for: 3.5)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            for attempt in 0..<6 {
                if attempt > 0 { Thread.sleep(forTimeInterval: 0.5) }
                guard let level = BluetoothBattery.level(forDeviceNamed: name) else { continue }
                DispatchQueue.main.async {
                    let color: Color = level <= 20 ? .red : .green
                    self?.viewModel.update(IslandAlert(icon: icon, iconColor: .white, text: "\(level)%", textColor: color))
                }
                return
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
