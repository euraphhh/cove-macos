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
        for section in sections {
            guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                guard let info = entry[name] as? [String: Any] else { continue }
                // Left/right buds or the single "main" battery; the case doesn't count.
                let levels = info
                    .filter { $0.key.contains("batteryLevel") && !$0.key.contains("Case") }
                    .compactMap { Int(($0.value as? String ?? "").replacingOccurrences(of: "%", with: "")) }
                return levels.min()
            }
        }
        return nil
    }
}
