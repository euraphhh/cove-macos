import SwiftUI

/// Island shape: concave "ears" at the top blend into the menu bar, rounded bottom corners.
struct NotchShape: Shape {
    var radius: CGFloat
    var ear: CGFloat
    /// Rounds the top corners too (floating pill on screens without a notch).
    var topRadius: CGFloat = 0
    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(radius, AnimatablePair(ear, topRadius)) }
        set { radius = newValue.first; ear = newValue.second.first; topRadius = newValue.second.second }
    }

    func path(in r: CGRect) -> Path {
        let e = ear, rad = min(radius, (r.height - e) , (r.width - 2 * e) / 2)
        if topRadius > 0 {
            return Path(roundedRect: r, cornerRadii: RectangleCornerRadii(
                topLeading: min(topRadius, r.height / 2), bottomLeading: rad,
                bottomTrailing: rad, topTrailing: min(topRadius, r.height / 2)), style: .continuous)
        }
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
    /// macOS "Reduce motion": swap springs, blur and scale for short fades.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let viewModel: NotchViewModel
    let media: MediaModule
    let shelf: ShelfModule
    let timer: TimerModule
    let calendar: CalendarModule
    let privacy: PrivacyMonitor
    let registry: ActivityRegistry

    @AppStorage(Prefs.music) private var musicOn = true
    @AppStorage(Prefs.shelf) private var shelfOn = true
    @AppStorage(Prefs.privacy) private var privacyOn = true
    @AppStorage(Prefs.bubble) private var bubbleOn = true

    private var expanded: Bool { viewModel.state == .expanded }

    /// Live activities, highest priority first (the first one owns the island).
    private var activities: [ActivityEntry] { registry.live }
    private var liveIDs: [Activity] { activities.map(\.activity) }
    private var primary: ActivityEntry? { activities.first }
    /// Green for camera (which implies the mic too), orange for microphone only, like iOS.
    private var privacyColor: Color? {
        guard privacyOn else { return nil }
        return privacy.cameraInUse ? .green : privacy.micInUse ? .orange : nil
    }
    /// What the expanded island shows: the tapped bubble, else the primary activity.
    private var expandedEntry: ActivityEntry? { registry.entry(for: viewModel.focused) ?? primary }
    private var showShelf: Bool { shelfOn && (!shelf.items.isEmpty || shelf.isTargeted) }

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
        let notch = viewModel.hasNotch
        let ear = notch ? (expanded ? Self.earExpanded : Self.earClosed) : 0
        let radius = expanded ? (notch ? 36 : 28) : (notch ? min(size.height / 2.4, 14) : size.height / 2)
        // Without a notch, an idle island would just be a black pill in the menu bar: hide it.
        let hidden = !notch && viewModel.state == .closed && !viewModel.hasLiveActivity && viewModel.alert == nil
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(radius: radius, ear: ear, topRadius: notch ? 0 : radius).fill(.black)
                Group {
                    if expanded {
                        expandedContent.transition(islandTransition)
                    } else if let alert = viewModel.alert {
                        alertContent(alert).transition(islandTransition)
                    } else if viewModel.hasLiveActivity {
                        compactContent.transition(islandTransition)
                    }
                }
                .padding(.horizontal, ear)
            }
            .frame(width: size.width + ear * 2, height: size.height)
            .contentShape(Rectangle())
            .scaleEffect(viewModel.isPressed ? 0.95 : 1, anchor: .top)
            .offset(x: viewModel.nudgeOffset)
            .gesture(pressGesture, including: expanded ? .subviews : .all)
            .opacity(hidden ? 0 : 1)
            .padding(.top, notch ? 0 : 2)
            .overlay(alignment: .topTrailing) {
                if let secondary = viewModel.secondary, !expanded {
                    bubble(for: secondary)
                        .offset(x: viewModel.bubbleSize + NotchViewModel.bubbleGap)
                        .transition(reduceMotion ? .opacity : .bubble)
                }
            }
            .overlay(alignment: .trailing) {
                if let color = privacyColor, !expanded {
                    // Sits just right of the island (or of the bubble), vertically centered like iOS.
                    let bubbleSpace = viewModel.secondary != nil ? viewModel.bubbleSize + NotchViewModel.bubbleGap : 0
                    // Black backing keeps the dot visible over any wallpaper or menu bar icon.
                    Circle().fill(.black).frame(width: 14, height: 14)
                        .overlay(Circle().fill(color).frame(width: 6, height: 6))
                        .offset(x: bubbleSpace + 11)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(x: viewModel.centerOffset)
        .overlay(alignment: .top) {
            if viewModel.showAlignmentGuide {
                // 1pt outside the notch rect: if aligned, the red line is equally thin on both sides.
                Rectangle().stroke(.red, lineWidth: 1)
                    .frame(width: viewModel.notchSize.width + 2, height: viewModel.notchSize.height + 1)
                    .offset(x: viewModel.centerOffset, y: -0.5)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: ShelfModule.acceptedTypes, isTargeted: Binding(get: { shelf.isTargeted }, set: { shelf.isTargeted = $0 })) {
            shelfOn ? shelf.handleDrop($0) : false
        }
        .onAppear(perform: sync)
        .onChange(of: media.nowPlaying) { sync() }
        .onChange(of: liveIDs) { sync() }
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in sync() }
        .onChange(of: showShelf) { sync() }
        .onChange(of: viewModel.focused) { sync() }
        .onChange(of: musicOn) { sync() }
        .onChange(of: bubbleOn) { sync() }
        .onChange(of: viewModel.state) { _, state in
            if state == .closed { viewModel.focused = nil }
        }
        .animation(motion(expanded ? Self.openSpring : Self.closeSpring), value: viewModel.state)
        .animation(motion(Self.spring), value: viewModel.alert)
        .animation(motion(Self.spring), value: viewModel.hasLiveActivity)
        .animation(motion(Self.spring), value: viewModel.secondary)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: privacyColor)
        .animation(motion(Self.spring), value: viewModel.expandedSize)
        .animation(motion(.spring(response: 0.22, dampingFraction: 0.6)), value: viewModel.isPressed)
        .animation(motion(.spring(response: 0.3, dampingFraction: 0.5)), value: viewModel.nudgeOffset)
    }

    private var islandTransition: AnyTransition { reduceMotion ? .opacity : .island }

    private func motion(_ animation: Animation) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.18) : animation
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
        let list = liveIDs
        viewModel.wideLiveActivity = activities.first?.wide ?? false
        viewModel.hasLiveActivity = !list.isEmpty
        viewModel.secondary = bubbleOn && list.count > 1 ? list[1] : nil
        if let f = viewModel.focused, !list.contains(f) { viewModel.focused = nil }
        // Expanded island hugs its content.
        let top = viewModel.notchSize.height
        let home = expandedEntry == nil && (media.nowPlaying == nil || !musicOn)
        // With no live activity the expanded island shows the (paused) player, which is the tallest card.
        let contentHeight: CGFloat = home ? 108 : (expandedEntry?.expandedHeight ?? 138)
        let width: CGFloat = (showShelf ? 200 : 0) + (home ? 500 : 440)
        viewModel.expandedSize = CGSize(width: width, height: top + contentHeight + 22)
    }

    private var expandedContent: some View {
        HStack(spacing: 18) {
            Group {
                if let entry = expandedEntry {
                    entry.expanded()
                } else if media.nowPlaying != nil && musicOn {
                    media.expandedView
                } else {
                    HomeView(calendar: calendar, timer: timer)
                }
            }
            .frame(maxWidth: .infinity)
            if showShelf {
                shelf.expandedView.frame(width: 180).transition(islandTransition)
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, viewModel.notchSize.height + 8)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func alertContent(_ alert: IslandAlert) -> some View {
        wings {
            if let image = alert.image {
                Image(nsImage: image).resizable().scaledToFill()
                    .frame(width: viewModel.notchSize.height - 8, height: viewModel.notchSize.height - 10)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.3), lineWidth: 1))
            } else {
                Image(systemName: alert.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(alert.iconColor)
                    .contentTransition(.symbolEffect(.replace))
            }
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
            if let entry = registry.entry(for: activity) {
                entry.bubble(size)
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
            if let entry = primary {
                wings { entry.leading() } trailing: { entry.trailing() }
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
