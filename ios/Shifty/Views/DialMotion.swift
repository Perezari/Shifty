import SwiftUI

// What moves on the dial's ticks once it stands (NowView's ShiftDial), the user's picks of the animations' mock: the
// time worked's seconds as a second hand, the ticks by the goal's flag growing while it is dragged, and a wave of light
// round them as the goal is reached. Each is drawn over the dial's own gray ticks (DialFace), in its geometry: a tick
// every 6° from 12, every fifth long.

/// A tick lit: its index from 12, and how much, from 0 to 1.
struct LitTick: Hashable {
    let index: Int
    let level: Double
}

/// One of the dial's ticks in the accent, longer and a little wider the more it is lit, over the gray one under it.
struct TickMark: View {
    let size: CGFloat
    let tick: LitTick
    /// How much longer it grows lit in full: 0.8 is four fifths again.
    let grow: Double

    var body: some View {
        let r = size * 160 / 350
        let w = size * 22 / 350
        let big = tick.index % 5 == 0
        let thick: CGFloat = (big ? 2 : 1.5) * CGFloat(1 + 0.5 * tick.level)
        let long: CGFloat = (big ? 9 : 4) * CGFloat(1 + grow * tick.level)
        let middle: CGFloat = r - w / 2 - (big ? 11.5 : 9)
        Capsule()
            .fill(Color.accentColor.opacity(tick.level))
            .frame(width: thick, height: long)
            .offset(y: -middle)
            .rotationEffect(.degrees(Double(tick.index) * 6))
    }
}

/// The time worked's seconds as a clock's second hand: this second's tick lit, the two before it fading, a step a
/// second, drawn again with the dial each second.
struct SecondTicks: View {
    let size: CGFloat
    /// The time worked, in whole seconds.
    let second: Int

    var body: some View {
        ZStack {
            ForEach(Self.lit(second), id: \.index) { tick in
                TickMark(size: size, tick: tick, grow: 0.8)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.15), value: second)
        .allowsHitTesting(false)
    }

    static func lit(_ second: Int) -> [LitTick] {
        [1, 0.5, 0.22].enumerated().map { age, level in
            LitTick(index: ((second - age) % 60 + 60) % 60, level: level)
        }
    }
}

/// The ticks by the goal's flag while the finger drags it, larger the nearer they are, as under a magnifying glass.
struct FlagTicks: View {
    let size: CGFloat
    /// The flag's angle, clockwise from 12.
    let angle: Double

    var body: some View {
        ZStack {
            ForEach(Self.near(angle), id: \.index) { tick in
                TickMark(size: size, tick: tick, grow: 1.5)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeOut(duration: 0.12), value: angle)
        .allowsHitTesting(false)
    }

    static func near(_ angle: Double) -> [LitTick] {
        (0..<60).compactMap { i -> LitTick? in
            var gap = abs((Double(i) * 6 - angle).truncatingRemainder(dividingBy: 360))
            if gap > 180 { gap = 360 - gap }
            let level = exp(-pow(gap / 13, 2))
            return level > 0.03 ? LitTick(index: i, level: level) : nil
        }
    }
}

/// A wave of light round the ticks, clockwise from the goal as it is reached, as the opening's ticks come in: each
/// grows and lights in the accent as it passes, in a little over a second. One canvas, a frame at a time, while it
/// lasts (NowView takes it away after).
struct DialWave: View {
    let size: CGFloat
    /// Where it sets off, clockwise from 12.
    let from: Double
    let began: Date

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { gc, _ in
                TickDrawing.wave(gc, size: size, from: from, after: context.date.timeIntervalSince(began))
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

enum TickDrawing {
    /// The wave `t` seconds after it set off: round the dial in 0.75 s, each tick lit in 0.09 s and out by 0.42 s.
    static func wave(_ context: GraphicsContext, size: CGFloat, from: Double, after t: Double) {
        let c = size / 2
        let r = size * 160 / 350
        let w = size * 22 / 350
        for i in 0..<60 {
            let along = ((Double(i) * 6 - from).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let u = t - along / 360 * 0.75
            let lit = OpeningCurve.out3(u, 0, 0.09) - OpeningCurve.inOut2(u, 0.09, 0.42)
            guard lit > 0.005 else { continue }
            let big = i % 5 == 0
            let thick: CGFloat = (big ? 2 : 1.5) * CGFloat(1 + 0.5 * lit)
            let long: CGFloat = (big ? 9 : 4) * CGFloat(1 + 1.15 * lit)
            let middle: CGFloat = r - w / 2 - (big ? 11.5 : 9)
            let rect = CGRect(x: -thick / 2, y: -middle - long / 2, width: thick, height: long)
            var g = context
            g.translateBy(x: c, y: c)
            g.rotate(by: .degrees(Double(i) * 6))
            g.opacity = lit
            g.fill(Path(roundedRect: rect, cornerRadius: thick / 2), with: .color(Color.accentColor))
        }
    }
}
