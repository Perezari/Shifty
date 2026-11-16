import Foundation

/// Chapeau. The icon rises into the dial's place and becomes its round face, the man in it. He looks up, knows you,
/// and tips his mustache to you as a gentleman tips his hat: it lifts off his lip, sails to the ring, lands on this
/// very minute and unrolls both ways into the shift: back to the start (the hours done), and pale on to the goal (the
/// hours left). The "now" knob pops where its halves meet, like a nose; a new mustache pops onto his lip; he bows out.
///
/// On another day each half becomes what the dial has on its side of the knob. Back: the pieces behind now, all the
/// way to the start (in the accent as it unrolls; a break's orange, the overtime's gold, and finished shifts'
/// paleness and the gaps between them, come up through it once it has landed). On: the pieces ahead to their end,
/// each stretch in its own piece's color (the time to the goal, a plan's pieces, a day off's whole round). A half
/// with nothing on its side (no goal ahead; nothing worked behind) is reeled into the knob as the mustache it is,
/// and is gone under it. He looks to wherever that day's knob is.
struct ChapeauOpening: OpeningScene {
    let id = "chapeau"
    let name = "שאפו"
    let about = "מר משמרת קד קידה ומסיר את השפם כמו כובע. השפם עף אל הטבעת, נוחת על הדקה הזאת ונפרש לקשת של המשמרת, ולו צץ שפם חדש."
    let rest = 2.4
    let end = 4.0
    let haptics = [OpeningHaptic(0.7, .light), OpeningHaptic(1.12, .medium)]
    let poster = 0.96                                               // the doff: he bows, the mustache off his lip and held out like a hat
    let arrive = 0.6                                                // the rise's spring has come to the dial's middle

    /// His head at a moment: turned by `rot` degrees about `pivot` (the icon's grid), and lowered by `dy`.
    private struct Head {
        var rot: Double
        var dy: Double
        var pivot: OpeningPoint
    }

    /// The mustache in the air, as one shape: its notch at x, y, its line's direction there (degrees: 0 to the
    /// right, clockwise) and bend, its size along and across, and how far its wavy middle line has straightened.
    private struct Flying {
        var x: Double
        var y: Double
        var dir: Double
        var bend: Double
        var kL: Double
        var kT: Double
        var hug: Double
    }

    func draw(_ t: Double, _ K: OpeningKit) {
        let E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, C = K.C, o = K.o
        if t >= 2.36 {                                              // the Now screen, whole
            K.dial()
            for id in K.PARTS { K.part(id, 1, 0) }
            return
        }
        let R = DIAL.r, HALF = DIAL.w / 2, FACE = R - HALF, DEG = 180 / Double.pi
        let NOW = DIAL.start + DIAL.now                             // the knob, clock degrees
        let N = K.markAt(.knob)
        let ST = K.stache, NOTCH = 38.0 / 64                        // where the mustache's two halves meet, along its outline
        let NG: OpeningPoint = (ST.middle.x + (NOTCH - 0.5) * ST.length, ST.middle.y)    // that notch on the icon's grid
        let TIP: OpeningPoint = (ST.middle.x - ST.length / 2, ST.middle.y + 7)           // its left tip
        // the mustache's outline as a wavy middle line and a half thickness: on the ring the middle line straightens onto the ring's
        func stMid(_ u: Double) -> Double { (ST.top(u) - ST.bottom(u)) / 2 }
        func stHalf(_ u: Double) -> Double { (ST.top(u) + ST.bottom(u)) / 2 }
        let HUG = 0.7
        // his head nods forward about the neck and tips back about the jaw's end: so the cut at the neck never shows
        let NECK = K.P.neck, JAW: OpeningPoint = (346, 364)
        let INK = OpeningColor(hex: 0x0A1435)                       // a shadow on his face: dark in both looks

        // ---- the moments
        let T_OFF = 0.66                // the mustache leaves his lip
        let T_FLY = 0.92                // it is let go, up to the ring
        let T_LAND = T_FLY + 0.157      // it touches the ring
        let T_KNOB = 1.1                // the "now" knob pops on its notch, and a new mustache on his lip
        let T_SPLIT = 1.2               // from here its two halves are drawn each on its own (their seam is under the knob)
        let T_UN = 1.27                 // the halves begin to unroll
        let T_ARR = 1.62                // and arrive at the start mark and at the goal
        let T_GONE = 1.86               // the face has melted and the man has left

        // ---- the day on the dial: what each half has to become
        // back, against the clock: the pieces behind now, from the knob to the start. With none, it is reeled into the knob
        let goesBack = DIAL.worked > 0 && DIAL.now > 0
        // on, with the clock: the pieces ahead of now, from the knob to their end. With none, into the knob as well
        let pieces = K.layout.pieces.filter { $0.ahead && $0.to > $0.from }
        let before = pieces.filter { $0.to <= DIAL.now }, ahead = pieces.filter { $0.to > DIAL.now }.sorted { $0.from < $1.from }
        let END = max(DIAL.end, DIAL.now)
        let goesOn = !ahead.isEmpty && END > DIAL.now
        // a half that lands as the very arc the dial draws there is simply the dial's from then on (the mock's way):
        // back, time worked all the way from a start mark; on, pieces one after another from the knob to their end,
        // each stretch of the half in its own piece's color. Any other day's half is cross-faded into the dial's
        let exactBack = goesBack && DIAL.goal != nil && K.covered(from: 0, to: DIAL.now)
        var exactOn = goesOn && before.isEmpty && ahead[0].from == DIAL.now
        for i in ahead.indices.dropFirst() where ahead[i].from != ahead[i - 1].to {
            exactOn = false
        }
        // its round end lands under the flag, or after a whole round under the knob; anywhere else it squares itself
        // in its last moments, to be the arc's own end
        let flagAtEnd = DIAL.flag.map { abs($0 - END) < 0.01 } ?? false
        let onCovered = flagAtEnd || END - DIAL.now >= 359.5

        // ---- the push-in: the icon rises to the dial's middle and grows into its round face
        let rise = K.spring(t, 0.12, 0.7, 0.8)
        let size = K.lerp(LAUNCH.size, FACE * 2, rise)
        let box = K.box(LAUNCH.x, K.lerp(LAUNCH.y, DIAL.y, rise), size, K.lerp(LAUNCH.r, size / 2, K.seg(t, 0.16, 0.56, E.io2)))
        let k0 = box.k

        // ---- the man's acting
        let lag = K.spring(t, 0.12, 0.7, 0.8) - K.spring(t, 0.16, 0.7, 0.52)              // what hangs on him: a beat behind the plate, and past it
        let perk = K.spring(t, T_KNOB + 0.02, 0.32, 0.5)                                  // the new mustache: he comes up
        let out = K.seg(t, 1.38, 1.52, E.io2)                                             // and bows out
        func head(_ tt: Double) -> Head {                                                 // his head up to the new mustache
            let behind = max(0, K.spring(tt, 0.12, 0.7, 0.8) - K.spring(tt, 0.16, 0.7, 0.52))   // it arrives a beat after the body
            let up = K.spring(tt, 0.3, 0.36, 0.5)                                         // and is carried on: chin up, he looks at you
            let bow = K.seg(tt, 0.62, 0.8, E.io2)                                         // the doff's bow
            let back = K.spring(tt, 0.9, 0.42, 0.62)                                      // he straightens as he lets it go
            let rot = -3.5 * up + 10.5 * bow + 1.2 * K.wobble(tt, 0.8, 0.26, 8) - 5.5 * back
            return Head(rot: rot, dy: 60 * behind + 5 * bow - 4 * back, pivot: rot < 0 ? JAW : NECK)
        }
        let h = head(t), headRot = h.rot - 2 * perk + 8 * out
        let H = Head(rot: headRot, dy: h.dy + 4 * out, pivot: headRot < 0 ? JAW : NECK)   // his head now
        let slide = 480 * K.seg(t, 1.48, 1.82, E.in2)                                     // straight down behind the lower rim
        let tall = 0.028 * (K.seg(t, 1.38, 1.48, E.io2) - K.seg(t, 1.48, 1.56, E.io2))    // a little taller before he goes (his shirt stays on the rim)
        let watch = K.seg(t, 0.97, 1.07, E.out2) * (1 - K.seg(t, 1.38, 1.47, E.in2))      // his eyes open after the mustache, up to the ring
        // and follow its tip back over his head (if it goes back)
        let gaze = K.lerp(4, -2.5, goesBack ? K.seg(t, T_UN + 0.03, 1.45, E.io2) : 0)
        // (the glance is the mock's for its knob, at 66 degrees: turned with the knob to wherever this day's is)
        let glance = (NOW - 66).truncatingRemainder(dividingBy: 360) / DEG
        let open = K.seg(t, 0.34, 0.46, E.out2) * (1 - K.seg(t, 0.64, 0.74, E.in2)) + watch
        let browUp = K.spring(t, 0.34, 0.3, 0.5) * (1 - K.seg(t, 0.64, 0.76, E.io2)) + 0.8 * watch
        let grin = K.spring(t, 0.42, 0.24, 0.5) * (1 - K.seg(t, 0.57, 0.65, E.io2))       // the mustache lifts and its tips curl: he knows you
        let fresh = K.seg(t, T_KNOB, T_KNOB + 0.28, E.back)                               // the new mustache on his lip
        // a point of his head, on the icon's grid, with the head turned and lowered as in h
        func onHead(_ p: OpeningPoint, _ h: Head) -> OpeningPoint {
            let a = h.rot / DEG, dx = p.x - h.pivot.x, dz = p.y - h.pivot.y
            return (h.pivot.x + dx * cos(a) - dz * sin(a), h.pivot.y + h.dy + dx * sin(a) + dz * cos(a))
        }

        // ---- the mustache off his lip: lifted by one end like a hat by its brim, held out, then let go up to the ring
        let h0 = head(T_OFF), tip0 = onHead(TIP, h0)
        let wind = K.seg(t, T_FLY - 0.1, T_FLY, E.io2) - K.seg(t, T_FLY, T_FLY + 0.08, E.out2)   // a little back before it goes
        let tilt = K.lerp(h0.rot, -15, K.seg(t, T_OFF, T_OFF + 0.15, E.out2)) - 2 * K.wobble(t, T_OFF + 0.15, 0.24, 8) - 2 * wind
        let up = K.seg(t, T_OFF + 0.03, T_OFF + 0.21, E.back) + 0.05 * K.seg(t, T_OFF + 0.21, T_FLY, E.io2)
        let ta = tilt / DEG, vx = NG.x - TIP.x, vy = NG.y - TIP.y
        let heldX = tip0.x + vx * cos(ta) - vy * sin(ta) + 70 * up - 3 * wind
        let heldY = tip0.y + vx * sin(ta) + vy * cos(ta) + 21 * up + 5 * wind
        let held = box.pt(heldX, heldY)
        let fly = K.spring(t, T_FLY, 0.3, 0.7), arc = t < T_LAND ? sin(Double.pi * fly) : 0
        let turn = K.lerp(K.spring(t, T_FLY + 0.05, 0.26, 0.7), 1, K.seg(t, T_SPLIT - 0.06, T_SPLIT))   // its tail whips round onto the ring
        // (the ring's direction at the knob, by the shorter way round from how it was held)
        let along = NOW - 360 * ((NOW + 15) / 360).rounded()
        let fit = K.seg(t, T_FLY + 0.02, T_FLY + 0.2, E.io2)
        // its size against its size on his lip: laid on the ring it stretches out a little
        let KL = K.lerp(1, 0.92, fit) + 0.5 * K.spring(t, T_LAND, 0.28, 0.62), KT = K.lerp(1, 0.9, fit)
        // how far it still is from the "now" point: all the way while held, then its landing's swing past the ring and back
        let swing = (fly - 1) * (1 - K.seg(t, T_SPLIT, T_SPLIT + 0.12))
        let off: OpeningPoint = ((N.x - held.x) * swing, (N.y - held.y) * swing)
        // the dark look's edge round it, as wide as his own
        let EDGE = C.edgeShare * 512 * k0
        // a smooth closed shape through the points: curves between the middles of its sides
        func shape(_ pts: [OpeningPoint], _ fill: OpeningColor, _ alpha: Double, edge: Double = 0) {
            let n = pts.count
            var p = pts[n - 1], q = pts[0]
            var path = OpeningPath()
            path.move((p.x + q.x) / 2, (p.y + q.y) / 2)
            for i in 0..<n {
                p = pts[i]
                q = pts[(i + 1) % n]
                path.quad(p.x, p.y, (p.x + q.x) / 2, (p.y + q.y) / 2)
            }
            path.close()
            o.save()
            o.alpha *= alpha
            K.edged(o, edge) { o.fill(path, fill) }
            o.restore()
        }

        // ---- its two halves along the ring, from the notch at "now"
        let reach = E.io2(0.9 * K.seg(t, T_UN, T_ARR)) / E.io2(0.9)                       // they arrive still moving
        let L10 = NOTCH * ST.length * k0 * KL, L20 = (1 - NOTCH) * ST.length * k0 * KL
        let L1 = K.lerp(L10, goesBack ? DIAL.now / DEG * R : 0, reach)
        let L2 = K.lerp(L20, goesOn ? (END - DIAL.now) / DEG * R : 0, reach)
        let tipBack = NOW - L1 / R * DEG, tipOn = NOW + L2 / R * DEG                      // where the two tips are, clock degrees

        // ---- the dial's ticks come on just inside each half as its tip passes; the rest after, away from the arc's two ends
        let gate = K.seg(t, T_UN, T_UN + 0.1), late = K.seg(t, T_ARR - 0.04, T_ARR + 0.14)
        let AHEAD = DIAL.start + (goesOn ? END : DIAL.now)          // where the arc ahead ends, clock degrees
        let REST = (DIAL.start + 360 - AHEAD) / 2                   // half of what is left of the ring beyond it
        let tick: (Int) -> OpeningDialTick = { i in
            let th = Double(i * 6), ph = th < DIAL.start ? th + 360 : th
            var k: Double
            if ph <= NOW {
                k = K.clamp((ph - tipBack) / 12 + late)
            } else if ph <= AHEAD {
                k = K.clamp((tipOn - ph) / 12 + late)
            } else {
                let d = REST > 0 ? min(ph - AHEAD, DIAL.start + 360 - ph) / REST : 0
                k = K.seg(t, T_ARR + d * 0.22, T_ARR + d * 0.22 + 0.22)
            }
            k = E.back(k) * gate
            return OpeningDialTick(k: k, a: min(1, k * 2))
        }
        let numerals = K.seg(t, T_UN + 0.12, T_ARR + 0.1)
        let pops = [K.seg(t, T_ARR - 0.02, T_ARR + 0.24, E.back), K.seg(t, T_KNOB, T_KNOB + 0.28, E.back),
                    K.seg(t, T_ARR, T_ARR + 0.26, E.back)]
        let landed = t >= T_ARR + 0.1, gone = t >= T_GONE           // landed: the marks cover the halves' round ends
        // once landed the day's own colors come up through the accent; a half that is not the dial's own arc gives way to it
        let own = K.seg(t, T_ARR + 0.1, T_ARR + 0.36, E.io2)
        // the marks stay over the face, and over a half that is still giving way, which would veil them from above
        let over = !gone || (own < 1 && ((goesBack && !exactBack) || (goesOn && !exactOn)))

        // ---- the mustache in the air: one shape, its notch at m.x, m.y
        let inAir = t >= T_OFF && t < T_SPLIT
        let near = 0.09 * min(1, up) * (1 - fit)                                          // lifted toward you, it is a little larger
        let m = Flying(x: N.x + off.x + 9 * arc, y: N.y + off.y + 3 * arc,
                       dir: K.lerp(tilt, along, turn), bend: K.seg(t, T_FLY + 0.07, T_FLY + 0.2, E.io2) / R,
                       kL: k0 * KL * (1 + near - 0.06 * wind + 0.08 * arc), kT: k0 * KT * (1 + near + 0.05 * wind - 0.05 * arc),
                       hug: HUG * K.seg(t, T_FLY + 0.03, T_FLY + 0.19, E.io2))
        // K.stache's outline along a line through the notch, which may bend (as K.ribbon lays it), its edges smooth
        func whole(_ m: Flying, _ fill: OpeningColor, _ alpha: Double) {
            let L = ST.length * m.kL, th0 = m.dir / DEG, b = m.bend, flat = abs(b) < 1e-6
            var top: [OpeningPoint] = [], bottom: [OpeningPoint] = []
            for i in 0...64 {
                let u = Double(i) / 64, d = (u - NOTCH) * L, th = th0 + b * d
                let x = flat ? m.x + d * cos(th0) : m.x + (sin(th) - sin(th0)) / b
                let y = flat ? m.y + d * sin(th0) : m.y - (cos(th) - cos(th0)) / b
                let wave = stMid(u) * (1 - m.hug) * m.kT, w = stHalf(u) * m.kT
                top.append((x + sin(th) * (wave + w), y - cos(th) * (wave + w)))
                bottom.append((x + sin(th) * (wave - w), y - cos(th) * (wave - w)))
            }
            shape(top + bottom.reversed(), fill, alpha)
        }
        // the mustache itself: its shape, and its picture, which gives way to its shape as it is let go
        func aloft() {
            whole(m, ST.color, 1)
            let drawn = K.seg(t, T_FLY - 0.08, T_FLY + 0.04)
            if drawn < 1 {
                K.sprite(o, .stache, m.x, m.y, k: k0, rot: m.dir, sx: m.kL / k0, sy: m.kT / k0, alpha: 1 - drawn, anchor: NG, edge: 0)
            }
        }

        // ---- the dial under it all
        K.dial(track: K.seg(t, 0.38, 0.6), numerals: gone ? numerals : 0, span: landed ? DIAL.worked : 0,
               tint: own < 1 ? (C.accent, 1 - own) : nil, ahead: landed ? (exactOn ? 1 : own) : 0, marks: over ? [0, 0, 0] : pops,
               tick: gone ? tick : { _ in OpeningDialTick(k: 0, a: 0) })

        // ---- the face and the man; the dial's ticks and numerals over the face's white while it is there
        if !gone {
            K.ground(o, box, alpha: 1 - K.seg(t, 1.5, 1.84, E.io2), hairline: 1 - K.seg(t, 0.16, 0.5))
            K.dial(track: 0, numerals: numerals, span: 0, ahead: 0, marks: [0, 0, 0], ctx: o, tick: tick)
            let gx = gaze * watch, gy = -4 * watch
            // the dark look's edge round the mustache in the air lies under him, as his own edge does: off his lip
            // it is still a part of his silhouette, and white shows only where it stands out of him, never on his face
            if inAir && C.edge != nil {
                K.edged(o, EDGE) { aloft() }
            }
            K.clip(o, box) {
                K.ticks(o, box) { _, _ in
                    OpeningLogoTick(a: 1 - K.seg(t, 0.34, 0.54, E.io2), out: 16 * K.seg(t, 0.3, 0.54, E.in2))
                }
                let bow = -40 * lag + 3 * K.wobble(t, 0.8, 0.22, 9) - 4 * K.wobble(t, T_KNOB + 0.08, 0.2, 9) + 3 * K.wobble(t, 1.5, 0.22, 9)
                K.man(o, box, OpeningPose(
                    all: OpeningMove(dy: slide), body: OpeningMove(sy: 1 + tall),
                    head: OpeningMove(dy: H.dy, rot: H.rot, pivot: H.rot < 0 ? H.pivot : nil),
                    brows: OpeningMove(dy: -6 * browUp),
                    eyes: OpeningMove(dx: gx * cos(glance) - gy * sin(glance), dy: gx * sin(glance) + gy * cos(glance), open: open),
                    stache: t < T_OFF ? OpeningMove(dy: -2.5 * grin, sx: 1 + 0.04 * grin, split: 5 * grin)
                        : OpeningMove(rot: 7 * K.wobble(t, T_KNOB + 0.1, 0.2, 9), s: max(fresh, 0.001)),
                    bow: OpeningMove(rot: bow),
                    hide: t >= T_OFF && fresh <= 0 ? [.stache] : []))
            }
        }

        // ---- the mustache in the air, over him
        if inAir {
            // its shadow on his face, soft, fainter as it rises
            let lifted = K.seg(t, T_OFF, T_OFF + 0.2, E.out2) * (1 - K.seg(t, T_FLY, T_FLY + 0.1))
            if lifted > 0 {
                let lip = box.pt(onHead(NG, H))
                var shade = m
                shade.x = K.lerp(lip.x, m.x, 0.4) + 1
                shade.y = K.lerp(lip.y, m.y, 0.4) + 5
                o.save()
                o.clip(.circle(box.cx, box.cy, box.size / 2))
                o.blur(3)
                whole(shade, INK, 0.2 * lifted)
                o.restore()
            }
            // (the dark look: once it lies on the ring its edge comes over him too, where it meets his shirt at the
            // dial's bottom, as its halves' edges are from the split on)
            K.edged(o, EDGE * K.seg(t, T_LAND, T_SPLIT - 0.02, E.io2)) { aloft() }
        }

        // ---- the mustache becomes the shift: each half a ribbon from the notch, stretching along the ring
        if t >= T_SPLIT && own < 1 {
            let flat = K.seg(t, T_UN + 0.02, T_UN + 0.26, E.io2)                          // its outline into the ring's even band
            let round = K.seg(t, T_UN, T_UN + 0.12, E.io2)                                // each tip rounds, and stays round on its way
            let dye = K.seg(t, T_UN + 0.04, T_ARR - 0.04, E.io2)
            let bare = 1 - K.seg(t, T_UN + 0.04, T_UN + 0.2, E.io2)                       // the dark look's edge goes as the dye comes
            // one half: from the notch along the ring, back against the clock (dirn -1) or on with it (+1), L points long
            // (of L0, its length as it lay: shorter, it has been reeled in at the notch that far), to the outline's end
            // uTip; its tip a round end, which at the start mark is the mark's own disc
            func half(_ dirn: Double, _ L: Double, _ L0: Double, _ uTip: Double, _ fill: OpeningColor, _ alpha: Double,
                      flat: Double, round: Double, edge: Double) {
                let span = dirn * L / R * DEG, n = max(40, Int((L / 2.5).rounded(.up)))
                let reeled = L < L0 ? 1 - L / L0 : 0
                var top: [OpeningPoint] = [], bottom: [OpeningPoint] = [], cap: [OpeningPoint] = []
                func edgeAt(_ v: Double, _ side: Double) -> Double {
                    let u = K.lerp(NOTCH, uTip, reeled + (1 - reeled) * v)
                    return K.lerp((stHalf(u) + side * stMid(u) * (1 - HUG)) * k0 * KT, HALF, flat)
                }
                for i in 0...n {
                    top.append(K.at(DIAL.x, DIAL.y, NOW + span * Double(i) / Double(n), R + edgeAt(Double(i) / Double(n), 1)))
                    bottom.append(K.at(DIAL.x, DIAL.y, NOW + span * Double(i) / Double(n), R - edgeAt(Double(i) / Double(n), -1)))
                }
                let r = (edgeAt(1, 1) + edgeAt(1, -1)) / 2
                let c = K.at(DIAL.x, DIAL.y, NOW + span, R + (edgeAt(1, 1) - edgeAt(1, -1)) / 2), a = K.rad(NOW + span)
                for j in 1..<14 {
                    let f = Double(j) / 14 * Double.pi, across = r * cos(f), along = dirn * r * round * sin(f)
                    cap.append((c.x + across * cos(a) - along * sin(a), c.y + across * sin(a) + along * cos(a)))
                }
                shape(top + cap + bottom.reversed(), fill, alpha, edge: edge)
            }
            // a half the dial's own arc stands for from its landing on; another's gives way to the dial's; one reeled in is gone
            // (its edge, in the dark look, drawn in with its last points: nothing of it shows round the knob)
            let onThere = goesOn ? (exactOn ? (landed ? 0 : 1) : 1 - own) : (L2 > 0.05 ? 1 : 0)
            let backThere = goesBack ? (exactBack ? (landed ? 0 : 1) : 1 - own) : (L1 > 0.05 ? 1 : 0)
            o.save()
            o.translate(off.x, off.y)                                                     // what is left of its landing's swing
            if onThere > 0 {
                if goesOn {                                         // on to the goal: navy into the color ahead, thinning to its paleness
                    let end = onCovered ? round : round * (1 - K.seg(t, T_ARR, T_ARR + 0.1, E.io2))
                    // with more than one piece ahead (a plan), each stretch in its piece's color: the half, cut to
                    // that piece's part of the ring (the first and the last a little beyond, for the half's two ends)
                    let spare = min(20, (360 - (END - DIAL.now)) / 2)
                    for (i, piece) in ahead.enumerated() {
                        o.save()
                        if ahead.count > 1 {
                            let from = DIAL.start + (i == 0 ? DIAL.now - spare : piece.from)
                            let to = DIAL.start + (i == ahead.count - 1 ? piece.to + spare : ahead[i + 1].from)
                            var part = OpeningPath()
                            part.move(DIAL.x, DIAL.y)
                            part.arc(DIAL.x, DIAL.y, R + 40, K.rad(from), K.rad(to))
                            part.close()
                            o.clip(part)
                        }
                        half(1, L2, L20, 1, K.mix(ST.color, piece.color.alpha(1), dye), K.lerp(1, piece.color.a, dye) * onThere,
                             flat: flat, round: end, edge: EDGE * bare)
                        o.restore()
                    }
                } else {
                    half(1, L2, L20, 1, ST.color, 1, flat: 0, round: round, edge: EDGE * min(1, L2 / 16))
                }
            }
            if backThere > 0 {
                if goesBack {                                       // back to the start: navy into the accent
                    // (its round end lands under the start mark; with none, today's finished shifts, it squares itself)
                    let end = DIAL.goal != nil ? round : round * (1 - K.seg(t, T_ARR, T_ARR + 0.1, E.io2))
                    half(-1, L1, L10, 0, K.mix(ST.color, C.accent, dye), backThere, flat: flat, round: end, edge: EDGE * bare)
                } else {
                    half(-1, L1, L10, 0, ST.color, 1, flat: 0, round: round, edge: EDGE * min(1, L1 / 16))
                }
            }
            o.restore()
        }

        // ---- the marks, over the face while it is there: the knob on the notch, the start mark and the flag at the tips' ends
        //      (one over another as K.dial has them, for a day whose marks stand near enough to overlap: the knob over
        //      the start and a plan's dot, the flag over the knob)
        if over {
            func pop(_ at: OpeningPoint, _ s: Double, _ draw: () -> Void) {
                if s <= 0 { return }
                o.save()
                o.translate(at.x, at.y)
                o.scale(s, s)
                draw()
                o.restore()
            }
            K.mark(o, .start, pops[0])
            if let goal = DIAL.goal { pop(K.at(DIAL.x, DIAL.y, DIAL.start + goal, R), pops[2]) { K.planDot(o) } }
            K.mark(o, .knob, pops[1], dx: off.x, dy: off.y)         // in the mustache's notch, settling onto the ring with it
            if DIAL.flag != nil { pop(K.markAt(.flag), pops[2]) { K.flag(o) } }
        }

        // ---- the Now screen comes in round the dial: the words in its middle once his hair has passed them
        let words = K.seg(t, 1.72, 1.98, E.out3)
        K.part(.center, words, -8 * (1 - words))
        K.parts(t, 1.62, gap: 0.07, dur: 0.42, order: [.cap, .facts, .buttons, .week, .tabs])
    }
}
