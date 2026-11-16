import Foundation

/// The butterfly tie. The icon's tile drops under the dial's place and grows into a small portrait card; on the way
/// down his head lags and the air lifts his bow tie's wings, and as he lands they flop. Then the bow tie (in Hebrew: a
/// "butterfly tie") flaps its wings by itself, lifts off the collar and flies up as a butterfly; he follows it with
/// his eyes. It settles on the dial's ring at this very minute: its knot becomes the "now" knob, the wing behind it
/// unrolls back along the ring into the time worked, the wing ahead on to the goal. The tile becomes the facts card
/// and he sinks out of it.
///
/// On another day each wing becomes what the dial really has on its side of the knob: the wing behind unrolls over a
/// running shift's time (its breaks and its overtime come up through it once it lies there), the wing ahead over the
/// pieces ahead, in their own pale color, to where they end. A wing with nothing to become on its side (no shift
/// running, a goal already reached) folds in under the knob as the knot turns over into it, and what the day has
/// apart from the knob (the day's finished shifts) comes up by itself.
struct ButterflyOpening: OpeningScene {
    let id = "butterfly"
    let name = "הפרפר"
    let about = "עניבת הפרפר שלו מנפנפת בכנפיים, מתנתקת מהצווארון ועפה אל הטבעת. הקשר שלה נהיה הסמן של עכשיו, והכנפיים נפרשות לשעות שכבר עבדת ולדרך עד היעד."
    let rest = 2.75
    let end = 4.35
    let haptics = [OpeningHaptic(1.3, .light), OpeningHaptic(1.94, .light)]
    let poster = 0.98
    let arrive = 0.5

    private enum Side {
        case left, right
    }

    /// A wing's outline on the icon's grid: from the knot outward, how far each edge is from the bow's level line
    /// (`body` units long), and then a round tip (`cap` units long).
    private struct Wing {
        let body: Double
        let cap: Double
        let top: [Double]
        let bot: [Double]
    }

    private static let left = Wing(
        body: 64.3, cap: 25,
        top: [23.7, 23.2, 22.7, 21.2, 21.2, 24.2, 27.2, 29.7, 32.2, 34.7, 36.7, 38.7, 40.2, 42.2, 43.2, 44.2, 44.2, 44.2, 43.7, 43.2, 42.7],
        bot: [26.3, 25.8, 25.3, 24.3, 22.3, 24.8, 27.8, 30.8, 33.8, 36.3, 38.8, 41.3, 43.3, 45.3, 46.8, 48.3, 49.8, 50.8, 51.8, 52.3, 52.3])
    private static let right = Wing(
        body: 60.7, cap: 24,
        top: [23.7, 23.2, 22.7, 22.2, 20.7, 18.7, 21.2, 23.7, 25.7, 27.7, 29.2, 30.7, 32.2, 33.7, 34.7, 35.7, 36.7, 36.7, 37.2, 37.2, 36.7],
        bot: [26.3, 25.8, 25.3, 24.3, 22.3, 25.8, 28.8, 31.3, 34.3, 36.8, 38.8, 41.3, 43.3, 45.3, 47.3, 48.8, 49.8, 50.8, 51.8, 51.8, 51.8])

    func draw(_ t: Double, _ K: OpeningKit) {
        let E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, C = K.C, P = K.P, g = K.g, o = K.o
        func hump(_ x: Double) -> Double { (1 - cos(2 * Double.pi * K.clamp(x))) / 2 }   // 0, up to 1, back to 0
        let R = DIAL.r, HW = DIAL.w / 2, NOW = DIAL.start + DIAL.now
        let (nx, ny) = K.markAt(.knob)
        let NAVY = OpeningColor(hex: 0x16265C)                      // the wings' flat navy: the picture's own
        let KNOT: OpeningPoint = (P.knot.x, P.knot.y)
        let SIZE = 176.0, CY = 560.0                                // the tile under the dial
        let LAND = 26.0 / 98                                        // the butterfly's size on the ring: its wings a little taller than the ring is wide
        // the moments
        let OWN = 0.12                                              // from the first move the bow tie is drawn on its own, over him
        let FLAP1 = 0.42, FLAP2 = 0.54, OFF = 0.66, ON = 1.30       // two flaps on the collar; it is off; it is on the ring
        let BEAT = (ON - OFF) / 6                                   // six wing-beats on the way
        let FLIP = ON + 0.07                                        // the knot turns over into the knob
        let B0 = ON + 0.12, B1 = ON + 0.66, F0 = ON + 0.16, F1 = ON + 0.56   // the wing behind unrolls; the wing ahead
        let DONE = B1 + 0.2                                         // from here the dial's own arcs and marks stand for it all
        let CARD = ON + 0.44                                        // the tile becomes the facts card

        // ---- the day on the dial: what each wing has to become
        // behind the knob: a running shift's time, solid all the way from the start (else nothing to unroll over)
        let BACK = DIAL.now > 0 && K.covered(from: 0, to: DIAL.now) ? min(DIAL.now, 360) : 0
        // ahead of it: the pieces from the knob on, as far as they go without a gap
        var reach = DIAL.now
        var pieces: [OpeningLayout.Piece] = []
        for piece in K.layout.pieces.filter({ $0.ahead }).sorted(by: { $0.from < $1.from })
        where piece.from <= reach + 1e-6 && piece.to > reach {
            pieces.append(piece)
            reach = piece.to
        }
        let AHEAD = min(reach - DIAL.now, 360)
        // the arc ahead as it shows on the track: its first piece's color over the track over the background
        func over(_ top: OpeningColor, _ under: OpeningColor) -> OpeningColor {
            OpeningColor(top.r * top.a + under.r * (1 - top.a), top.g * top.a + under.g * (1 - top.a),
                         top.b * top.a + under.b * (1 - top.a))
        }
        let PALE = over(pieces.first?.color ?? C.accent.alpha(0.18), over(C.track, C.background)).whole
        // one color all the way: the wing is the arc. If not (a plan's pieces), the day's own show through it at the end
        let plain = pieces.allSatisfy { $0.color == pieces[0].color }
        // each wing's round tip ends under a mark: the start's, and the flag (or, round the whole ring, the knob)
        let backTip = DIAL.goal != nil
        let frontTip = AHEAD >= 360 || (DIAL.flag.map { abs($0 - reach) < 1e-6 } ?? false)

        // ---- the wings' outline
        func prof(_ arr: [Double], _ u: Double) -> Double {
            let f = K.clamp(u) * Double(arr.count - 1), i = min(arr.count - 2, Int(f.rounded(.down)))
            return K.lerp(arr[i], arr[i + 1], f - Double(i))
        }
        /* One wing as a flat shape: a ribbon from the knot at x, y outward (the left one backward, the right one
           forward) along the line `rot`, curved by `bend`, `length` long, and a round tip on its end (`tip` of it: 0
           is a square end). flat 0 is the wing's own outline at the size k; flat 1 is the ring's even band with a
           half-round end. */
        func wing(_ ctx: OpeningPen, _ side: Side, _ x: Double, _ y: Double, _ k: Double, _ rot: Double, _ bend: Double,
                  _ length: Double, _ flat: Double, _ fill: OpeningColor, _ alpha: Double = 1, tip: Double = 1) {
            let W = side == .left ? Self.left : Self.right, sign = side == .left ? -1.0 : 1.0, th0 = rot * Double.pi / 180
            let own = W.cap * k * min(1, length / ((W.body + W.cap) * k))
            let cap = K.lerp(own, HW, flat) * tip, body = max(0.01, length - cap)
            func pt(_ s: Double) -> OpeningPoint {
                bend != 0 ? (x + (sin(th0 + bend * s) - sin(th0)) / bend, y - (cos(th0 + bend * s) - cos(th0)) / bend)
                    : (x + s * cos(th0), y + s * sin(th0))
            }
            let mid = pt(sign * body / 2)
            // u from the knot (0) to the tip (1)
            func half(_ arr: [Double], _ u: Double) -> Double { K.lerp(max(0, prof(arr, u) - 0.8) * k, HW, flat) }
            K.ribbon(ctx, x: mid.x, y: mid.y, dir: rot + bend * sign * body / 2 * 180 / Double.pi, length: body, bend: bend,
                     top: { u in half(W.top, sign < 0 ? 1 - u : u) }, bottom: { u in half(W.bot, sign < 0 ? 1 - u : u) },
                     fill: fill, alpha: alpha, n: flat > 0 ? 96 : 24)
            let end = pt(sign * body), hT = half(W.top, 1), hB = half(W.bot, 1)
            ctx.save()
            ctx.alpha *= alpha
            ctx.translate(end.x, end.y)
            ctx.rotate(th0 + bend * sign * body)
            ctx.scale(sign, 1)
            var p = OpeningPath()
            p.move(-0.6, -hT)
            p.ellipse(0, 0, cap, hT, 0, -Double.pi / 2, 0)
            p.ellipse(0, 0, cap, hB, 0, 0, Double.pi / 2)
            p.line(-0.6, hB)
            p.close()
            ctx.fill(p, fill)
            ctx.restore()
        }
        // a wing's own length at the size k (a hair inside its picture)
        func span(_ s: Side, _ k: Double) -> Double {
            let W = s == .left ? Self.left : Self.right
            return (W.body + W.cap) * k * 0.985
        }
        /* The butterfly: the bow tie's own picture, its two wings narrowed toward the knot (sx) and raised in a V (vee,
           degrees) for a flap; under the picture, as it fades (shade), the same wings as a flat shape in `fill`. In the
           dark look all of it has one edge round it, `edge` of the icon's. */
        func butterfly(_ ctx: OpeningPen, _ x: Double, _ y: Double, _ k: Double, _ rot: Double, _ sx: Double, _ vee: Double,
                       _ shade: Double, _ fill: OpeningColor, _ bend: Double, edge: Double) {
            K.edged(ctx, C.edgeShare * 512 * k * edge) {
                if shade < 1 {
                    for s in [Side.left, .right] {
                        wing(ctx, s, x, y, k, rot + (s == .left ? vee : -vee), bend, span(s, k) * sx, 0, fill, K.seg(1 - shade, 0, 0.15))
                    }
                }
                if shade > 0 {
                    if vee == 0 {
                        K.sprite(ctx, .wings, x, y, k: k, rot: rot, sx: sx, alpha: shade, anchor: KNOT, edge: 0)
                    } else {
                        for s in [-1.0, 1.0] {
                            ctx.save()
                            ctx.translate(x, y)
                            ctx.rotate((rot - s * vee) * Double.pi / 180)
                            ctx.clip(.rect(s < 0 ? -300 : 0, -300, 300, 600))
                            K.sprite(ctx, .wings, 0, 0, k: k, sx: sx, alpha: shade, anchor: KNOT, edge: 0)
                            ctx.restore()
                        }
                    }
                }
                K.sprite(ctx, .knot, x, y, k: k, rot: rot, anchor: KNOT, edge: 0)
            }
        }

        // ---- the tile steps down under the dial's place and grows; later its frame becomes the facts card's
        let step = K.spring(t, 0.12, 0.4, 0.7)                      // it dips a little past its place and comes back
        let box = K.box(LAUNCH.x, K.lerp(LAUNCH.y, CY, step), K.lerp(LAUNCH.size, SIZE, step))
        // how fast it moves, 1 at its fastest: his head and the tie's wings lag
        let vel = (step - K.spring(t - 0.06, 0.12, 0.4, 0.7)) / 0.416
        let m = K.spring(t, CARD, 0.46, 0.78)
        let card = K.facts                                          // the real card: as wide as the screen has it
        let fr = (x: K.lerp(box.x, card.x, m), y: K.lerp(box.y, card.y, m), w: K.lerp(box.size, card.w, m),
                  h: K.lerp(box.size, card.h, m), r: K.lerp(box.r, 22, m))
        // he sinks out of the card
        let sink = -5 * K.seg(t, CARD - 0.08, CARD + 0.04, E.io2) + 135 * K.seg(t, CARD + 0.04, CARD + 0.38, E.in2)
        let manBox = K.box(box.cx, box.cy + sink, box.size)
        let land = K.wobble(t, 0.33, 0.24, 9)                       // he lands in his new place: a soft squash on the tile's floor, and a settle
        // and on the way down he stretches a little
        let squash = (x: 1 - 0.015 * vel + 0.03 * land, y: 1 + 0.04 * vel - 0.08 * land)

        // ---- the butterfly's way: off the collar to the right, past his face, up beside the tile, and on to the ring at
        //      "now": two curves, walked at an even pace
        let collar = box.pt(256 + (KNOT.x - 256) * squash.x, 512 - (512 - KNOT.y) * squash.y)
        func bez(_ a: Double, _ b: Double, _ c: Double, _ d: Double, _ u: Double) -> Double {
            let v = 1 - u
            let first = a * pow(v, 3) + 3 * b * u * pow(v, 2)
            return first + 3 * c * u * u * v + d * pow(u, 3)
        }
        let edge = LAUNCH.x + SIZE / 2                              // the tile's right edge
        let rise: OpeningPoint = (edge + 29, CY - 24)               // beside the tile, going up: where the first curve ends
        /* How it comes to the ring. Wherever the ring is beyond the dial's middle, as seen from there, it flies into
           the dial and out to the ring, arriving outward (the mock's shift, at 2 o'clock). The stretch of the ring that
           faces it (4 to 7 o'clock, between the two lines from there that touch the ring) it cannot reach from the
           inside without a hairpin: there its last heading turns evenly from outward at one end of the stretch, by
           straight in at its middle, to outward at the other. And a place nearby gets shorter curves. */
        let seen = atan2(rise.x - DIAL.x, -(rise.y - DIAL.y)) * 180 / Double.pi        // where it is, round the dial
        let wide = acos(min(1, R / hypot(rise.x - DIAL.x, rise.y - DIAL.y))) * 180 / Double.pi
        let turned = (NOW - seen + 180).truncatingRemainder(dividingBy: 360)
        let off = (turned < 0 ? turned + 360 : turned) - 180       // the knob's place from there, -180 to 180
        var toward = NOW                                            // its last heading, clockwise from up
        if abs(off) < wide {
            toward = K.lerp(seen - wide, seen + wide - 360, (off + wide) / (2 * wide))
        }
        let out: OpeningPoint = (sin(toward * Double.pi / 180), -cos(toward * Double.pi / 180))
        let near = min(1, 0.4 * hypot(nx - rise.x, ny - rise.y) / 110)
        let AX = [collar.x, collar.x + 26, rise.x, rise.x], AY = [collar.y, collar.y + 2, CY + 58, rise.y]
        let BX = [rise.x, rise.x, nx - 110 * near * out.x, nx], BY = [rise.y, rise.y - 86 * near, ny - 110 * near * out.y, ny]
        var way: [OpeningPoint] = []
        for i in 0...20 {
            let u = Double(i) / 20
            way.append((bez(AX[0], AX[1], AX[2], AX[3], u), bez(AY[0], AY[1], AY[2], AY[3], u)))
        }
        for i in 1...30 {
            let u = Double(i) / 30
            way.append((bez(BX[0], BX[1], BX[2], BX[3], u), bez(BY[0], BY[1], BY[2], BY[3], u)))
        }
        var far = [0.0]
        for i in 1..<way.count {
            far.append(far[i - 1] + hypot(way[i].x - way[i - 1].x, way[i].y - way[i - 1].y))
        }
        let total = far[far.count - 1]
        func on(_ d: Double) -> OpeningPoint {                      // the point `d` along the way
            let d = K.clamp(d, 0, total)
            var i = 1
            while i < way.count - 1 && far[i] < d { i += 1 }
            let gap = far[i] - far[i - 1], u = (d - far[i - 1]) / (gap != 0 ? gap : 1)
            return (K.lerp(way[i - 1].x, way[i].x, u), K.lerp(way[i - 1].y, way[i].y, u))
        }
        // the way's heading at `d`, clockwise from up; followed from the way's start, so that it never leaps a whole turn
        func headed(_ d: Double) -> Double {
            func raw(_ d: Double) -> Double {
                let a = on(d - 7), b = on(d + 7)
                return atan2(b.x - a.x, -(b.y - a.y)) * 180 / Double.pi
            }
            var h = raw(0)
            for j in 1...48 {
                let at = min(total * Double(j) / 48, d), r = raw(at)
                h = r + 360 * ((h - r) / 360).rounded()
                if at >= d { break }
            }
            return h
        }
        let fly = K.seg(t, OFF - 0.04, ON) { x in x * x * (3 - 2 * x) }               // a gentle start, an even pace, a soft arrival
        let p = on(fly * total)
        // the bow's turn when it lies along the ring at "now": the right way up or upside down, whichever is nearer
        // to how it arrives (the wing that then points back is the one that unrolls back)
        let halves = ((NOW - headed(total)) / 180).rounded()
        let LIE = NOW - 180 * halves
        let upside = halves.truncatingRemainder(dividingBy: 2) != 0
        let backSide: Side = upside ? .right : .left, frontSide: Side = upside ? .left : .right
        let ringBend = (upside ? -1 : 1) / R
        let heading = fly >= 1 ? LIE : headed(fly * total)
        let beat = t < OFF ? 0 : (t - OFF) / BEAT
        // the wings: 0 flat, 1 raised
        let up = t < OFF ? 0.6 * hump(K.seg(t, FLAP1, FLAP2)) + hump(K.seg(t, FLAP2, OFF))
            : t < ON ? hump(beat.truncatingRemainder(dividingBy: 1)) : 0
        let air = sin(Double.pi * K.seg(t, OFF, ON))                // 0 on the collar and on the ring
        // the second flap lifts it off the collar: a dip as the wings rise, a hop as they come down
        let dip = 1.5 * sin(Double.pi * K.seg(t, FLAP2, FLAP2 + 0.06)) - 5 * K.seg(t, FLAP2 + 0.06, OFF + 0.02, E.io2)
        let hop = dip * (1 - K.seg(t, OFF + 0.04, OFF + 0.3, E.io2))
        let bx = p.x, by = p.y + hop + 4.5 * air * (2 * up - 1)     // in the air the body bobs up on each down-stroke
        // while he drops the air lifts the tie's wings; as he lands they flop down past level, swing once and lie still
        let trail = 15 * vel - 8 * K.wobble(t, 0.36, 0.2, 11)
        let sway = 3 * K.wobble(t, 0.36, 0.18, 10)                  // and the tie swings a little on its knot
        let turn = K.lerp(heading * K.seg(fly, 0.3, 0.72, E.io2), LIE, K.seg(fly, 0.72, 1, E.io2))
        let rot = turn + 5 * air * sin(2 * Double.pi * beat) + sway
        let bk = K.lerp(box.k, LAND, K.seg(t, OFF, ON - 0.04, E.io2))
        let shade = 1 - K.seg(t, OFF + 0.14, ON - 0.08)             // the picture's shading gives way to a flat shape
        let tint = 0.4 * K.seg(t, OFF + 0.14, ON, E.io2)

        // ---- the wings on the ring
        func EU(_ x: Double) -> Double { 1 - pow(1 - pow(x, 1.5), 3) }
        func EUinv(_ p: Double) -> Double { pow(1 - pow(1 - K.clamp(p), 1.0 / 3), 1 / 1.5) }
        let spread = 1 + 0.12 * K.wobble(t, ON, 0.16, 14)           // as it alights its wings spread a little and settle
        // a tip with no mark to end under goes square as it arrives
        let backRound = backTip ? 1 : 1 - K.seg(t, B1 - 0.14, B1, E.io2), frontRound = frontTip ? 1 : 1 - K.seg(t, F1 - 0.14, F1, E.io2)
        let backLen = K.lerp(span(backSide, LAND) * spread, R * BACK * Double.pi / 180 + HW * backRound, K.seg(t, B0, B1, EU))
        let frontLen = K.lerp(span(frontSide, LAND) * spread, R * AHEAD * Double.pi / 180 + HW * frontRound, K.seg(t, F0, F1, EU))
        let flat = K.seg(t, B0 - 0.02, B0 + 0.22, E.io2)
        // both wings to the accent; the one ahead on to its pale
        let teal = K.lerp(0.4, 1, K.seg(t, B0, B0 + 0.3, E.io2)), pale = K.seg(t, F0 + 0.1, F1, E.io2)
        /* When a wing has come to a place on the ring, `deg` from the start: the mark there comes up from 0.07 s before
           this moment. At a wing's end it is the wing's own last moment, as the mock has it (0.07 s before it the tip
           is all but there, 0.7 of HW over the place). On a wing's way it is 0.07 s after the tip is as far over the
           place, so that a mark is never there ahead of its wing. And a mark that stands on the knob, or touches it,
           waits for the knob to be whole: the knot's turn into the knob is seen first. Nil where neither wing goes. */
        func passes(_ deg: Double) -> Double? {
            // `far` degrees along a wing that unrolls over `whole` degrees between `from` and `to`, from its `own` length
            func along(_ far: Double, _ whole: Double, _ from: Double, _ to: Double, _ own: Double, _ tip: Bool) -> Double {
                var at = to
                if far < whole - 1e-6 {
                    let full = R * whole * Double.pi / 180 + (tip ? HW : 0), over = R * far * Double.pi / 180 + 0.7 * HW
                    at = min(to, (full > own ? from + (to - from) * EUinv((over - own) / (full - own)) : from) + 0.07)
                }
                return R * far * Double.pi / 180 < K.KNOB.r + 21 ? max(at, FLIP + 0.22 + 0.07) : at
            }
            if deg >= DIAL.now, AHEAD > 0, deg - DIAL.now <= AHEAD + 1e-6 {
                return along(deg - DIAL.now, AHEAD, F0, F1, span(frontSide, LAND), frontTip)
            }
            if deg <= DIAL.now, BACK > 0 { return along(DIAL.now - deg, BACK, B0, B1, span(backSide, LAND), backTip) }
            return nil
        }

        // ---- the dial
        func wave(_ i: Int) -> OpeningDialTick {
            let a = Double(i * 6)
            let back = ((NOW - a).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let front = ((a - NOW).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            // a tick comes up as a wing's tip passes it; beyond the wings, and where a wing only folds, as a ripple from there
            let tb = BACK <= 0 ? B0 + back / 600 : back <= BACK ? B0 + (B1 - B0) * EUinv(back / BACK) : B1 + (back - BACK) / 600
            let tf = AHEAD <= 0 ? F0 + front / 600 : front <= AHEAD ? F0 + (F1 - F0) * EUinv(front / AHEAD) : F1 + (front - AHEAD) / 600
            let at = min(tb, tf) + 0.03
            return OpeningDialTick(k: K.seg(t, at, at + 0.24, E.back), a: K.seg(t, at, at + 0.12))
        }
        let handed = t >= DONE
        if t >= DONE + 0.4 {
            K.dial()
        } else {
            // the wing behind was all in the accent: the day's own colors (a break, overtime) come up through it
            let through: (color: OpeningColor, share: Double)? = BACK > 0 ? (C.accent, 1 - K.seg(t, DONE, DONE + 0.3, E.io2)) : nil
            K.dial(track: K.seg(t, FLAP1 + 0.04, FLAP1 + 0.36), numerals: K.seg(t, B0 + 0.22, B0 + 0.52),
                   span: handed ? nil : 0, tint: through, ahead: handed ? 1 : 0, marks: handed ? [1, 1, 1] : [0, 0, 0], tick: wave)
            if !handed {
                // what the day has apart from the wings comes up by itself: finished shifts behind a knob with none
                // running, and pieces ahead that do not begin at the knob
                let came = K.seg(t, B0, B1, E.io2)
                if BACK <= 0 && DIAL.worked > 0 && came > 0 {
                    g.save()
                    g.alpha = came
                    K.worked(g, to: DIAL.worked)
                    g.restore()
                }
                if reach < DIAL.end && came > 0 { K.ahead(g, from: reach, to: DIAL.end, alpha: came) }
                // a plan's pieces come to lie under the wing ahead once it has reached its end, and show as it goes
                if AHEAD > 0 && !plain && t > F1 { K.ahead(g, from: DIAL.now, to: reach, alpha: K.seg(t, F1, F1 + 0.03)) }
            }
        }

        // ---- the tile: its ground under the facts card, the man over it, cut by its frame
        let tile = 1 - K.seg(t, CARD + 0.56, CARD + 0.7)
        if tile > 0 {
            let k = box.k
            g.save()
            g.alpha = tile
            // the icon's ground, top and bottom, into the card's color
            g.fill(.roundRect(fr.x, fr.y, fr.w, fr.h, fr.r), .linear(x0: 0, y0: fr.y, x1: 0, y1: fr.y + fr.h, stops: [
                OpeningStop(0, K.mix(C.groundTop, C.card, m)), OpeningStop(1, K.mix(C.groundBottom, C.card, m)),
            ]))
            // the icon's faint line into the card's own: the screen's ink, as faint (the dark icon has none to begin with)
            let mm = K.clamp(m), inset = K.lerp(1.1 * k, -0.25, mm)
            let line = C.dark ? OpeningColor(255, 255, 255, K.lerp(C.hairline.a, 0.06, mm)) : OpeningColor(0, 0, 0, K.lerp(C.hairline.a, 0.08, mm))
            if line.a > 0 {
                g.stroke(.roundRect(fr.x + inset, fr.y + inset, fr.w - 2 * inset, fr.h - 2 * inset, max(0, fr.r - inset)),
                         line, width: K.lerp(2.2 * k, 0.5, mm))
            }
            g.restore()
        }
        if t < CARD + 0.42 {
            // his acting: the eyes open and drop to the tie, the chin tucks, the brows jump; then he follows the butterfly up
            let SEE = FLAP1 + 0.05                                  // he notices: a beat after the first flap begins
            let open = K.seg(t, SEE, SEE + 0.1, E.io2) - K.seg(t, ON + 0.02, ON + 0.14, E.io2)
            let tuck = K.seg(t, SEE, SEE + 0.14, E.io2) - K.seg(t, OFF + 0.06, OFF + 0.34, E.io2)
            let brow = K.spring(t, SEE + 0.02, 0.28, 0.5) - K.seg(t, ON + 0.04, ON + 0.2, E.io2)
            let curl = K.seg(t, OFF + 0.12, OFF + 0.32, E.io2) - K.seg(t, ON + 0.08, ON + 0.28, E.io2)
            let nod = hump(K.seg(t, ON + 0.08, ON + 0.36))          // "there": a small nod as it lands
            let eye = manBox.pt(297, 234), gx = bx - eye.x, gy = by - eye.y, away = max(60, hypot(gx, gy))
            let lean = -5.5 * vel + 2.5 * K.wobble(t, 0.38, 0.2, 10) + 6 * tuck
            let head = OpeningMove(dy: -3 * vel + 3 * tuck + 1.5 * nod,
                                   rot: lean - 5 * hump(K.seg(t, OFF + 0.2, ON + 0.12)) + 3 * nod)
            let brows = OpeningMove(dy: -6 * brow)
            let eyes = OpeningMove(dx: 4.5 * gx / away * open, dy: 4.5 * gy / away * open, open: open)
            let stache = OpeningMove(split: 7 * curl)
            let gone = 1 - K.seg(t, CARD - 0.1, CARD + 0.02, E.io2) // the logo's ticks draw in and go
            o.save()
            o.clip(.roundRect(fr.x, fr.y, fr.w, fr.h, fr.r))
            K.ticks(o, manBox) { _, _ in OpeningLogoTick(a: gone, len: K.lerp(0.3, 1, gone), out: -16 * (1 - gone)) }
            let floor = manBox.pt(256, 512)                         // the tile's floor, under him
            o.translate(floor.x, floor.y)
            o.scale(squash.x, squash.y)
            o.translate(-floor.x, -floor.y)
            if t < OWN {
                K.man(o, manBox, OpeningPose(head: head, brows: brows, eyes: eyes, stache: stache))
            } else {
                /* With the tie off his collar shows, and the layers' pictures are rough where the tie used to cover them. So he
                   is drawn layer by layer with a clean neck in between, all on the icon's grid: the shirt; the neck going on up
                   behind the head, and its two side lines; the head; over the head's lower edge a patch of the neck's color
                   and round ends on its outline; last the collar's line and its meeting with the shoulder, drawn again clean.
                   (His own colors, the same in both looks.) */
                let NECK = OpeningColor(hex: 0xF3AC79), INK = OpeningColor(hex: 0x02132F)
                func onGrid(_ withHead: Bool, _ draw: () -> Void) {
                    o.save()
                    o.translate(manBox.x, manBox.y)
                    o.scale(manBox.k, manBox.k)
                    if withHead {
                        o.translate(P.neck.x, P.neck.y + head.dy)
                        o.rotate(head.rot * Double.pi / 180)
                        o.translate(-P.neck.x, -P.neck.y)
                    }
                    draw()
                    o.restore()
                }
                func shape(_ fill: OpeningColor, _ pts: [(Double, Double)]) {
                    var path = OpeningPath()
                    for (i, q) in pts.enumerated() {
                        if i == 0 { path.move(q.0, q.1) } else { path.line(q.0, q.1) }
                    }
                    path.close()
                    o.fill(path, fill)
                }
                func dot(_ x: Double, _ y: Double, _ r: Double) { o.fill(.circle(x, y, r), INK) }
                func line(_ path: OpeningPath, _ width: Double) { o.stroke(path, INK, width: width, cap: .round, join: .round) }
                // in the dark look the edge goes round all of him as one, and not along his picture's straight sides
                if C.edge != nil { o.clip(.rect(manBox.x, K.bounds.y, manBox.size, manBox.y + manBox.size - K.bounds.y)) }
                K.edged(o, C.edgeShare * manBox.size) {
                    K.man(o, manBox, OpeningPose(hide: [.head, .bow], edge: 0))
                    onGrid(false) {
                        shape(NECK, [(203, 350), (333, 350), (334, 372), (343, 385), (300, 395), (240, 395), (203, 366)])
                        // the left side line: inside the tie's own corner while the tie lies on it, then its full width
                        let s = K.seg(t, OWN, OWN + 0.1)
                        var side = OpeningPath()
                        side.move(K.lerp(183.3, 183.5, s), K.lerp(376.3, 378, s))
                        side.quad(K.lerp(186.4, 185, s), K.lerp(367, 365, s), K.lerp(202.8, 201, s), K.lerp(360.2, 359, s))
                        line(side, K.lerp(4.6, 7, s))
                        line(.line(346, 384.5, 330.9, 366.6), 8)    // the right one, up into the head
                    }
                    K.man(o, manBox, OpeningPose(head: head, brows: brows, eyes: eyes, stache: stache, hide: [.body, .bow], edge: 0))
                    onGrid(true) {
                        // the patch's upper edge is the tie's own upper edge, so nothing changes while the tie still lies on it
                        shape(NECK, [(218.8, 359.6), (228, 364.3), (240, 372.8), (246, 378), (248, 382.1), (252, 383.2), (260, 380.6),
                                     (268, 380.6), (276, 383.6), (280, 385.6), (284, 382.1), (286, 379), (296, 372.3), (308, 367.8),
                                     (316, 365.8), (320, 365.8), (328, 367.3), (331.5, 369.2), (333, 377), (300, 392), (240, 392),
                                     (226, 386), (219, 368)])
                        // the small shadow that showed over the knot goes as the tie lifts off
                        o.alpha = K.seg(t, FLAP2, OFF + 0.1)
                        shape(NECK, [(236, 366.5), (252, 370), (264, 372.5), (278, 374), (294, 373.6), (286, 379), (284, 382.1),
                                     (280, 385.6), (276, 383.6), (268, 380.6), (260, 380.6), (252, 383.2), (248, 382.1), (246, 378),
                                     (240, 372.8)])
                        o.alpha = 1
                        dot(217.6, 361.6, 2.6)
                        dot(333.6, 373.7, 1.9)
                    }
                    onGrid(false) {
                        var collarLine = OpeningPath()
                        collarLine.move(184, 381.8)
                        collarLine.quad(265.5, 449, 347, 387.3)
                        line(collarLine, 8.6)
                        shape(INK, [(175, 377.6), (180, 376.4), (187, 379), (190, 391.6), (175, 390.4)])
                    }
                }
            }
            o.restore()
        }

        // ---- the butterfly: on the collar, in the air, on the ring
        if t >= OWN && t < ON {
            // each beat: the wings up and together over the knot, then down, in the air a little past level.
            // (The dark look's edge is its own once it leaves him: none while it lies on his collar.)
            butterfly(o, bx, by, bk, rot, 1 - 0.5 * up - max(0, trail) / 60, 30 * up + trail - 9 * air * (1 - up), shade,
                      K.mix(NAVY, C.accent, tint), K.seg(t, ON - 0.08, ON, E.io2) * ringBend,
                      edge: K.seg(t, FLAP2, OFF + 0.08, E.io2))
        } else if t >= ON && t < DONE {
            let ringRot = upside ? NOW + 180 : NOW
            // a wing with nothing to become folds in toward the knot, and the knob comes over it
            func fold(_ side: Side, _ from: Double) {
                let shut = K.seg(t, from, from + 0.24, E.io2), there = 1 - K.seg(t, from + 0.14, from + 0.24)
                if there <= 0 { return }
                wing(g, side, nx, ny, LAND, ringRot, ringBend, span(side, LAND) * spread * (1 - shut), 0, K.mix(NAVY, C.accent, 0.4), there)
            }
            // the dark look's edge goes as the wings become the ring's own band, or fold away
            K.edged(g, C.edgeShare * 512 * LAND * (1 - K.seg(t, B0 - 0.02, B0 + 0.12, E.io2))) {
                if BACK > 0 {
                    wing(g, backSide, nx, ny, LAND, ringRot, ringBend, backLen, flat, K.mix(NAVY, C.accent, teal), tip: backRound)
                } else {
                    fold(backSide, B0)
                }
                if AHEAD > 0 {
                    wing(g, frontSide, nx, ny, LAND, ringRot, ringBend, frontLen, flat, K.mix(K.mix(NAVY, C.accent, teal), PALE, pale),
                         plain ? 1 : 1 - K.seg(t, F1 + 0.03, DONE - 0.03, E.io2), tip: frontRound)
                } else {
                    fold(frontSide, F0)
                }
            }
            // the marks, on the wings' tips as they arrive: the start's, a plan's dot at the goal, and (over the knob) the flag
            K.mark(g, .start, K.seg(t, (passes(0) ?? B1) - 0.07, (passes(0) ?? B1) + 0.15, E.back))
            func pop(_ deg: Double, _ draw: (OpeningPen?) -> Void) {
                let at = passes(deg) ?? F1, s = K.seg(t, at - 0.07, at + 0.15, E.back)
                if s <= 0 { return }
                let q = K.at(DIAL.x, DIAL.y, DIAL.start + deg, R)
                g.save()
                g.translate(q.x, q.y)
                g.scale(s, s)
                draw(g)
                g.restore()
            }
            if let goal = DIAL.goal { pop(goal, K.planDot) }
            // the knot flips into the knob
            let over = K.seg(t, FLIP, FLIP + 0.14)
            if over < 0.4 {
                K.sprite(o, .knot, nx, ny, k: LAND, rot: ringRot, sx: cos(over / 0.4 * Double.pi / 2), anchor: KNOT, edge: 0)
            } else {
                let s = K.lerp(0.5, 1, K.seg(t, FLIP + 0.056, FLIP + 0.22, E.back))
                g.save()
                g.translate(nx, ny)
                g.rotate(NOW * Double.pi / 180)
                g.scale(s * sin((over - 0.4) / 0.6 * Double.pi / 2), s)
                g.rotate(-NOW * Double.pi / 180)
                K.knob(g)
                g.restore()
            }
            if let flag = DIAL.flag { pop(flag, K.flag) }
        }

        // ---- the Now screen comes in round it
        let words = K.seg(t, B0 + 0.18, B0 + 0.5, E.out3)
        K.part(.center, words, 0, scale: K.lerp(0.96, 1, words))
        K.part(.facts, K.seg(t, CARD + 0.25, CARD + 0.48, E.io2), 0)                  // once his hair has left the card
        K.parts(t, CARD + 0.3, gap: 0.06, dur: 0.4, order: [.cap, .buttons, .week, .tabs])
    }
}
