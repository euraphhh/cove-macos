import SwiftUI
import Observation

enum NotchState { case closed, peek, expanded }

@Observable
final class NotchViewModel {
    var state: NotchState = .closed
    var notchSize: CGSize = CGSize(width: 200, height: 32)
}
