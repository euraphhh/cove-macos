import SwiftUI

struct NotchShape: Shape {
    var radius: CGFloat
    var animatableData: CGFloat { get { radius } set { radius = newValue } }
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: r.maxX - radius, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - radius), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct NotchRootView: View {
    let viewModel: NotchViewModel
    let media: MediaModule
    let shelf: ShelfModule

    private var expanded: Bool { viewModel.state == .expanded }

    var body: some View {
        let notch = viewModel.notchSize
        let size = expanded ? NotchGeometry.expandedSize : notch
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(radius: expanded ? 28 : 10).fill(.black)
                if expanded {
                    HStack(spacing: 16) {
                        media.expandedView.frame(maxWidth: .infinity)
                        shelf.expandedView.frame(width: 200)
                    }
                        .padding(.bottom, 16)
                        .padding(.horizontal, 24)
                        .padding(.top, notch.height + 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { shelf.isTargeted }, set: { shelf.isTargeted = $0 })) {
            shelf.handleDrop($0)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: expanded)
    }
}
