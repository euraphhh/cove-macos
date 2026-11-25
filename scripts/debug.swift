// Usage: swift scripts/debug.swift <lowBattery|charging|unplugged|expand|peek|close>
import Foundation
let cmd = CommandLine.arguments.dropFirst().first ?? "lowBattery"
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.euraphhh.cove.debug"), object: cmd, userInfo: nil, deliverImmediately: true)
