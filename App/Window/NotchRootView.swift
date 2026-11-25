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

/// Blur + scale + fade, the way Dynamic Island content morphs in and out.
private struct BlurFade: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 12 : 0)
            .scaleEffect(active ? 0.8 : 1, anchor: .top)
            .opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    static var island: AnyTransition {
        .modifier(active: BlurFade(active: true), identity: BlurFade(active: false))
    }
}

struct NotchRootView: View {
    let viewModel: NotchViewModel
    let media: MediaModule
    let shelf: ShelfModule

    private var expanded: Bool { viewModel.state == .expanded }
    private var showShelf: Bool { !shelf.items.isEmpty || shelf.isTargeted }

    /// Elastic spring tuned to feel like the iPhone island.
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.72)

    var body: some View {
        let size = expanded ? NotchGeometry.expandedSize : viewModel.closedSize
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(radius: expanded ? 32 : viewModel.notchSize.height / 2.6).fill(.black)
                if expanded {
                    expandedContent.transition(.island)
                } else if viewModel.hasLiveActivity {
                    compactContent.transition(.island)
                }
            }
            .frame(width: size.width, height: size.height)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { shelf.isTargeted }, set: { shelf.isTargeted = $0 })) {
            shelf.handleDrop($0)
        }
        .onAppear(perform: syncLiveActivity)
        .onChange(of: media.nowPlaying) { syncLiveActivity() }
        .animation(Self.spring, value: expanded)
        .animation(Self.spring, value: viewModel.hasLiveActivity)
        .animation(Self.spring, value: showShelf)
    }

    private func syncLiveActivity() {
        viewModel.hasLiveActivity = media.nowPlaying?.isPlaying == true
    }

    private var expandedContent: some View {
        HStack(spacing: 16) {
            media.expandedView.frame(maxWidth: .infinity)
            if showShelf {
                shelf.expandedView.frame(width: 200).transition(.island)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, viewModel.notchSize.height + 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Artwork on the left wing, equalizer on the right; the physical notch sits in between.
    private var compactContent: some View {
        let h = viewModel.notchSize.height
        return HStack(spacing: 0) {
            Artwork(url: media.nowPlaying?.artworkURL, size: h - 10)
                .frame(width: viewModel.wingWidth)
            Spacer(minLength: viewModel.notchSize.width)
            EqualizerView(isPlaying: media.nowPlaying?.isPlaying == true, color: .green)
                .frame(width: viewModel.wingWidth)
        }
        .frame(height: h)
    }
}
