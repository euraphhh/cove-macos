import Foundation

/// Trigger island states from the terminal to check visuals without real events:
///   defaults write com.euraphhh.cove debugHooks -bool true
///   (relaunch) then: swift scripts/debug.swift lowBattery
enum DebugHooks {
    static let name = Notification.Name("com.euraphhh.cove.debug")

    static func install(viewModel: NotchViewModel, power: PowerMonitor?, calendar: CalendarModule) {
        guard UserDefaults.standard.bool(forKey: "debugHooks") else { return }
        DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { note in
            switch note.object as? String {
            case "lowBattery": power?.showLowBattery(9)
            case "charging": power?.showCharging(57)
            case "unplugged": power?.showUnplugged(57)
            case "meeting":
                calendar.set(Meeting(id: "debug", title: "Design review", start: .now.addingTimeInterval(240),
                                     end: .now.addingTimeInterval(2040), color: .blue,
                                     joinURL: URL(string: "https://meet.google.com/abc-defg-hij")))
            case "meetingNow":
                calendar.set(Meeting(id: "debug-now", title: "Design review", start: .now,
                                     end: .now.addingTimeInterval(1800), color: .blue, joinURL: nil))
            case "noMeeting": calendar.set(nil)
            case "expand": viewModel.pinned = true; viewModel.state = .expanded
            case "peek": viewModel.pinned = true; viewModel.state = .peek
            case "close": viewModel.pinned = false; viewModel.state = .closed
            default: break
            }
        }
    }
}
