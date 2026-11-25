import SwiftUI

/// Island shape: concave "ears" at the top blend into the menu bar, rounded bottom corners.
struct NotchShape: Shape {
    var radius: CGFloat
    var ear: CGFloat
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(radius, ear) }
        set { radius = newValue.first; ear = newValue.second }
    }

    func path(in r: CGRect) -> Path {
        let e = ear, rad = min(radius, (r.height - e) , (r.width - 2 * e) / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + e, y: r.minY + e), control: CGPoint(x: r.minX + e, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + e, y: r.maxY - rad))
        p.addQuadCurve(to: CGPoint(x: r.minX + e + rad, y: r.maxY), control: CGPoint(x: r.minX + e, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - e - rad, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - e, y: r.maxY - rad), control: CGPoint(x: r.maxX - e, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - e, y: r.minY + e))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - e, y: r.minY))
        p.closeSubpath()
        return p
    }
}

/// Blur + scale + fade, the way Dynamic Island content morphs in and out.
private struct BlurFade: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 10 : 0)
            .scaleEffect(active ? 0.85 : 1, anchor: .top)
            .opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    /// Content arrives just after the shape grows, and leaves immediately.
    static var island: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: BlurFade(active: true), identity: BlurFade(active: false))
                .animation(.spring(response: 0.4, dampingFraction: 0.85).delay(0.08)),
            removal: .modifier(active: BlurFade(active: true), identity: BlurFade(active: false))
                .animation(.easeOut(duration: 0.15))
        )
    }
}

struct NotchRootView: View {
    let viewModel: NotchViewModel
    let media: MediaModule
    let shelf: ShelfModule
    let timer: TimerModule
    let calendar: CalendarModule

    private var expanded: Bool { viewModel.state == .expanded }
    private var showShelf: Bool { !shelf.items.isEmpty || shelf.isTargeted }

    /// Opening overshoots a little; closing is quicker and settles without bounce.
    static let openSpring = Animation.spring(response: 0.45, dampingFraction: 0.68)
    static let closeSpring = Animation.spring(response: 0.32, dampingFraction: 0.9)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.75)

    private static let earClosed: CGFloat = 6
    private static let earExpanded: CGFloat = 14

    var body: some View {
        let size: CGSize = switch viewModel.state {
        case .expanded: viewModel.expandedSize
        case .peek: viewModel.peekSize
        case .closed: viewModel.closedSize
        }
        let ear = expanded ? Self.earExpanded : Self.earClosed
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(radius: expanded ? 36 : min(size.height / 2.4, 14), ear: ear).fill(.black)
                Group {
                    if expanded {
                        expandedContent.transition(.island)
                    } else if let alert = viewModel.alert {
                        alertContent(alert).transition(.island)
                    } else if viewModel.hasLiveActivity {
                        compactContent.transition(.island)
                    }
                }
                .padding(.horizontal, ear)
            }
            .frame(width: size.width + ear * 2, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture {
                if viewModel.state == .peek { viewModel.state = .expanded }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL], isTargeted: Binding(get: { shelf.isTargeted }, set: { shelf.isTargeted = $0 })) {
            shelf.handleDrop($0)
        }
        .onAppear(perform: sync)
        .onChange(of: media.nowPlaying) { sync() }
        .onChange(of: timer.isAvailable) { sync() }
        .onChange(of: calendar.next) { sync() }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in sync() }
        .onChange(of: showShelf) { sync() }
        .animation(expanded ? Self.openSpring : Self.closeSpring, value: viewModel.state)
        .animation(Self.spring, value: viewModel.alert)
        .animation(Self.spring, value: viewModel.hasLiveActivity)
        .animation(Self.spring, value: viewModel.expandedSize)
    }

    private func sync() {
        viewModel.wideLiveActivity = timer.isAvailable || calendar.isAvailable
        viewModel.hasLiveActivity = viewModel.wideLiveActivity || media.nowPlaying?.isPlaying == true
        // Expanded island hugs its content.
        let top = viewModel.notchSize.height
        let compactCard = timer.isAvailable || calendar.isAvailable || media.nowPlaying == nil
        let contentHeight: CGFloat = compactCard ? 58 : 138
        let width: CGFloat = showShelf ? 640 : 440
        viewModel.expandedSize = CGSize(width: width, height: top + contentHeight + 22)
    }

    private var expandedContent: some View {
        HStack(spacing: 18) {
            Group {
                if timer.isAvailable { timer.expandedView }
                else if calendar.isAvailable { calendar.expandedView }
                else { media.expandedView }
            }
            .frame(maxWidth: .infinity)
            if showShelf {
                shelf.expandedView.frame(width: 180).transition(.island)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, viewModel.notchSize.height + 8)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func alertContent(_ alert: IslandAlert) -> some View {
        wings {
            Image(systemName: alert.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(alert.iconColor)
                .contentTransition(.symbolEffect(.replace))
        } trailing: {
            if let progress = alert.progress {
                LevelBar(value: progress).padding(.trailing, 12).padding(.leading, 4)
            } else {
                Text(alert.text)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(alert.textColor)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private var compactContent: some View {
        Group {
            if timer.isAvailable {
                wings {
                    Image(systemName: "timer").font(.system(size: 14, weight: .semibold)).foregroundStyle(.orange)
                } trailing: {
                    TimerCountdownText(timer: timer, font: .system(size: 13, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            } else if calendar.isAvailable, let meeting = calendar.next {
                wings {
                    Image(systemName: "calendar").font(.system(size: 14, weight: .semibold)).foregroundStyle(meeting.color)
                } trailing: {
                    MeetingCountdownText(meeting: meeting, font: .system(size: 13, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            } else {
                wings {
                    media.compactView
                } trailing: {
                    EqualizerView(isPlaying: media.nowPlaying?.isPlaying == true, color: media.tint)
                }
            }
        }
    }

    /// Lays out content on both sides of the physical notch.
    private func wings<L: View, T: View>(@ViewBuilder leading: () -> L, @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 0) {
            leading().frame(width: viewModel.wingWidth)
            Spacer(minLength: viewModel.notchSize.width)
            trailing().frame(width: viewModel.wingWidth)
        }
        .frame(height: viewModel.notchSize.height)
    }
}

/// Thin rounded level bar used by the HUD and the media scrubber.
struct LevelBar: View {
    var value: Double
    var color: Color = .white
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(color).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 5)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: value)
    }
}
