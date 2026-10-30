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
    /// The iPhone's tap at each lift, readied as a finger presses: a generator of UIKit's, and not a
    /// sensoryFeedback over the tabs, which drew the whole of them again for each tap.
    private let tap = UIImpactFeedbackGenerator(style: .medium)

    var isShowing: Bool { lift != nil }

    func ready() {
        tap.prepare()
    }

    func show(_ lift: Lift) {
        guard self.lift == nil else { return }
        tap.impactOccurred()
        withAnimation(.spring(duration: 0.22, bounce: 0.15)) { self.lift = lift }
    }

    /// Puts the thing down, then does what was chosen.
    func dismiss(then action: (() -> Void)? = nil) {
        withAnimation(.easeOut(duration: 0.15)) { lift = nil }
        action?()
    }
}

extension EnvironmentValues {
    /// The screen's lifter, set by liftHost().
    @Entry var lifter: Lifter? = nil
}

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
            .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }
}

extension LiftSection {
    /// What a plus adds: a shift by hand, or a paid vacation or sick day.
    static func adding(shift: @escaping () -> Void, dayOff: @escaping (ShiftType) -> Void) -> LiftSection {
        LiftSection(items: [
            LiftItem(title: "משמרת", systemImage: "timer", action: shift),
            LiftItem(title: "יום חופש", systemImage: "sun.max") { dayOff(.vacation) },
            LiftItem(title: "יום מחלה", systemImage: "cross.case") { dayOff(.sick) },
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
    /// Held down, before it lifts: it gives a little under the finger, as iOS's do.
    @GestureState private var pressing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressing ? 0.96 : 1)
            .animation(.easeOut(duration: 0.18), value: pressing)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                place.frame = frame
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.25, maximumDistance: 12)
                    .updating($pressing) { held, state, _ in state = held }
                    .onEnded { _ in lift() }
            )
            .onChange(of: pressing) { _, held in
                if held { lifter?.ready() }
            }
            .accessibilityAction(named: "אפשרויות") { lift() }
    }

    private func lift() {
        Perf.event("הרמה")
        let menu = sections()
        guard let lifter, !menu.isEmpty else { return }
        lifter.show(Lift(source: place.frame, card: card, preview: preview(), sections: menu))
    }
}

/// Where a liftable thing is on the screen, kept out of its view's state: it changes as the screen scrolls, and
/// should draw nothing again. (Place is the workplace's, Live/Place.swift.)
private final class LiftSpot {
    var frame: CGRect = .zero
}

/// The screen blurred under the thing lifted and its menu; a tap on it puts the thing down.
private struct LiftOverlay: View {
    let lifter: Lifter
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { proxy in
            if let lift = lifter.lift {
                let origin = proxy.frame(in: .global).origin
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Color.black.opacity(scheme == .dark ? 0.3 : 0.06)
                        }
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
        .allowsHitTesting(lifter.isShowing)
    }
}

/// The thing lifted and its menu, popping up as they appear: placed in points from the left, as the screen's
/// are, and drawn right to left.
private struct LiftStage: View {
    let lift: Lift
    /// Where the thing was, in this view's points.
    let source: CGRect
    let size: CGSize
    let insets: EdgeInsets
    let pick: (LiftItem) -> Void
    @State private var shown = false

    var body: some View {
        let above = !lift.card && source.midY > size.height / 2
        let right = lift.card || source.midX > size.width / 2
        LiftLayout(source: source, card: lift.card, top: insets.top + 8, bottom: insets.bottom + 8) {
            lift.preview
                .environment(\.layoutDirection, .rightToLeft)
                .allowsHitTesting(false)
                .scaleEffect(shown ? 1 : 0.94)
            LiftMenu(sections: lift.sections, pick: pick)
                .environment(\.layoutDirection, .rightToLeft)
                .scaleEffect(shown ? 1 : 0.6, anchor: UnitPoint(x: right ? 1 : 0, y: above ? 1 : 0))
                .opacity(shown ? 1 : 0)
        }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            withAnimation(.spring(duration: 0.24, bounce: 0.2)) { shown = true }
        }
    }
}

/// Places a thing lifted and its menu, the two in that order: a card across the screen where the thing was,
/// moved up as far as its menu under it needs; or the thing at its own size and place, its menu over it when it
/// is low on the screen and under it otherwise, on its side.
private struct LiftLayout: Layout {
    let source: CGRect
    let card: Bool
    let top: CGFloat
    let bottom: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let margin: CGFloat = 16
        let gap: CGFloat = 10
        let from = source.offsetBy(dx: bounds.minX, dy: bounds.minY)
        let highest = bounds.minY + top
        let lowest = bounds.maxY - bottom
        let menu = subviews[1].sizeThatFits(.unspecified)
        if card {
            let width = bounds.width - margin * 2
            let height = subviews[0].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            let y = max(highest, min(from.minY, lowest - height - gap - menu.height))
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

/// A lifted thing's menu on glass, as iOS's: each item's title from the right and its symbol on the left, and a
/// line between the parts.
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
