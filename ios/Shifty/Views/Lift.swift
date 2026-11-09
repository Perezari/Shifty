import SwiftUI
import UIKit

// A long press, as ios/preview has it: the screen blurs, what was pressed lifts (a shift or a day as a card of
// its pay, a button as itself), and its menu opens under it, or over it when it is low on the screen. Quicker
// than iOS's context menu, which since iOS 26 blurs nothing, and the iPhone taps at each. What the menu holds
// and how the thing looks lifted are made when it is pressed, not each time it is drawn.

/// An item of a lifted thing's menu: its title and a time under it, its symbol, red when it deletes.
struct LiftItem {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var destructive = false
    let action: () -> Void
}

/// A part of a menu: a line between it and the part before, and a small title over it.
struct LiftSection {
    var header: String? = nil
    let items: [LiftItem]
}

/// What a long press lifted: where it was on the screen, how it looks lifted, and its menu. A card goes across
/// the screen where the thing was; anything else stays at its own size and place.
struct Lift {
    let source: CGRect
    let card: Bool
    let preview: AnyView
    let sections: [LiftSection]
}

/// The thing lifted over a screen (the tabs', a sheet's), for its overlay to draw.
@MainActor @Observable
final class Lifter {
    private(set) var lift: Lift?
    /// The iPhone's tap at each lift: a generator of UIKit's, and not a sensoryFeedback over the tabs, which drew
    /// the whole of them again for each tap.
    private static let tap = UIImpactFeedbackGenerator(style: .medium)

    var isShowing: Bool { lift != nil }

    /// A finger came down on a thing that lifts: the tap gets ready, to come at once if it does.
    static func prepare() {
        tap.prepare()
    }

    /// Lifted with no animation here: LiftStage starts its own once all of it is made and drawn.
    func show(_ lift: Lift) {
        guard self.lift == nil else { return }
        Self.tap.impactOccurred()
        self.lift = lift
    }

    /// Puts the thing down, then does what was chosen.
    func dismiss(then action: (() -> Void)? = nil) {
        withAnimation(.easeOut(duration: 0.1)) { lift = nil }
        action?()
    }
}

extension EnvironmentValues {
    /// The screen's lifter, set by liftHost().
    @Entry var lifter: Lifter? = nil
}

#if DEBUG
extension EnvironmentValues {
    /// The thing the screenshot of a menu lifts once its screen is up (Screenshot.menu).
    @Entry var liftsForScreenshot = false
}
#endif

extension View {
    /// Where long presses lift things: over this view, blurred under the thing lifted and its menu.
    func liftHost() -> some View {
        modifier(LiftHost())
    }

    /// Lifted by a long press, with its menu: `preview` is how it looks lifted, across the screen as a `card` or
    /// else at its own size and place. A tap's action should ask the lifter first: the finger lifted after a
    /// long press taps too.
    func liftable<Preview: View>(card: Bool, @ViewBuilder preview: @escaping () -> Preview,
                                 sections: @escaping () -> [LiftSection]) -> some View {
        modifier(Liftable(card: card, preview: { AnyView(preview()) }, sections: sections))
    }
}

extension View {
    /// A shift or a day lifted as a card: solid over the blur, with the cards' corners and a shadow under it.
    func liftedCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { LiftSurface() }
    }
}

/// What a lifted card or menu lies on: solid, with the cards' corners and a shadow. The shadow of this shape alone: one
/// over the whole card, its words too, is made anew in each frame that it moves.
private struct LiftSurface: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.appBackground)
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }
}

extension LiftSection {
    /// What a plus adds: a shift by hand, a paid vacation or sick day, a day of reserve duty, or a sum once.
    static func adding(shift: @escaping () -> Void, dayOff: @escaping (ShiftType) -> Void,
                       adjustment: @escaping () -> Void) -> LiftSection {
        LiftSection(items: [
            LiftItem(title: "משמרת", systemImage: "timer", action: shift),
            LiftItem(title: "יום חופש", systemImage: "beach.umbrella") { dayOff(.vacation) },
            LiftItem(title: "יום מחלה", systemImage: "cross.case") { dayOff(.sick) },
            LiftItem(title: "יום מילואים", systemImage: "shield") { dayOff(.reserve) },
            LiftItem(title: "תוספת או ניכוי", systemImage: "plusminus", action: adjustment),
        ])
    }
}

private struct LiftHost: ViewModifier {
    @State private var lifter = Lifter()

    func body(content: Content) -> some View {
        content
            .environment(\.lifter, lifter)
            .overlay {
                LiftOverlay(lifter: lifter)
            }
    }
}

private struct Liftable: ViewModifier {
    let card: Bool
    let preview: () -> AnyView
    let sections: () -> [LiftSection]
    @Environment(\.lifter) private var lifter
    @State private var place = LiftSpot()
    #if DEBUG
    @Environment(\.liftsForScreenshot) private var liftsForScreenshot
    #endif

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                place.frame = frame
            }
            .background {
                LongPress(duration: 0.25) { lift() }
                    .allowsHitTesting(false)
            }
            .accessibilityAction(named: "אפשרויות") { lift() }
            #if DEBUG
            .task {
                // after the tab has appeared, where it is on the screen known
                guard liftsForScreenshot else { return }
                try? await Task.sleep(for: .seconds(1.5))
                lift()
            }
            #endif
    }

    private func lift() {
        Perf.event("הרמה")
        let menu = sections()
        guard let lifter, !menu.isEmpty else { return }
        lifter.show(Lift(source: place.frame, card: card, preview: preview(), sections: menu))
    }
}

/// A long press as UIKit's own, and out of SwiftUI's gestures: an empty view behind a thing that lifts, its long
/// press on the window, taking only a touch on that thing. SwiftUI's LongPressGesture, a simultaneous gesture on a
/// list's rows, held the finger, and the Shifts tab neither scrolled nor swiped; UIKit's put on the rows with
/// .gesture() waited for their buttons, each a gesture under it, and never lifted. This one waits for none and holds
/// up none: it gives up as soon as the finger moves, so that a list scrolls and a row's swipe opens.
private struct LongPress: UIViewRepresentable {
    let duration: TimeInterval
    let action: () -> Void

    func makeUIView(context: Context) -> PressView {
        PressView(duration: duration)
    }

    func updateUIView(_ view: PressView, context: Context) {
        view.action = action
    }
}

/// The view behind a thing that lifts. It takes no touch itself, its thing's button does; its long press is on the
/// window while it is on one, and goes along with every other gesture: a button's tap, which asks the lifter
/// first, a list's scroll and a row's swipe.
private final class PressView: UIView, UIGestureRecognizerDelegate {
    var action: () -> Void = {}
    private let press = UILongPressGestureRecognizer()

    init(duration: TimeInterval) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        press.minimumPressDuration = duration
        press.allowableMovement = 12
        press.cancelsTouchesInView = false
        press.delaysTouchesEnded = false
        press.delegate = self
        press.addTarget(self, action: #selector(pressed))
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window {
            if press.view !== window { window.addGestureRecognizer(press) }
        } else {
            press.view?.removeGestureRecognizer(press)
        }
    }

    @objc private func pressed() {
        guard press.state == .began else { return }
        // once it lifts, the list or the page under it moves no more with the finger, nor does a row's swipe open
        var view = superview
        while let v = view {
            if let scroll = v as? UIScrollView {
                for pan in scroll.gestureRecognizers ?? [] where pan is UIPanGestureRecognizer && pan.isEnabled {
                    pan.isEnabled = false
                    pan.isEnabled = true
                }
            }
            view = v.superview
        }
        action()
    }

    /// A touch on the thing, and not on a bar or a sheet over it: one in the same list, bar or screen. A small thing
    /// (a bar's plus) is taken 44 points round, as its button is.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touched = touch.view, let window, touched.window === window, isShown else { return false }
        let area = bounds.insetBy(dx: min(0, (bounds.width - 44) / 2), dy: min(0, (bounds.height - 44) / 2))
        guard area.contains(touch.location(in: self)), Self.owner(of: touched) === Self.owner(of: self) else { return false }
        Lifter.prepare()
        return true
    }

    /// On the screen, and not in a list's cell kept hidden for another row.
    private var isShown: Bool {
        var view: UIView? = self
        while let v = view {
            if v.isHidden || v.alpha < 0.01 { return false }
            view = v.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    /// What a view is in: the list or the scroll that moves it, a bar, or else the screen it is on, the tabs' or a
    /// sheet's.
    private static func owner(of view: UIView) -> UIView {
        var view = view
        while let parent = view.superview, !(parent is UIWindow) {
            if view is UIScrollView || view is UINavigationBar || view is UITabBar || view is UIToolbar {
                return view
            }
            view = parent
        }
        return view
    }
}

/// Where a liftable thing is on the screen, kept out of its view's state: it changes as the screen scrolls, and
/// should draw nothing again (also the shift's end's, NowView's HoldToEnd). (Place is the workplace's,
/// Live/Place.swift.)
final class LiftSpot {
    var frame: CGRect = .zero
}

/// The screen blurred under the thing lifted and its menu; a tap on it puts the thing down.
private struct LiftOverlay: View {
    let lifter: Lifter

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LiftBlur(on: lifter.isShowing)
                    .ignoresSafeArea()
                if let lift = lifter.lift {
                    let origin = proxy.frame(in: .global).origin
                    ZStack {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture { lifter.dismiss() }
                        LiftStage(lift: lift, source: lift.source.offsetBy(dx: -origin.x, dy: -origin.y),
                                  size: proxy.size, insets: proxy.safeAreaInsets) { item in
                            lifter.dismiss(then: item.action)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .allowsHitTesting(lifter.isShowing)
    }
}

/// The screen under a thing lifted, blurred and a little darker. UIKit's, and always there, with no effect until a lift:
/// its blur grows out of the sharp screen, where a material can only fade in over it as a second image, and the system
/// runs it, whatever this thread is busy with while the thing is first drawn.
private struct LiftBlur: UIViewRepresentable {
    let on: Bool

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: nil)
        view.isUserInteractionEnabled = false
        let shade = UIView(frame: view.bounds)
        shade.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shade.backgroundColor = UIColor { traits in
            UIColor.black.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.3 : 0.06)
        }
        shade.alpha = 0
        view.contentView.addSubview(shade)
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        let on = on
        guard on != (view.effect != nil) else { return }
        UIView.animate(withDuration: on ? 0.16 : 0.1, delay: 0, options: .curveEaseOut) {
            view.effect = on ? UIBlurEffect(style: .systemUltraThinMaterial) : nil
            view.contentView.subviews.first?.alpha = on ? 1 : 0
        }
    }
}

/// The thing lifted and its menu, coming in softly: placed in points from the left, as the screen's are, and drawn right
/// to left. Most of the way there in a tenth of a second, then a soft settling, with no bounce: the user found a quarter
/// of a second slow, and no animation at all strange. They start hidden and all move on one animation, begun once they
/// are made and drawn: whatever the first frame takes isn't then taken out of the animation's time, as a jump at its
/// start. (Almost hidden: what is wholly so isn't drawn yet.)
private struct LiftStage: View {
    let lift: Lift
    /// Where the thing was, in this view's points.
    let source: CGRect
    let size: CGSize
    let insets: EdgeInsets
    let pick: (LiftItem) -> Void
    @State private var shown = false

    /// A card starts at the width of what it lifts, its edges over that thing's, and grows from there; a day, which is
    /// small, from not so far.
    private var cardStart: CGFloat {
        max(0.97, min(1, source.width / (size.width - LiftLayout.margin * 2)))
    }

    var body: some View {
        let above = !lift.card && source.midY > size.height / 2
        let right = lift.card || source.midX > size.width / 2
        LiftLayout(source: source, card: lift.card, lifted: shown, top: insets.top + 8, bottom: insets.bottom + 8) {
            lift.preview
                .environment(\.layoutDirection, .rightToLeft)
                .allowsHitTesting(false)
                // a card over the thing almost at once; a button, as it is, from the first
                .opacity(shown || !lift.card ? 1 : 0.001)
                .animation(.easeOut(duration: 0.08), value: shown)
                .scaleEffect(shown || !lift.card ? 1 : cardStart, anchor: .top)
            LiftMenu(sections: lift.sections, pick: pick)
                .environment(\.layoutDirection, .rightToLeft)
                .scaleEffect(shown ? 1 : 0.94, anchor: UnitPoint(x: right ? 1 : 0, y: above ? 1 : 0))
                .opacity(shown ? 1 : 0.001)
        }
        .environment(\.layoutDirection, .leftToRight)
        .task {
            // on the next turn of the main thread, this frame done
            withAnimation(.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.2)) { shown = true }
        }
    }
}

/// Places a thing lifted and its menu, the two in that order: a card across the screen where the thing was and,
/// once `lifted`, moved up as far as its menu under it needs; or the thing at its own size and place, its menu over it
/// when it is low on the screen and under it otherwise, on its side.
private struct LiftLayout: Layout {
    static let margin: CGFloat = 16

    let source: CGRect
    let card: Bool
    let lifted: Bool
    let top: CGFloat
    let bottom: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let margin = Self.margin
        let gap: CGFloat = 10
        let from = source.offsetBy(dx: bounds.minX, dy: bounds.minY)
        let highest = bounds.minY + top
        let lowest = bounds.maxY - bottom
        let menu = subviews[1].sizeThatFits(.unspecified)
        if card {
            let width = bounds.width - margin * 2
            let height = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            let y = lifted ? max(highest, min(from.minY, lowest - height - gap - menu.height)) : from.minY
            subviews[0].place(at: CGPoint(x: bounds.minX + margin, y: y),
                              proposal: ProposedViewSize(width: width, height: height))
            subviews[1].place(at: CGPoint(x: bounds.maxX - margin - menu.width, y: y + height + gap),
                              proposal: ProposedViewSize(menu))
        } else {
            subviews[0].place(at: from.origin, proposal: ProposedViewSize(from.size))
            let x = from.midX > bounds.midX ? from.maxX - menu.width : from.minX
            let y = from.midY > bounds.midY ? from.minY - gap - menu.height : from.maxY + gap
            subviews[1].place(at: CGPoint(x: min(max(x, bounds.minX + margin), bounds.maxX - margin - menu.width),
                                          y: min(max(y, highest), lowest - menu.height)),
                              proposal: ProposedViewSize(menu))
        }
    }
}

/// A lifted thing's menu, solid over the blur as a lifted card is (glass let the screen under it show through, the bar
/// of the Shifts screen under its plus's most of all): each item's title from the right and its symbol on the left, and
/// a line between the parts.
private struct LiftMenu: View {
    let sections: [LiftSection]
    let pick: (LiftItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sections.indices, id: \.self) { s in
                if s > 0 {
                    Divider()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                }
                if let header = sections[s].header {
                    Text(header)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                }
                ForEach(sections[s].items.indices, id: \.self) { i in
                    row(sections[s].items[i])
                }
            }
        }
        .padding(.vertical, 6)
        .frame(width: 250)
        .background { LiftSurface() }
    }

    private func row(_ item: LiftItem) -> some View {
        Button {
            pick(item)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if let image = item.systemImage {
                    Image(systemName: image)
                        .frame(width: 24)
                }
            }
            .foregroundStyle(item.destructive ? Color.red : Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(LiftItemStyle())
    }
}

/// An item pressed: a shade behind it, as a menu's.
private struct LiftItemStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.primary.opacity(configuration.isPressed ? 0.08 : 0))
    }
}
