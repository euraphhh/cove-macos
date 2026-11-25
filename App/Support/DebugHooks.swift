import Foundation

/// Trigger island states from the terminal to check visuals without real events:
///   defaults write com.euraphhh.cove debugHooks -bool true
///   (relaunch) then: swift scripts/debug.swift lowBattery
enum DebugHooks {
    static let name = Notification.Name("com.euraphhh.cove.debug")

    static func install(viewModel: NotchViewModel, power: PowerMonitor?) {
        guard UserDefaults.standard.bool(forKey: "debugHooks") else { return }
        DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { note in
            switch note.object as? String {
            case "lowBattery": power?.showLowBattery(9)
            case "charging": power?.showCharging(57)
            case "unplugged": power?.showUnplugged(57)
            case "expand": viewModel.state = .expanded
            case "peek": viewModel.state = .peek
            case "close": viewModel.state = .closed
            default: break
            }
        }
    }
}
