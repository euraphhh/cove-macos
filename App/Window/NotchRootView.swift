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

private struct BubbleSplit: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 0.3 : 1)
            .offset(x: active ? -28 : 0)
            .blur(radius: active ? 4 : 0)
            .opacity(active ? 0 : 1)
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
    /// Bubble splits off the island: grows from its left edge while sliding out.
    static var bubble: AnyTransition {
        .modifier(active: BubbleSplit(active: true), identity: BubbleSplit(active: false))
    }

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

    private var activities: [Activity] {
        var list: [Activity] = []
        if timer.isAvailable { list.append(.timer) }
        if calendar.isAvailable, calendar.next != nil { list.append(.meeting) }
        if media.nowPlaying?.isPlaying == true { list.append(.media) }
        return list
    }
    private var primary: Activity? { activities.first }
    /// What the expanded island shows: the tapped bubble, else the primary activity.
    private var expandedActivity: Activity? { viewModel.focused ?? primary }
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
            .scaleEffect(viewModel.isPressed ? 0.95 : 1, anchor: .top)
            .offset(x: viewModel.nudgeOffset)
            .gesture(pressGesture, including: expanded ? .subviews : .all)
            .overlay(alignment: .topTrailing) {
                if let secondary = viewModel.secondary, !expanded {
                    bubble(for: secondary)
                        .offset(x: viewModel.bubbleSize + NotchViewModel.bubbleGap)
                        .transition(.bubble)
                }
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
        .onChange(of: viewModel.focused) { sync() }
        .onChange(of: viewModel.state) { _, state in
            if state == .closed { viewModel.focused = nil }
        }
        .animation(expanded ? Self.openSpring : Self.closeSpring, value: viewModel.state)
        .animation(Self.spring, value: viewModel.alert)
        .animation(Self.spring, value: viewModel.hasLiveActivity)
        .animation(Self.spring, value: viewModel.secondary)
        .animation(Self.spring, value: viewModel.expandedSize)
        .animation(.spring(response: 0.22, dampingFraction: 0.6), value: viewModel.isPressed)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: viewModel.nudgeOffset)
    }

    /// Squish while pressed, expand on release (like pressing the iPhone island).
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in if !viewModel.isPressed { viewModel.isPressed = true } }
            .onEnded { _ in
                viewModel.isPressed = false
                if viewModel.state != .expanded { viewModel.state = .expanded }
            }
    }

    private func sync() {
        let list = activities
        viewModel.wideLiveActivity = list.first == .timer || list.first == .meeting
        viewModel.hasLiveActivity = !list.isEmpty
        viewModel.secondary = list.count > 1 ? list[1] : nil
        if let f = viewModel.focused, !list.contains(f) { viewModel.focused = nil }
        // Expanded island hugs its content.
        let top = viewModel.notchSize.height
        let compactCard = expandedActivity == .timer || expandedActivity == .meeting || media.nowPlaying == nil
        let contentHeight: CGFloat = compactCard ? 58 : 138
        let width: CGFloat = showShelf ? 640 : 440
        viewModel.expandedSize = CGSize(width: width, height: top + contentHeight + 22)
    }

    private var expandedContent: some View {
        HStack(spacing: 18) {
            Group {
                switch expandedActivity {
                case .timer: timer.expandedView
                case .meeting: calendar.expandedView
                case .media, nil: media.expandedView
                }
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

    /// Minimal presentation of the second activity, in a detached circle (like iOS).
    private func bubble(for activity: Activity) -> some View {
        let size = viewModel.bubbleSize
        return ZStack {
            Circle().fill(.black)
            switch activity {
            case .timer:
                TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                    let left = timer.duration > 0 ? timer.remaining(at: ctx.date) / timer.duration : 0
                    ZStack {
                        Circle().stroke(.orange.opacity(0.25), lineWidth: 2.5)
                        Circle().trim(from: 0, to: left).stroke(.orange, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "timer").font(.system(size: 9, weight: .bold)).foregroundStyle(.orange)
                    }
                    .padding(7)
                }
            case .meeting:
                Image(systemName: "calendar").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(calendar.next?.color ?? .blue)
            case .media:
                Artwork(image: media.artwork, size: size - 12, radius: (size - 12) / 2)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture {
            viewModel.focused = activity
            viewModel.state = .expanded
        }
    }

    private var compactContent: some View {
        Group {
            if primary == .timer {
                wings {
                    Image(systemName: "timer").font(.system(size: 14, weight: .semibold)).foregroundStyle(.orange)
                } trailing: {
                    TimerCountdownText(timer: timer, font: .system(size: 13, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            } else if primary == .meeting, let meeting = calendar.next {
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
