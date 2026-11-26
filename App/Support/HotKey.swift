import AppKit
import Carbon.HIToolbox

/// Global shortcut to toggle the island. Carbon hot keys need no Accessibility permission.
final class HotKey {
    enum Preset: String, CaseIterable {
        case controlOption = "ctrlOpt", option = "opt", commandShift = "cmdShift", off
        var label: String {
            switch self {
            case .controlOption: "⌃⌥ Space"
            case .option: "⌥ Space"
            case .commandShift: "⇧⌘ Space"
            case .off: String(localized: "Off")
            }
        }
        var modifiers: UInt32? {
            switch self {
            case .controlOption: UInt32(controlKey | optionKey)
            case .option: UInt32(optionKey)
            case .commandShift: UInt32(cmdKey | shiftKey)
            case .off: nil
            }
        }
    }

    static let shared = HotKey()
    var onPress: (() -> Void)?
    private var ref: EventHotKeyRef?
    private var handlerInstalled = false

    func apply(_ preset: Preset) {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        guard let modifiers = preset.modifiers else { return }
        installHandler()
        let id = EventHotKeyID(signature: OSType(0x436F_7665), id: 1) // 'Cove'
        let status = RegisterEventHotKey(UInt32(kVK_Space), modifiers, id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr { Log.app.error("Hot key registration failed: \(status)") }
    }

    private func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
