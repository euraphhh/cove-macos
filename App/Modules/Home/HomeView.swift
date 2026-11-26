import AppKit
import SwiftUI

/// What the expanded island shows when nothing is playing: clock, today's events, batteries, shortcuts.
struct HomeView: View {
    let calendar: CalendarModule
    let timer: TimerModule
    @State private var mac: (onAC: Bool, percent: Int)? = PowerMonitor.read()
    @State private var headphones: Int?

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 18) {
                clock.frame(width: 130, alignment: .leading)
                events.frame(maxWidth: .infinity, alignment: .leading)
                batteries.frame(width: 70, alignment: .trailing)
            }
            HStack(spacing: 8) {
                shortcut("timer", "5 min") { timer.start(minutes: 5) }
                shortcut("timer", "25 min") { timer.start(minutes: 25) }
                shortcut("circle.lefthalf.filled", "Dark Mode") { Self.toggleDarkMode() }
                shortcut("camera.viewfinder", "Capture") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"))
                }
            }
        }
        .foregroundStyle(.white)
        .onAppear {
            mac = PowerMonitor.read()
            DispatchQueue.global(qos: .userInitiated).async {
                let level = BluetoothBattery.level(forDeviceNamed: "")
                DispatchQueue.main.async { headphones = level }
            }
        }
    }

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            VStack(alignment: .leading, spacing: 0) {
                Text(ctx.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 30, weight: .semibold).monospacedDigit())
                Text(ctx.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    @ViewBuilder private var events: some View {
        if !calendar.isEnabled {
            hint("calendar", "Turn on meetings in the menu to see today's events.")
        } else if calendar.today.isEmpty {
            hint("calendar", "No more events today.")
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(calendar.today, id: \.id) { m in
                    HStack(spacing: 7) {
                        RoundedRectangle(cornerRadius: 1.5).fill(m.color).frame(width: 3, height: 14)
                        Text(m.start.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 12).monospacedDigit()).foregroundStyle(.white.opacity(0.55))
                        Text(m.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    }
                }
            }
        }
    }

    private var batteries: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let mac {
                batteryRow(icon: mac.onAC ? "bolt.fill" : "laptopcomputer", percent: mac.percent)
            }
            if let headphones {
                batteryRow(icon: "airpodspro", percent: headphones)
            }
        }
    }

    private func batteryRow(icon: String, percent: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
            Text("\(percent)%").font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(percent <= 20 ? .red : .white)
        }
    }

    private func hint(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: icon).foregroundStyle(.white.opacity(0.4))
            Text(text).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12))
    }

    private func shortcut(_ icon: String, _ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 8).frame(height: 28)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(.white.opacity(0.12)))
        }
        .buttonStyle(PressScaleStyle())
    }

    /// Needs Automation access to System Events (asked the first time).
    private static func toggleDarkMode() {
        let source = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }
}
