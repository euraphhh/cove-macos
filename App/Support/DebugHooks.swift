import AppKit
import Foundation

/// Trigger island states from the terminal to check visuals without real events:
///   defaults write com.euraphhh.cove debugHooks -bool true
///   (relaunch) then: swift scripts/debug.swift lowBattery
enum DebugHooks {
    static let name = Notification.Name("com.euraphhh.cove.debug")

    static func install(viewModel: NotchViewModel, power: PowerMonitor?, calendar: CalendarModule, timer: TimerModule, privacy: PrivacyMonitor, unlock: UnlockMonitor?, downloads: DownloadModule) {
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
            case "timer": timer.start(minutes: 5)
            case "noTimer": timer.cancel()
            case "camera", "mic": privacy.debugOverride = note.object as? String
            case "noPrivacy": privacy.debugOverride = nil
            case "unlock": unlock?.play()
            case "weather":
                UserDefaults.standard.set(true, forKey: Prefs.weather)
                UserDefaults.standard.set("São Paulo", forKey: Prefs.weatherCity)
                WeatherModule.shared.refresh()
            case "noWeather":
                UserDefaults.standard.set(false, forKey: Prefs.weather)
                UserDefaults.standard.set("", forKey: Prefs.weatherCity)
                WeatherModule.shared.refresh()
            case "align": viewModel.showAlignmentGuide.toggle()
            case "musicOff": UserDefaults.standard.set(false, forKey: Prefs.music)
            case "musicOn": UserDefaults.standard.set(true, forKey: Prefs.music)
            case "lowPower": power?.showLowPowerMode(true)
            case "screenshot":
                viewModel.show(IslandAlert(icon: "camera.viewfinder", iconColor: .white, text: "",
                                           image: NSApp.applicationIconImage), for: 3)
            case "offline": viewModel.show(IslandAlert(icon: "wifi.slash", iconColor: .red, text: String(localized: "Offline"), textColor: .red))
            case "download": downloads.active = .init(name: "Cove-Design.zip", fraction: 0.62)
            case "noDownload": downloads.active = nil
            case "expand": viewModel.pinned = true; viewModel.state = .expanded
            case "peek": viewModel.pinned = true; viewModel.state = .peek
            case "close": viewModel.pinned = false; viewModel.state = .closed
            default: break
            }
        }
    }
}
