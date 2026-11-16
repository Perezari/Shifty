import Foundation

/// The monocle. A close-up on his face: he opens one eye and cocks the eyebrow above it; the eyebrow slides down
/// round the eye and closes into a monocle; a glint crosses the monocle, and it grows and is the dial's ring, the
/// clock already in its lens. The logo's nine ticks are drawn round that very eye, so at the close-up they stand on
/// the dial's hour ticks. One stroke the whole way: an arc over the eye, a circle round it, the ring round the clock.
///
/// It plays the same whatever the day is: the rim grows in the app's accent and then every stretch of it takes the
/// color the day's ring has there (the track, what lies ahead, the pieces behind now: `ring`), so that the dial's
/// own ring takes over from it unseen; the marks the day has pop on it. In the dark look the stroke is his own ink
/// while it lies on his face, and the glint leaves the rim in the logo's line color, which reads on the dark lens.
struct MonocleOpening: OpeningScene {
    let id = "monocle"
    let name = "המונוקל"
    let about = "הגבה שלו יורדת ונסגרת סביב העין למונוקל. העדשה גדלה עד שהמסגרת שלה היא הטבעת של השעון, והקווים של הלוגו נעשים שנתות השעות."
    let rest = 2.35
    let end = 3.8
    let haptics = [OpeningHaptic(0.84, .rigid), OpeningHaptic(1.47, .light)]
    // the closed monocle on his face. A small picture of a scene is its two canvases alone, with none of the Now
    // screen's words: once the lens has opened it would be an empty disc over his eye
    let poster = 1.0
    let arrive = 0.5

    /// A color between two, each part as it comes (the mock's `blend`: rounded only when it is drawn, by `whole`).
    private func blend(_ a: OpeningColor, _ b: OpeningColor, _ k: Double) -> OpeningColor {
        OpeningColor(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, a.a + (b.a - a.a) * k)
    }

    /// What a color, clear as it may be, looks like over a solid one: a solid color.
    private func over(_ c: OpeningColor, _ base: OpeningColor) -> OpeningColor {
        OpeningColor(base.r + (c.r - base.r) * c.a, base.g + (c.g - base.g) * c.a, base.b + (c.b - base.b) * c.a)
    }

    /// The day's ring as the finished dial shows it, in stretches of one solid color each (degrees from the
    /// layout's start): the track on the app's background is `track`; over it the pieces ahead of now, and over
    /// those the pieces behind it. In the order K.dial draws them, what lies ahead first, so that their ends meet
    /// as the dial's do. Stretches that touch and share a color are one.
    private func ring(_ K: OpeningKit, _ track: OpeningColor) -> [(from: Double, to: Double, color: OpeningColor)] {
        let all = K.layout.pieces.filter { $0.ahead && $0.to > $0.from } + K.layout.pieces.filter { !$0.ahead && $0.to > $0.from }
        var out: [(from: Double, to: Double, color: OpeningColor)] = []
        for (n, piece) in all.enumerated() {
            // the piece in the stretches the others cut it into; each is this piece's to draw where it is the topmost
            var cuts = [piece.from, piece.to]
            for other in all {
                for edge in [other.from, other.to] where edge > piece.from && edge < piece.to { cuts.append(edge) }
            }
            cuts.sort()
            for (a, b) in zip(cuts, cuts.dropFirst()) where b > a {
                let mid = (a + b) / 2
                var color = track, top = n
                for (m, other) in all.enumerated() where other.from <= mid && mid < other.to {
                    color = over(other.color, color)
                    top = m
                }
                if top != n { continue }
                if let last = out.last, last.to == a, last.color == color {
                    out[out.count - 1].to = b
                } else {
                    out.append((a, b, color))
                }
            }
        }
        return out
    }

    func draw(_ t: Double, _ K: OpeningKit) {
        let E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, TC = K.TC, P = K.P, C = K.C, g = K.g, o = K.o
        let OUT = DIAL.r + DIAL.w / 2                               // the dial's outer circle, 171
        let HOUR = K.tick(true)                                     // the dial's hour tick: its middle 137.5 from the dial's
        let KEND = HOUR.mid / TC.r                                  // the close-up's size: the logo's ticks on the dial's hour ticks
        let INK = OpeningColor(2, 19, 49)                           // the drawing's own line
        // the eyebrow as a stroke on the icon's grid: an arc about (253, 239) with round ends; and the monocle it becomes
        let BROW = (x: 253.0, y: 239.0, r: 33.7, w: 12.8, a0: -69.0, a1: 23.0)
        let MONO = (r: 20 / KEND, w: 6 / KEND)
        // the moments: the monocle closes; the glint sets off; the lens begins to grow; the dial itself takes over from the rim
        let CLICK = 0.84, GLINT = 1.06, GROW = 1.16, LAND = 1.87

        // ---- the close-up: the tile grows and rises until the ticks' circle (and the eye in its middle) is the dial's
        let cam = K.lerp(K.spring(t, 0.12, 0.5, 0.85), 1, K.seg(t, 0.66, 0.82))
        let box = K.box(LAUNCH.x, K.lerp(LAUNCH.y, DIAL.y - (TC.y - 256) * KEND, cam), K.lerp(LAUNCH.size, 512 * KEND, cam))
        let half = K.lerp(LAUNCH.size / 2, OUT, cam)
        let frame = K.box(LAUNCH.x, K.lerp(LAUNCH.y, DIAL.y, cam), half * 2,
                          half * K.lerp(LAUNCH.r / (LAUNCH.size / 2), 1, K.seg(t, 0.16, 0.5, E.io2)))
        // the logo's nine ticks stand within two degrees of their hours: during the move each is set exactly on its own
        let set = K.seg(t, 0.16, 0.5, E.io2)
        func onHour(_ i: Int, _ tk: OpeningRig.Tick) -> OpeningLogoTick? {
            if set == 0 { return OpeningLogoTick() }
            let h = tk.hour * Double.pi / 180, lies = atan2(tk.x2 - tk.x1, tk.y1 - tk.y2) * 180 / Double.pi
            let turn = ((tk.hour - lies + 90).truncatingRemainder(dividingBy: 180) + 180).truncatingRemainder(dividingBy: 180) - 90
            return OpeningLogoTick(dx: (TC.x + TC.r * sin(h) - tk.cx) * set, dy: (TC.y - TC.r * cos(h) - tk.cy) * set, rot: turn * set)
        }

        // ---- his acting
        // the click: his head leans up into the monocle as it comes down, gives as it closes, and returns
        let lean = K.seg(t, 0.7, CLICK - 0.005, E.io2), hit = K.seg(t, CLICK - 0.005, CLICK + 0.075, E.out2)
        let give = hit - K.seg(t, CLICK + 0.075, CLICK + 0.17, E.io2)
        // his head lags a little as the camera sets off, rocks back as it arrives, and settles; the bow tie a beat after it
        let lag = 2.2 * (K.seg(t, 0.14, 0.24, E.io2) - K.seg(t, 0.24, 0.36, E.io2))
        let rock = 3 * (K.seg(t, 0.32, 0.44, E.io2) - K.spring(t, 0.44, 0.36, 0.55)) * (1 - K.seg(t, 0.66, 0.72))
        let headRot = lag - rock + 0.9 * lean * (1 - hit) - 0.7 * give
        let bowRot = 5 * K.wobble(t, 0.34, 0.28, 8) * (1 - K.seg(t, 0.72, 0.82))
        // the eye opens while his head is still settling; the brow above it cocks on a spring, then winds up a little
        let open = K.seg(t, 0.46, 0.59, E.io2)
        let cock = K.spring(t, 0.52, 0.26, 0.55), wind = K.seg(t, 0.64, 0.7, E.io2)
        let brow = (dy: -11 * cock - 3 * wind, rot: 10 * cock + 2 * wind)
        let squeeze = K.seg(t, 0.52, 0.66, E.io2)
        // the pen `o` set to the icon's grid on his head, as K.man places it
        func onHead() {
            o.translate(box.x, box.y)
            o.scale(box.k, box.k)
            o.translate(P.neck.x, P.neck.y)
            o.rotate(headRot * Double.pi / 180)
            o.translate(-P.neck.x, -P.neck.y)
        }

        // ---- the stroke: the cocked eyebrow, sliding down onto the eye while its ends run on round it
        let th = brow.rot * Double.pi / 180, bx = BROW.x - P.browL.x, by = BROW.y - P.browL.y
        let from: OpeningPoint = (P.browL.x + bx * cos(th) - by * sin(th), P.browL.y + brow.dy + bx * sin(th) + by * cos(th))
        let slide = K.seg(t, 0.7, CLICK, E.io2), run = K.seg(t, 0.7, CLICK, E.in2)
        let snap = K.wobble(t, CLICK, 0.2, 12) * (1 - K.seg(t, 0.92, 0.98))
        let meet = (BROW.a0 + BROW.a1) / 2 + brow.rot + 180
        let stroke = (x: K.lerp(from.x, TC.x, slide), y: K.lerp(from.y, TC.y, slide),
                      r: K.lerp(BROW.r, MONO.r, slide) - 2.2 * snap, w: K.lerp(BROW.w, MONO.w, slide) + 1.2 * snap,
                      a0: K.lerp(BROW.a0 + brow.rot, meet - 360, run), a1: K.lerp(BROW.a1 + brow.rot, meet, run))

        // ---- the monocle grows into the dial's ring: a small dip, then out on a spring (to about 164) and back to 160
        func radius(_ s: Double) -> Double {
            let sprung = 20 - 2 * K.seg(s, GLINT, GROW, E.io2) + 142 * K.spring(s, GROW, 0.56, 0.75)
            return K.lerp(sprung, DIAL.r, K.seg(s, LAND - 0.14, LAND, E.io2))
        }
        func width(_ s: Double) -> Double {
            K.lerp(6, DIAL.w, pow(K.clamp((radius(s) - 20) / 140), 1.15))
        }
        let R = radius(t), W = width(t), landed = t >= LAND
        // the lens reaches the logo's ticks: its inner edge (radius - width / 2) is 124 from the middle. The mock looks
        // for the moment in steps of 0.004 from GROW on and finds the 54th; the growth is the same whatever the day is
        let tTicks = 1.376
        // once the rim has covered his head and the bow tie, what is left outside it (the shirt's hem) lets go; the logo's
        // ticks stay whole until the rim is over them (their caps reach 151). In the dark look the hem is a white shape
        // on the dark ground, far more to let go than the light look's few lines on white: it goes over twice the way,
        // the rim closing over it meanwhile (the round frame ends at 171)
        let leave = 1 - K.seg(R + W / 2, 140, C.dark ? 164 : 153), gone = leave <= 0
        // the rim's ink turns to the accent as it grows; then every stretch of it takes the day's color there
        let toTeal = K.seg(R, 28, 88, E.io2), day = K.seg(R, 84, 150, E.io2)
        // the glint: a band of light crossing the lens from the upper left; its place across the lens, -1 to 1
        let sweep = K.lerp(-1.5, 2.1, K.seg(t, GLINT, GLINT + 0.168))

        // ---- the dial, under it all: its face while the lens grows, then all of it
        func pop(_ a: Double) -> Double { K.seg(t, a, a + 0.24, E.back) }
        let marks = [pop(1.48), pop(1.56), pop(1.64)]
        if landed {
            K.dial(marks: marks)
        } else if t >= GLINT {
            let sprout = K.seg(t, tTicks + 0.02, tTicks + 0.26, E.back), slim = K.seg(t, tTicks, tTicks + 0.26, E.io2)
            let nine = Set(K.TICKS.map { Int($0.hour / 6) })
            K.dial(track: 0, span: 0, ahead: 0, marks: [0, 0, 0], tick: { i in
                nine.contains(i) ? OpeningDialTick(a: slim < 1 ? 0 : 1) : OpeningDialTick(k: sprout, a: min(1, sprout * 2))
            })
            // the logo's nine ticks, seen through the lens: each slims, where it stands, into the dial's hour tick
            if slim < 1 {
                let ink = blend(C.line, C.tickBig, slim).whole
                for tk in K.TICKS {
                    let len = K.lerp(hypot(tk.x2 - tk.x1, tk.y2 - tk.y1) * KEND, HOUR.line, slim)
                    g.stroke(.line(K.at(DIAL.x, DIAL.y, tk.hour, HOUR.mid - len / 2), K.at(DIAL.x, DIAL.y, tk.hour, HOUR.mid + len / 2)),
                             ink, width: K.lerp(tk.w * KEND, HOUR.width, slim), cap: .round)
                }
            }
        }

        // ---- the portrait, cut by the lens once it has opened
        if !gone {
            o.save()
            if t >= GLINT && sweep > -1 {
                // all but the part of the lens the glint has crossed
                var cut = K.bounds.path
                let left = sweep >= 1 ? 0 : acos(sweep), a0 = Double.pi / 4 + left
                cut.move(DIAL.x + R * cos(a0), DIAL.y + R * sin(a0))
                cut.arc(DIAL.x, DIAL.y, R, a0, a0 + 2 * (Double.pi - left))
                cut.close()
                o.clip(cut, evenOdd: true)
            }
            K.ground(o, frame, alpha: leave, hairline: 1)
            o.clip(K.path(frame))
            K.ticks(o, box, onHour)
            o.alpha = leave
            K.man(o, box, OpeningPose(
                head: OpeningMove(rot: headRot),
                browL: OpeningMove(dy: brow.dy, rot: brow.rot, alpha: 1 - K.seg(t, 0.65, 0.69)),
                browR: OpeningMove(dy: 3 * squeeze),
                eyeL: OpeningMove(dx: -1.5 * open, dy: -3.5 * open, open: open),
                eyeR: OpeningMove(sy: K.lerp(1, 0.78, squeeze)),
                // the rim sits on its tip and presses it down
                stache: OpeningMove(rot: -4.5 * K.seg(t, CLICK - 0.01, CLICK + 0.05, E.out2) - 1.2 * give),
                bow: OpeningMove(rot: bowRot)))
            o.alpha = 1
            // the glass in the closed rim: a faint wash and a small highlight
            let glass = K.seg(t, CLICK, CLICK + 0.1, E.out2)
            if glass > 0 {
                o.save()
                onHead()
                o.fill(.circle(TC.x, TC.y, stroke.r), OpeningColor(255, 255, 255, 0.07 * glass))
                o.stroke(.arc(TC.x, TC.y, stroke.r * 0.62, K.rad(-66), K.rad(-66 + 36 * glass)), OpeningColor(255, 255, 255, 0.92),
                         width: 3.4, cap: .round)
                o.restore()
            }
            o.restore()
        }

        // ---- the stroke itself: the eyebrow, the monocle, the ring
        let strokeIn = K.seg(t, 0.62, 0.66)
        if t < GLINT && strokeIn > 0 {
            o.save()
            onHead()
            o.alpha = strokeIn
            let line: OpeningPath = run >= 1 ? .circle(stroke.x, stroke.y, stroke.r)
                : .arc(stroke.x, stroke.y, stroke.r, K.rad(stroke.a0), K.rad(stroke.a1))
            o.stroke(line, INK, width: stroke.w, cap: .round)
            o.restore()
        } else if t >= GLINT && !landed {
            let d = 0.5.squareRoot()
            func along(_ c: Double) -> OpeningPoint { (DIAL.x + d * c * R, DIAL.y + d * c * R) }
            // the glint: a band of white light with a crisp front and a long soft tail; before it the lens shows his eye,
            // and behind it the dial comes out of the light
            if sweep < 2.1 {
                let a = along(sweep - 1.05), b = along(sweep + 0.4)
                o.save()
                o.clip(.circle(DIAL.x, DIAL.y, R))
                o.fill(.rect(DIAL.x - R, DIAL.y - R, 2 * R, 2 * R), .linear(x0: a.x, y0: a.y, x1: b.x, y1: b.y, stops: [
                    OpeningStop(0, OpeningColor(255, 255, 255, 0)), OpeningStop(0.655, OpeningColor(255, 255, 255, 1)),
                    OpeningStop(0.807, OpeningColor(255, 255, 255, 1)), OpeningStop(1, OpeningColor(255, 255, 255, 0)),
                ]))
                o.restore()
            }
            // the rim: ink, then the accent, then the day's own colors: the track, what lies ahead, the pieces behind now.
            // Solid colors, each as the dial's ring looks on the app's background: the portrait is still under its outer half.
            // In the dark look his ink would be lost on the dark lens: there the glint's light leaves the rim in the logo's
            // line color, from its front on
            let lit = C.dark ? C.line : INK
            let live = blend(lit, C.accent, toTeal)
            if C.dark && sweep < 2.1 {
                let a = along(sweep + 0.12), b = along(sweep - 0.1)
                o.stroke(.circle(DIAL.x, DIAL.y, R), .linear(x0: a.x, y0: a.y, x1: b.x, y1: b.y, stops: [
                    OpeningStop(0, blend(INK, C.accent, toTeal).whole), OpeningStop(1, live.whole),
                ]), width: W)
            } else {
                let track = over(C.track, C.background)
                func arc(_ a: Double, _ b: Double, _ color: OpeningColor) {
                    o.stroke(.arc(DIAL.x, DIAL.y, R, K.rad(a), K.rad(b)), color.whole, width: W, cap: .butt)
                }
                arc(0, 360, blend(live, track, day))
                if day > 0 {
                    for piece in ring(K, track) {
                        arc(DIAL.start + piece.from, DIAL.start + min(piece.to, piece.from + 360), blend(live, piece.color, day))
                    }
                }
            }
        }

        // ---- the marks, as the ring lands (over the rim until the dial itself takes over): those the day has, as the
        //      dial draws them, a plan's dot at the goal with the flag
        if !landed {
            func mark(_ s: Double, _ deg: Double, _ draw: (OpeningPen?) -> Void) {
                if s <= 0 { return }
                let p = K.at(DIAL.x, DIAL.y, DIAL.start + deg, R)
                o.save()
                o.translate(p.x, p.y)
                o.scale(s, s)
                draw(o)
                o.restore()
            }
            mark(marks[0], 0, K.startMark)
            if let goal = DIAL.goal { mark(marks[2], goal, K.planDot) }
            mark(marks[1], DIAL.now, K.knob)
            if let flag = DIAL.flag { mark(marks[2], flag, K.flag) }
        }

        // ---- the words in the lens: the clock is in it from the glint on, and grows with it
        if t >= GLINT {
            K.part(.center, 1, 0, scale: landed ? 1 : K.clamp((R - W / 2) / (DIAL.r - DIAL.w / 2), 0, 1.03))
        }
        K.parts(t, 1.5, gap: 0.07, dur: 0.42, order: [.facts, .buttons, .week, .tabs])
        let cap = K.seg(t, 1.52, 1.92, E.out3)                      // the capsule, a short way: it stays clear of the ring
        K.part(.cap, cap, (1 - cap) * 14)
    }
}
