import Foundation

/// Reads headphone battery from `system_profiler` (no public API exists).
/// Fragile by nature: returns nil whenever the output doesn't match.
enum BluetoothBattery {
    static func level(forDeviceNamed name: String) -> Int? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do { try task.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = json["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        var devices: [String: [String: Any]] = [:]
        for section in sections {
            for entry in section["device_connected"] as? [[String: Any]] ?? [] {
                for (key, value) in entry { if let info = value as? [String: Any] { devices[key] = info } }
            }
        }
        // Exact name first; otherwise any connected device that reports a battery.
        if let info = devices[name], let level = batteryLevel(in: info) { return level }
        return devices.values.lazy.compactMap(batteryLevel(in:)).first
    }

    /// Left/right buds or the single "main" battery; the case doesn't count.
    private static func batteryLevel(in info: [String: Any]) -> Int? {
        info.filter { $0.key.contains("batteryLevel") && !$0.key.contains("Case") }
            .compactMap { Int(($0.value as? String ?? "").replacingOccurrences(of: "%", with: "")) }
            .min()
    }
}
