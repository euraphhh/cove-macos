import AudioToolbox
import CoreAudio
import Foundation
import SwiftUI

/// Listens to the default output device volume/mute and shows it in the island.
final class VolumeMonitor {
    private let viewModel: NotchViewModel
    private var device = AudioObjectID(kAudioObjectUnknown)
    private let queue = DispatchQueue.main
    private lazy var changed: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.showVolume() }
    private lazy var deviceChanged: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.attach() }

    init(viewModel: NotchViewModel) {
        self.viewModel = viewModel
    }

    func start() {
        var addr = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, queue, deviceChanged)
        attach()
    }

    private func attach() {
        detach()
        var addr = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &device) == noErr
        else { return }
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
            var a = Self.address(selector, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectAddPropertyListenerBlock(device, &a, queue, changed)
        }
    }

    private func detach() {
        guard device != kAudioObjectUnknown else { return }
        for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
            var a = Self.address(selector, scope: kAudioDevicePropertyScopeOutput)
            AudioObjectRemovePropertyListenerBlock(device, &a, queue, changed)
        }
    }

    /// Changes volume by `delta` (unmuting first). Returns false if the device has no settable volume.
    func step(_ delta: Float) -> Bool {
        guard var volume = readVolume() else { return false }
        if isMuted { _ = setMute(false) }
        volume = min(max(volume + delta, 0), 1)
        let size = UInt32(MemoryLayout<Float32>.size)
        var a = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        let ok = AudioObjectSetPropertyData(device, &a, 0, nil, size, &volume) == noErr
        if ok { showVolume() } // also covers hitting 0%/100% where no change fires
        return ok
    }

    func toggleMute() -> Bool {
        let ok = setMute(!isMuted)
        if ok { showVolume() }
        return ok
    }

    private var isMuted: Bool {
        var muted = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var m = Self.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        return AudioObjectGetPropertyData(device, &m, 0, nil, &size, &muted) == noErr && muted != 0
    }

    private func setMute(_ mute: Bool) -> Bool {
        var value = UInt32(mute ? 1 : 0)
        var m = Self.address(kAudioDevicePropertyMute, scope: kAudioDevicePropertyScopeOutput)
        return AudioObjectSetPropertyData(device, &m, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }

    private func readVolume() -> Float32? {
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var a = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, scope: kAudioDevicePropertyScopeOutput)
        return AudioObjectGetPropertyData(device, &a, 0, nil, &size, &volume) == noErr ? volume : nil
    }

    private func showVolume() {
        guard let volume = readVolume() else { return }
        let level = isMuted ? 0 : Double(volume)
        let icon = switch level {
        case 0: "speaker.slash.fill"
        case ..<0.34: "speaker.wave.1.fill"
        case ..<0.67: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
        viewModel.show(IslandAlert(icon: icon, iconColor: .white, text: "", progress: level), for: 1.5)
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
