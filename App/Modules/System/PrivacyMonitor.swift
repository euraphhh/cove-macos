import CoreAudio
import CoreMediaIO
import Foundation
import Observation

/// Detects whether any app is using the camera or microphone (public "running somewhere" flags).
/// Driven by Core Audio / Core Media IO property listeners; a slow timer is only a safety net.
@Observable
final class PrivacyMonitor {
    private(set) var cameraInUse = false
    private(set) var micInUse = false
    @ObservationIgnored private var safetyTimer: Timer?
    @ObservationIgnored private var listenedMic = AudioObjectID(kAudioObjectUnknown)
    @ObservationIgnored private var listenedCameras = Set<CMIOObjectID>()
    /// Debug only: forces the indicator ("camera" / "mic").
    var debugOverride: String? { didSet { refresh() } }

    func start() {
        installSystemListeners()
        refresh()
        safetyTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        let camera = debugOverride == "camera" || Self.anyCameraRunning()
        let mic = debugOverride == "mic" || Self.micRunning()
        if camera != cameraInUse { cameraInUse = camera }
        if mic != micInUse { micInUse = mic }
    }

    // MARK: Listeners

    private func installSystemListeners() {
        // Default input device changed: listen to the new one.
        var inputAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                      mScope: kAudioObjectPropertyScopeGlobal,
                                                      mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &inputAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.bindMic()
            self?.refresh()
        }
        // Cameras plugged in or removed.
        var devicesAddress = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                                       mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                                       mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        CMIOObjectAddPropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), &devicesAddress, DispatchQueue.main) { [weak self] _, _ in
            self?.bindCameras()
            self?.refresh()
        }
        bindMic()
        bindCameras()
    }

    /// Listeners on a previous default input device are left in place: they only trigger a cheap refresh.
    private func bindMic() {
        guard let device = Self.defaultInputDevice(), device != listenedMic else { return }
        listenedMic = device
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        AudioObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main) { [weak self] _, _ in
            self?.refresh()
        }
    }

    private func bindCameras() {
        var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                                                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        for device in Self.cameraDevices() where !listenedCameras.contains(device) {
            listenedCameras.insert(device)
            CMIOObjectAddPropertyListenerBlock(device, &address, DispatchQueue.main) { [weak self] _, _ in
                self?.refresh()
            }
        }
    }

    // MARK: Reading

    private static func defaultInputDevice() -> AudioObjectID? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown else { return nil }
        return device
    }

    private static func micRunning() -> Bool {
        guard let device = defaultInputDevice() else { return false }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var running = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &running) == noErr && running != 0
    }

    private static func cameraDevices() -> [CMIOObjectID] {
        var addr = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                             mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                             mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == 0, size > 0 else { return [] }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &addr, 0, nil, size, &used, &devices) == 0 else { return [] }
        return devices
    }

    private static func anyCameraRunning() -> Bool {
        var addr = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                                             mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                             mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        return cameraDevices().contains { device in
            var running: UInt32 = 0
            var got: UInt32 = 0
            return CMIOObjectGetPropertyData(device, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &got, &running) == 0
                && running != 0
        }
    }
}
