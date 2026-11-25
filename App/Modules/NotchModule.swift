import SwiftUI

protocol NotchModule {
    associatedtype Compact: View
    associatedtype Expanded: View
    var id: String { get }
    var isAvailable: Bool { get }
    @ViewBuilder var compactView: Compact { get }
    @ViewBuilder var expandedView: Expanded { get }
}
