import Foundation

/// Mr. Now. The icon was the dial's "now" knob all along, seen from very close. The plate rounds into a white disc,
/// the logo's nine ticks leave the man for its edge and close into a rim in the knob's color (the knob, 6.75 times
/// its size), and the man in it opens his eyes and winks; the dial's ring shows under him as a broad road; then ONE
/// camera pull-back shows the whole dial, with him riding it at this very minute. As the knob gets small his round
/// portrait draws in to the disc's middle and is the knob's dot. The dial is never built: it is the world the knob
/// was sitting on. Plate = disc, ticks = rim, man = dot.
///
/// Every dial has a knob, so it plays the same whatever the day is: he rides the last 30 degrees to now over
/// whatever is there (time worked, a break, the bare track with no shift running), and what lies ahead of him, if
/// anything does, runs out from him once the dial has landed. The flag then pops at its place: under him as a part
/// of the dial, but over him on a day that has it standing on the knob or beside it, as the app's dial lays the two.
struct MrNowOpening: OpeningScene {
    let id = "mrnow"
    let name = "מר עכשיו"
    let about = "האייקון מתעגל לעיגול עם טבעת בצבע האפליקציה, ומר משמרת קורץ. המצלמה מתרחקת, ומתברר שהעיגול הוא הסמן של עכשיו על השעון."
    let rest = 2.3
    let end = 3.8
    let haptics = [OpeningHaptic(1.42, .light)]
    let poster = 0.95

    func draw(_ t: Double, _ K: OpeningKit) {
        let E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, C = K.C, g = K.g, o = K.o
        if t <= 0.12 {                                              // the launch picture, still
            K.launch()
            return
        }
        let NOW = DIAL.start + DIAL.now                             // the knob's angle, clockwise from 12
        let A0 = NOW - 30                                           // where he rides from
        let Z0 = 216.0 / 32                                         // the giant knob against the real one: 6.75
        let T = 0.86                                                // the camera lets go
        let L = T + 0.56                                            // the landing: the dial first reaches its own size
        let S = T + 1.2                                             // and stands still
        func sind(_ d: Double) -> Double { sin(d * Double.pi / 180) }
        func cosd(_ d: Double) -> Double { cos(d * Double.pi / 180) }

        // ---- the plate grows into the giant knob (a spring, a little over and back), its corner rounding into a circle
        var grow = K.spring(t, 0.15, 0.5, 0.7)
        grow += (1 - grow) * K.seg(t, 0.6, 0.84, E.io2)
        let breath = K.seg(t, 0.12, 0.17, E.io2) * (1 - K.seg(t, 0.17, 0.26, E.io2))   // it draws in a little first
        let round = K.seg(t, 0.15, 0.4, E.io2)

        // ---- the camera. At the zoom Z0 the dial's middle is far off the screen, so that the knob, 30 degrees before
        //      "now" on the ring, stands at the launch icon's place. The pull-back is a zoom about one fixed point of the
        //      screen (the dial's middle goes straight to its place as the zoom falls), and ONE spring drives it and the
        //      knob's ride along the ring to "now": it comes in a touch small and settles.
        let far: OpeningPoint = (LAUNCH.x - Z0 * DIAL.r * sind(A0), LAUNCH.y + Z0 * DIAL.r * cosd(A0))
        let focus: OpeningPoint = ((Z0 * DIAL.x - far.x) / (Z0 - 1), (Z0 * DIAL.y - far.y) / (Z0 - 1))
        var p = K.spring(t, T, 0.84, 0.8)
        p += (1 - p) * K.seg(t, S - 0.24, S, E.io2)
        let push = K.seg(t, T - 0.12, T, E.io2) * (1 - K.seg(t, T, T + 0.14, E.io2))   // a breath in before it
        let still = t >= S
        let cam = pow(Z0, -p) * (1 + 0.03 * push)
        let zd = still ? 1 : Z0 * cam                               // the dial's zoom
        // the knob's: the plate's own growth, then the dial's
        let z = still ? 1 : K.lerp(LAUNCH.size, 216, grow) * (1 - 0.035 * breath) / 32 * cam
        let a = still ? NOW : K.lerp(A0, NOW, p)
        let cx = still ? DIAL.x : focus.x + zd * (DIAL.x - focus.x), cy = still ? DIAL.y : focus.y + zd * (DIAL.y - focus.y)
        let kx = cx + zd * DIAL.r * sind(a), ky = cy - zd * DIAL.r * cosd(a)
        let behind = a - DIAL.start                                 // the knob's place, counted from the arc's start

        // ---- the dial: the road under the knob, then all of it, then the finished Now screen's
        let sweep = K.seg(t, L, L + 0.34, E.io2)                    // what lies ahead, from the knob to its end
        let flag = K.seg(t, L + 0.28, L + 0.52, E.back)
        // The dial lays the flag over the knob wherever the two meet (K.dial: the knob, then the flag), and the knob
        // here is on the pen over the dial's. So on a day whose flag stands on the knob or beside it (a plan come
        // due this minute, the goal reached a moment ago) the flag pops on the knob's pen, after him: it grows over
        // him, and what stands there in the end is what K.dial draws from then on. "Beside" is less than 56 points
        // between the two marks' middles on the finished dial: at 56 the flag's halo at the top of its pop (24) and
        // the knob's shadow (27 below him) are still apart. Further off the two never meet, and the flag pops on
        // the dial's own pen, as the rest of the dial.
        var onKnob = false
        if let stands = DIAL.flag { onKnob = 2 * DIAL.r * abs(sind((stands - DIAL.now) / 2)) < 56 }
        // a mark of the dial's, popping with the flag at its place on the dial as the camera has it
        func pop(_ ctx: OpeningPen, _ deg: Double, _ draw: (OpeningPen?) -> Void) {
            let f = K.at(cx, cy, DIAL.start + deg, DIAL.r * zd)
            ctx.save()
            ctx.translate(f.x, f.y)
            ctx.scale(zd * flag, zd * flag)
            draw(ctx)
            ctx.restore()
        }
        if still {
            K.dial()
        } else if t > 0.59 {
            // the road: the ring at the knob's zoom, shown by a round opening that spreads from under the disc to the
            // screen's corners (a soft start, hidden under the disc, then an even pace): the band comes out of him both
            // ways as one, its front parallel to his rim, and the ticks come up as the opening passes them
            func pace(_ u: Double) -> Double { (u < 0.25 ? 2 * u * u : u - 0.125) / 0.875 }
            let road = t < T, wipe = 96 + 400 * K.seg(t, 0.59, T - 0.02, pace)
            // (the band's own ends, 26 degrees either way, are far beyond the screen: the dial's own band takes over unseen)
            if road {
                g.save()
                g.clip(.circle(kx, ky, wipe))
                // the bare track ahead of him; behind him too, where no time worked covers it
                let from = K.covered(from: behind - 26, to: behind) ? a : a - 26
                g.save()
                g.translate(cx, cy)
                g.scale(zd, zd)
                g.stroke(.arc(0, 0, DIAL.r, K.rad(from), K.rad(a + 26)), C.track, width: DIAL.w, cap: .butt)
                g.restore()
            }
            K.dial(cx: cx, cy: cy, k: zd, track: road ? 0 : 1, numerals: 1, span: road ? 0 : behind, ahead: 0,
                   marks: [1, 0, 0], tick: road ? { i in
                       // the tick's distance from the knob
                       let d = Double(i * 6) - a, away = zd * hypot(DIAL.r - 138 * cosd(d), 138 * sind(d))
                       let k = E.back(K.clamp((wipe - away) / 70))
                       return OpeningDialTick(k: k, a: min(1, k * 2))
                   } : nil)
            if road {
                K.worked(g, from: behind - 26, to: behind, cx: cx, cy: cy, k: zd)
                g.restore()
            }
            if sweep > 0 {
                K.ahead(g, from: behind, to: K.lerp(behind, max(DIAL.end, DIAL.now), sweep), cx: cx, cy: cy, k: zd)
            }
            if flag > 0, let goal = DIAL.goal, let stands = DIAL.flag {
                pop(g, goal, K.planDot)                             // a plan's dot at the goal: under the knob, always
                if !onKnob { pop(g, stands, K.flag) }
            }
        }

        // ---- the knob: the icon's plate, then the giant knob, then the real one
        if !still {
            let R = 16 * z, size = 2 * R
            let box = K.box(kx, ky, size, K.lerp(LAUNCH.r / LAUNCH.size, 0.5, round) * size)
            let isDisc = round >= 1
            let shade = K.seg(t, 0.2, 0.5, E.io2), white = K.seg(t, 0.14, 0.4), hair = 1 - K.seg(t, 0.14, 0.4)
            let pulse = 1 + 0.3 * (K.seg(t, L - 0.02, L + 0.08, E.out2) - K.seg(t, L + 0.08, L + 0.3, E.io2))
            // the knob's color, for its rim and its dot: one that reads on the white disc until, at the end, it is
            // the app's knob's own (the two are one color, but for a knob with no shift running in the dark look)
            let ink = K.mix(K.onWhite(K.knobColor), K.knobColor, K.seg(t, S - 0.3, S, E.io2))
            func outline(_ inset: Double) -> OpeningPath {
                isDisc ? .circle(kx, ky, max(0, R - inset)) : K.path(box, inset)
            }

            // the plate: the icon's ground going white, the knob's own disc
            o.save()
            if shade > 0 { o.shadow(OpeningColor(0, 0, 0, 0.22 * shade), radius: 7 * z, dx: 0, dy: 4 * z) }
            if isDisc {
                o.fill(outline(0), OpeningColor.white)
            } else {
                o.fill(outline(0), .linear(x0: 0, y0: box.y, x1: 0, y1: box.y + box.size, stops: [
                    OpeningStop(0, K.mix(C.groundTop, .white, white)), OpeningStop(1, K.mix(C.groundBottom, .white, white)),
                ]))
            }
            o.restore()
            if hair > 0 && C.hairline.a > 0 {
                o.stroke(outline(1.1 * box.k), C.hairline.faded(hair), width: 2.2 * box.k)
            }

            // the man: a round portrait, a little smaller in the disc, to sit inside the rim. As the disc gets small
            // (70 to 38 points across) the portrait draws in to the disc's middle and takes the knob's color: it is
            // the knob's dot
            let fit = K.seg(t, 0.14, 0.5, E.io2), thick = K.seg(t, 0.26, 0.5, E.io2)
            let q = K.clamp((2.2 - z) / (2.2 - 1.18)), f = K.lerp(1, 4.5 / 13, E.io2(q))
            let mbox = K.box(kx, ky - 14 * fit * box.k * f, size * K.lerp(1, 0.8, fit) * f)
            let open = K.seg(t, 0.3, 0.42, E.io2), lift = K.spring(t, 0.3, 0.3, 0.5)
            let wink = K.seg(t, 0.48, 0.54, E.io2) - K.seg(t, 0.6, 0.67, E.io2)          // once the rim has closed
            let look = K.seg(t, 0.65, 0.77, E.io2)                  // a glance down the road
            let level = K.seg(t, 0.28, 0.5, E.io2), lean = K.seg(t, 0.66, 0.86, E.io2)
            let shut = K.seg(t, T - 0.03, T + 0.07, E.io2)          // his eyes shut in the rush: the logo's own smile
            let drag = K.seg(t, T, T + 0.1, E.out2) - K.seg(t, T + 0.1, T + 0.34, E.io2) // and his head left a little behind
            if q < 1 {
                o.save()
                o.clip(q > 0 ? .circle(kx, ky, 13 * z * f) : outline(3 * z * thick))
                K.man(o, mbox, OpeningPose(
                    // (the lean is the whole man's: more than 5 degrees at the neck shows its cut; on the ride he banks into the curve)
                    all: OpeningMove(dy: 5 * push, rot: 4 * lean + 6 * min(1, p)),
                    head: OpeningMove(dy: 2 * level, rot: 5 * level - 2 * wink - 7 * drag),
                    brows: OpeningMove(dy: -6 * lift * (1 - shut) + 3 * shut),
                    browL: OpeningMove(dy: 6 * wink),
                    eyes: OpeningMove(dx: 2.5 * look * (1 - shut), dy: 1.2 * look * (1 - shut)),
                    eyeL: OpeningMove(open: open * (1 - wink) * (1 - shut)), eyeR: OpeningMove(open: open * (1 - shut)),
                    stache: OpeningMove(rot: 5 * wink, split: 5 * wink + 3 * shut),
                    // it arrives a beat after him, and flutters in the rush
                    bow: OpeningMove(rot: 5 * K.wobble(t, 0.2, 0.24, 8) + 12 * K.wobble(t, T + 0.02, 0.15, 6))))
                o.restore()
            }
            if q > 0 {
                o.save()
                o.alpha = E.io2(K.clamp((q - 0.2) / 0.8))
                o.fill(.circle(kx, ky, 13 * z * f * pulse), ink)
                o.restore()
            }

            // the rim: the logo's nine ticks go out to the plate's edge, taking the knob's color, and spread along it
            // until they close into a ring (from the top down both sides; it closes at the bottom), which thickens to
            // the knob's own. It lies inside the disc's edge; as the knob comes down to its own size it moves out to
            // where the app's knob has its ring, astride the edge
            let rim = K.lerp(17 * mbox.k, K.KNOB.width * z, thick)
            let rho = R - rim / 2 + (K.KNOB.ring - (K.KNOB.r - K.KNOB.width / 2)) * z * E.io2(q)
            if t >= 0.5 {
                o.stroke(.circle(kx, ky, max(0, rho)), ink, width: rim, cap: .round)
            } else {
                for (i, tk) in K.TICKS.enumerated() {
                    let from = 0.19 + min(tk.hour, 360 - tk.hour) / 30 * 0.012, land = from + 0.13, fly = K.seg(t, from, land, E.io2)
                    let th = atan2(tk.cx - 256, 256 - tk.cy), s = K.tickOnScreen(mbox, i)
                    var line = OpeningPath()
                    if fly < 1 {
                        let x = K.lerp(s.mid.x, kx + rho * sin(th), fly), y = K.lerp(s.mid.y, ky - rho * cos(th), fly)
                        let hx = (s.b.x - s.a.x) / 2 * (1 - fly), hy = (s.b.y - s.a.y) / 2 * (1 - fly)
                        line.move(x - hx, y - hy)
                        line.line(x + hx, y + hy)
                    } else {
                        let half = 0.0005 + 66 * Double.pi / 180 * K.seg(t, land, 0.5, E.io2)
                        line.arc(kx, ky, rho, th - Double.pi / 2 - half, th - Double.pi / 2 + half)
                    }
                    o.stroke(line, K.mix(C.line, ink, fly), width: K.lerp(s.w, rim, fly), cap: .round)
                }
            }

            // the flag of a day that has it on the knob or beside it: over him, as the dial has it
            if flag > 0, onKnob, DIAL.goal != nil, let stands = DIAL.flag { pop(o, stands, K.flag) }
        }

        // ---- the Now screen comes in round the dial: the words in its middle as it comes to rest (held to the dial's own
        //      place and size until it has), the capsule in its place, the rest rising once the dial has landed
        let words = K.seg(t, L - 0.1, L + 0.22, E.out3), cap = K.seg(t, L + 0.06, L + 0.44, E.out3)
        K.part(.center, words, cy - DIAL.y, dx: cx - DIAL.x, scale: K.lerp(0.94, 1, words) * zd)
        K.part(.cap, cap, 10 * (1 - cap))
        K.parts(t, L + 0.1, gap: 0.07, dur: 0.42, order: [.facts, .buttons, .week, .tabs])
    }
}
