import Foundation

/// The ride. The icon's tile closes in round the man into a little medallion (his head and his bow tie; the shirt
/// goes as the tile cuts it away); he hops onto the dial's ring where the shift began and rides it clockwise to this
/// very minute, the worked arc laid behind him and the hours and the shekels counting up with him; he brakes, and
/// the medallion contracts into the "now" knob: the tile is the knob's disc, its rim the knob's rim, his head the
/// knob's dot.
///
/// Every day has a ring to ride and a knob to become. He rides from where the day's arc starts to the knob, and
/// what the dial really has there unrolls behind him: the time worked with its breaks and its overtime, or the
/// day's finished shifts. Where that is a few degrees or nothing (a shift just begun, no shift today, a day off) a
/// ride so short is no ride: he goes a whole lap round first and lays the arc over its last, real part alone; on a
/// day off the day's whole ring unrolls behind him, and with nothing today nothing does. The count runs only with a
/// shift running.
struct RideOpening: OpeningScene {
    let id = "ride"
    let name = "הסיבוב"
    let about = "מר משמרת קופץ על הטבעת ורוכב עליה מתחילת המשמרת ועד הדקה הזאת, והשעות והשקלים נספרים איתו. בסוף הוא מתכווץ לסמן של עכשיו."
    let rest = 2.6
    let end = 4.2
    let haptics = [OpeningHaptic(0.64, .light), OpeningHaptic(1.66, .medium), OpeningHaptic(2.08, .light)]
    let poster = 1.34                                               // on his way, the arc behind him and the count running
    let arrive = 0.64                                               // he lands on the ring

    func draw(_ t: Double, _ K: OpeningKit) {
        let E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, C = K.C, g = K.g, o = K.o
        if t < 0.12 {                                               // the launch picture, still
            K.launch()
            return
        }
        if t >= 2.56 {                                              // the Now screen, whole
            K.dial()
            for id in K.PARTS { K.part(id, 1, 0) }
            return
        }

        // ---- the medallion: a disc of 64 points (twice the knob's), the man in it at 0.7 of the launch picture's
        //      size, the grid point GC (the middle of the logo's ring of ticks) at its middle
        let R = 32.0, MS = 0.7, k0 = LAUNCH.size / 512
        let GC: OpeningPoint = (256, 242)
        let HOME: OpeningPoint = (LAUNCH.x + (GC.x - 256) * k0, LAUNCH.y + (GC.y - 256) * k0)   // where GC is in the launch picture
        // where he lands on the ring: where the day's arc starts (a day with no shift running has no mark there)
        let S = K.at(DIAL.x, DIAL.y, DIAL.start, DIAL.r)
        // the ride: to the knob; a whole lap more when the knob is so near the start that it would be no ride
        let LAP = DIAL.now < 60 ? 360.0 : 0.0
        let RIDE = DIAL.now + LAP, NOW = DIAL.start + RIDE
        // ---- the moments
        let CLOSE = (0.18, 0.42), CROUCH = (0.34, 0.44), HOP = (0.44, 0.64), WIND = (0.72, 0.86)
        let GO = 0.86, BRAKE = 1.64, TURN = 1.9, KNOB = 2.16

        // ---- where he is on the ring: a wind back, the ride (he arrives with speed), and a spring that takes that speed
        let SL = 0.72, KICK = 0.8, PER = 0.32, Z = 0.45             // KICK under 1: he is off at once after the wind back
        func ringAt(_ t: Double) -> Double {
            let u = pow(K.clamp((t - GO) / (BRAKE - GO)), KICK)
            var p = (3 - SL) * u * u + (SL - 2) * u * u * u
            if t > BRAKE {
                let w = 2 * Double.pi / PER, wd = w * (1 - Z * Z).squareRoot(), x = t - BRAKE
                let swing = exp(-Z * w * x) * sin(wd * x) * (1 - K.seg(t, TURN - 0.1, TURN + 0.04))
                p = 1 + SL * KICK / (BRAKE - GO) / wd * swing
            }
            return K.lerp(DIAL.start - 7 * K.seg(t, WIND.0, WIND.1, E.io2), NOW, p)
        }
        // ---- where the medallion's middle is: at home, in the hop's flight, on the ring
        let HOPH = 62.0
        let arriving: OpeningPoint = {           // the way he comes down onto the ring
            let vx = S.x - HOME.x, vy = S.y - HOME.y + 4 * HOPH, n = hypot(vx, vy)
            return (vx / n, vy / n)
        }()
        func place(_ t: Double) -> OpeningPoint {
            if t <= HOP.0 {
                let e = K.seg(t, CLOSE.0, CLOSE.1, E.io2)
                return (K.lerp(LAUNCH.x, HOME.x, e), K.lerp(LAUNCH.y, HOME.y, e))
            }
            if t < HOP.1 {
                let f = pow((t - HOP.0) / (HOP.1 - HOP.0), 1.25)
                return (K.lerp(HOME.x, S.x, f), K.lerp(HOME.y, S.y, f) - HOPH * 4 * f * (1 - f))
            }
            let p = K.at(DIAL.x, DIAL.y, ringAt(t), DIAL.r), b = 4 * K.wobble(t, HOP.1, 0.2, 12)
            return (p.x + arriving.x * b, p.y + arriving.y * b)
        }
        // how far he has ridden, the lap and all (RIDE is 60 degrees at the least: nothing to guard), how much of
        // the ride that is, and how much of the day's arc lies behind him: what he has ridden after the lap
        let ang = ringAt(t), ridden = max(0, ang - DIAL.start), prog = K.clamp(ridden / RIDE)
        let laid = max(0, ridden - LAP)
        let (x, y) = place(t), (xb, yb) = place(t - 0.06), (x1, y1) = place(t - 0.012), (x2, y2) = place(t + 0.012)
        let vx = (x2 - x1) / 0.024, vy = (y2 - y1) / 0.024, speed = hypot(vx, vy)
        func tangent(_ a: Double) -> OpeningPoint {                 // the clockwise way along the ring at a
            (cos(a * Double.pi / 180), sin(a * Double.pi / 180))
        }

        // ---- the dial under him: what the day has behind the knob is laid as he passes it
        func wave(_ i: Int) -> OpeningDialTick {
            let d = (Double(i * 6) - DIAL.start + 720).truncatingRemainder(dividingBy: 360) / 360
            let a = HOP.1 + 0.02 + d * 0.2
            return OpeningDialTick(k: K.seg(t, a, a + 0.18, E.back), a: K.seg(t, a, a + 0.09))
        }
        let started = K.seg(t, GO + 0.04, GO + 0.2, E.back) * (1 + 0.16 * K.wobble(t, GO + 0.17, 0.2, 10))
        K.dial(track: K.seg(t, 0.14, 0.46), numerals: K.seg(t, HOP.1 + 0.1, HOP.1 + 0.45), span: laid, ahead: 0,
               marks: [started, 0, 0], tick: wave)
        // what lies ahead runs on from him to its end, and the flag pops at its end. With no shift running what is
        // "ahead" is the day's own ring (a day off's): it unrolls behind him as he rides his lap
        let run = K.seg(t, TURN + 0.08, TURN + 0.44, E.io2)
        let unrolled = DIAL.goal == nil && LAP > 0 ? min(max(ridden, DIAL.now), DIAL.end) : DIAL.now
        let aheadTo = max(unrolled, K.lerp(DIAL.now, max(DIAL.end, DIAL.now), run))
        if aheadTo > DIAL.now { K.ahead(g, from: DIAL.now, to: aheadTo) }
        // the marks, one over another as K.dial has them: a plan's dot at the goal, the knob, the flag
        func stand(_ deg: Double?, _ s: Double, _ mark: (OpeningPen?) -> Void) {
            guard let deg, s > 0 else { return }
            let p = K.at(DIAL.x, DIAL.y, DIAL.start + deg, DIAL.r)
            g.save()
            g.translate(p.x, p.y)
            g.scale(s, s)
            mark(g)
            g.restore()
        }
        let flag = K.seg(t, TURN + 0.38, TURN + 0.62, E.back)
        stand(DIAL.goal, flag, K.planDot)
        if t >= KNOB { stand(DIAL.now, 1, K.knob) }
        stand(DIAL.flag, flag, K.flag)

        // ---- the words in the dial's middle: pale at nought, then counting with him, and landing with him
        let words = K.seg(t, HOP.1, HOP.1 + 0.24, E.out3)
        K.part(.center, words * K.lerp(0.5, 1, K.seg(t, GO, GO + 0.3)), 0,
               scale: K.lerp(0.96, 1, words) + 0.028 * K.wobble(t, BRAKE, 0.3, 9))
        if t < BRAKE && DIAL.goal != nil { K.count(prog) }          // a count needs a shift running
        // the rest of the screen comes in with the knob, after his last look at us: the capsule from above (clear of
        // the ring), the cards rising
        let cap = K.seg(t, TURN - 0.02, TURN + 0.4, E.out3)
        K.part(.cap, cap, -14 * (1 - cap))
        K.parts(t, TURN + 0.02, gap: 0.07, dur: 0.42, order: [.facts, .buttons, .week, .tabs])

        if t >= KNOB { return }                                     // from here he is the dial's own knob

        // ---- the medallion's shape
        let close = K.seg(t, CLOSE.0, CLOSE.1, E.io2)
        let shrink = K.seg(t, TURN, KNOB - 0.06, E.io2)             // his head into the dot
        let pop = K.seg(t, TURN + 0.03, KNOB - 0.02, E.io3)         // the disc into the knob
        // its size: a little under, and back
        let snap = K.lerp(K.spring(t, TURN + 0.03, 0.26, 0.62), 1, K.seg(t, KNOB - 0.07, KNOB - 0.01))
        let swell = 1.4 * K.seg(t, TURN - 0.08, TURN + 0.03, E.io2) // a breath in before it closes
        let h = K.lerp(K.lerp(60, R, close) + swell, K.KNOB.r, snap)
        let corner = K.lerp(27, h, K.seg(t, 0.16, 0.36, E.io2))
        // he keeps his size until the tile reaches him, then is squeezed with it
        let ms = K.lerp(K.lerp(1, MS, K.seg(t, 0.25, CLOSE.1, E.io2)), 0.1, shrink)
        let k = k0 * ms

        // ---- how he is carried: the head lags behind the disc, he leans into the way, and is thrown on when he brakes
        var lx = (xb - x) * 0.07, ly = (yb - y) * 0.07
        let far = hypot(lx, ly)
        if far > 3.6 {
            lx *= 3.6 / far
            ly *= 3.6 / far
        }
        let windUp = K.seg(t, WIND.0, WIND.1, E.io2) - K.seg(t, GO, GO + 0.1, E.out2)
        let (wx, wy) = tangent(DIAL.start), (nx, ny) = tangent(NOW)
        let thrown = K.wobble(t, BRAKE + 0.01, 0.3, 8)
        lx += -wx * 3 * windUp - nx * 2.5 * thrown
        ly += -wy * 3 * windUp - ny * 2.5 * thrown
        // he leans back to brake
        let brace = K.seg(t, BRAKE - 0.17, BRAKE - 0.05, E.io2) - K.seg(t, BRAKE - 0.03, BRAKE + 0.04, E.out2)
        let lean = K.clamp(-lx * 4, -15, 15) - 10 * brace + 9 * thrown
        let calm = 1 - shrink

        // ---- his face
        let crouch = K.seg(t, CROUCH.0, CROUCH.1 - 0.02, E.out2) - K.seg(t, CROUCH.1 - 0.02, CROUCH.1 + 0.03, E.in2)
        let riding = K.seg(t, GO, GO + 0.12) - K.seg(t, BRAKE - 0.06, BRAKE + 0.02)
        let open = K.seg(t, 0.13, 0.23, E.io2) - K.seg(t, HOP.1 - 0.01, HOP.1 + 0.07, E.io2)
            + K.seg(t, BRAKE - 0.02, BRAKE + 0.07, E.out3)
        let browCrouch = K.seg(t, CROUCH.0, CROUCH.0 + 0.07, E.io2) - K.seg(t, HOP.0 - 0.01, HOP.0 + 0.06, E.io2)
        let browWind = K.seg(t, WIND.0, WIND.1, E.io2) - K.seg(t, GO, GO + 0.12, E.out3)
        let browSwing = 0.3 * K.wobble(t, HOP.1, 0.2, 9) - 0.9 * brace + 0.5 * K.wobble(t, BRAKE, 0.26, 8)
        let brow = K.spring(t, 0.12, 0.3, 0.5) - 1.5 * browCrouch - 1.7 * browWind + browSwing
            - 0.7 * K.seg(t, TURN - 0.1, TURN, E.io2)
        // where the open eyes look: up at the dial, then at the place he will land on; after the ride, on along the
        // ring, then straight out
        let lookX = -2 * K.seg(t, 0.26, 0.36, E.io2) + 4 * K.seg(t, 0.9, 1.1)
            - 2 * K.seg(t, BRAKE + 0.1, TURN - 0.04, E.io2)
        let lookY = -2 * K.seg(t, 0.14, 0.24, E.io2) + 1.5 * K.seg(t, 0.26, 0.36, E.io2) + 0.5 * K.seg(t, 0.9, 1.1)
        let flap = (t - GO) / 0.11 * 2 * Double.pi                  // the wind in his mustache: its halves flap a beat apart
        let splitHop = 12 * (K.seg(t, HOP.0, HOP.0 + 0.08) - K.seg(t, HOP.1 - 0.02, HOP.1 + 0.04))
        let splitRide = (8 + 5 * sin(flap)) * riding + 14 * K.wobble(t, BRAKE, 0.28, 6.5)
        let split = 8 * K.wobble(t, 0.15, 0.2, 9) - 6 * crouch + splitHop + 10 * K.wobble(t, HOP.1, 0.2, 8)
            - 9 * windUp + splitRide
            + 7 * K.seg(t, BRAKE + 0.14, BRAKE + 0.24, E.io2)       // and a last smile, straight at us
        let glance = K.seg(t, 0.14, 0.26, E.io2) - K.seg(t, 0.3, 0.4, E.io2)   // he lifts his face to the dial as he wakes
        // the bow tie goes with the head, over the neck, and swings on a beat after it when he lands and when he brakes
        let bowSwing = 7 * K.wobble(t, HOP.1 + 0.04, 0.2, 9) + 9 * K.wobble(t, BRAKE + 0.05, 0.24, 8)
        // the shirt goes as the tile cuts it away: a medallion shows his head and his bow tie
        let shirt = 1 - K.seg(t, 0.3, 0.42)
        let pose = OpeningPose(
            all: OpeningMove(rot: 0.4 * lean * calm, pivot: GC),
            body: OpeningMove(alpha: shirt),
            head: OpeningMove(dx: 0.6 * lx / k * calm, dy: (0.6 * ly / k + 4 * crouch) * calm,
                              rot: 0.6 * lean * calm - 4 * glance),
            brows: OpeningMove(dy: -7 * brow),
            eyes: OpeningMove(dx: lookX * calm, dy: lookY * calm - 3 * riding, s: 1 + 0.06 * riding,
                              sy: 1 - 0.3 * windUp, open: open),
            stache: OpeningMove(dx: 0.3 * lx / k * calm, dy: (K.clamp(0.2 * ly / k, -2, 3) + 3 * riding) * calm,
                                rot: 5 * cos(flap) * riding * calm, split: split * calm),
            bow: OpeningMove(dx: 0.6 * lx / k * calm, dy: 0.6 * ly / k * calm, rot: (0.5 * lean + bowSwing) * calm))

        // ---- squash and stretch: the crouch (about the disc's bottom), the stretch along his way, the landing, the brake
        var squashes: [(a: Double, sa: Double, sb: Double)] = []
        let along = 0.12 * K.clamp(speed / 1000)
        if along > 0.001 { squashes.append((atan2(vy, vx), 1 + along, 1 - along * 0.6)) }
        let land = K.wobble(t, HOP.1, 0.2, 10)
        if land != 0 { squashes.append((atan2(arriving.y, arriving.x), 1 - 0.16 * land, 1 + 0.1 * land)) }
        let brake = K.wobble(t, BRAKE, 0.28, 9)
        if brake != 0 { squashes.append((atan2(ny, nx), 1 - 0.08 * brake, 1 + 0.05 * brake)) }
        if windUp != 0 { squashes.append((atan2(wy, wx), 1 - 0.08 * windUp, 1 + 0.05 * windUp)) }
        if crouch != 0 { squashes.append((Double.pi / 2, 1 - 0.12 * crouch, 1 + 0.08 * crouch)) }

        // ---- draw him
        let white = K.seg(t, TURN, KNOB - 0.04)
        let rim = K.lerp(2.5 * K.seg(t, 0.25, 0.42, E.out2), K.KNOB.width, pop)
        // how high he is in the hop
        let air = t > HOP.0 && t < HOP.1 ? sin(Double.pi * pow((t - HOP.0) / (HOP.1 - HOP.0), 1.25)) : 0
        let shadeBlur = K.lerp(9, 7, pop) + 6 * air, shadeDown = 4 + 7 * air
        let shadeAlpha = K.lerp(0.24 * K.seg(t, 0.2, 0.4), 0.22, pop) * (1 - 0.35 * air)
        // his rim and at last his dot are in the knob's own color from the first: he is the knob. (With no shift
        // running that is a gray, which in the dark look reads on the dark tile and melts into the disc as it goes
        // white: the app's knob is all but white there)
        let ink = K.knobColor
        o.save()
        o.translate(x, y + h * 0.12 * crouch)
        for s in squashes {
            o.rotate(s.a)
            o.scale(s.sa, s.sb)
            o.rotate(-s.a)
        }
        let frame = K.box(0, 0, h * 2, corner)
        if shadeAlpha > 0 {
            o.save()
            o.shadow(K.mix(C.shade, .black, pop).alpha(shadeAlpha), radius: shadeBlur, dx: 0, dy: shadeDown)
            o.fill(K.path(frame), K.mix(C.groundTop, .white, white))
            o.restore()
        }
        K.ground(o, frame, toward: (.white, white), hairline: 1 - K.seg(t, 0.16, 0.34))
        let dot = K.seg(t, KNOB - 0.09, KNOB - 0.03)
        if dot < 1 {
            o.save()
            o.clip(shrink > 0 ? .circle(0, 0, K.lerp(R, K.KNOB.dot, shrink)) : K.path(frame))
            // a knob's color one sees through (the gray of no shift running) does not hide him as the dot comes
            // over him: there he goes as it comes
            if ink.a < 1 { o.alpha *= 1 - dot }
            if shrink > 0 {
                // his round portrait's ground, which takes the knob's color as it draws in: it is the knob's dot.
                // From white on the light tile, as the mock has it; on the dark tile, which is only then going
                // white, from the tile's own colors as they are
                let dye = E.in2(shrink)
                if C.dark {
                    o.fill(.rect(-R, -R, 2 * R, 2 * R), .linear(x0: 0, y0: frame.y, x1: 0, y1: frame.y + frame.size, stops: [
                        OpeningStop(0, K.mix(K.mix(C.groundTop, .white, white), ink, dye)),
                        OpeningStop(1, K.mix(K.mix(C.groundBottom, .white, white), ink, dye)),
                    ]))
                } else {
                    o.fill(.rect(-R, -R, 2 * R, 2 * R), K.mix(.white, ink, dye))
                }
            }
            let gc: OpeningPoint = (K.lerp(GC.x, 254, shrink), K.lerp(GC.y, 233, shrink))
            // while the tile closes in, he stays where he is
            let off: OpeningPoint = t <= HOP.0 ? (HOME.x - x, HOME.y - y) : (0, 0)
            let box = K.box(off.x + 0.4 * lx * calm + (256 - gc.x) * k, off.y + 0.4 * ly * calm + (256 - gc.y) * k,
                            LAUNCH.size * ms)
            if t < 0.4 {
                K.ticks(o, box) { i, _ in
                    let s = K.seg(t, 0.12 + Double(i) * 0.011, 0.23 + Double(i) * 0.011, E.io2)
                    return s >= 1 ? nil : OpeningLogoTick(len: 1 - s, out: -70 * s)
                }
            }
            if C.edge != nil && shirt > 0 && shirt < 1 {
                // the dark look: under a shirt that fades by itself his edge's white would show through it, a white
                // shirt that then goes at once. So the whole man fades, edge and all, under the man without his
                // shirt, whose own edge grows in where the shirt was behind him (round his neck and his bow tie)
                var whole = pose, rest = pose
                whole.body = OpeningMove()
                whole.alpha = shirt
                rest.hide = [.body]
                rest.edge = K.seg(t, 0.3, 0.34)
                K.man(o, box, whole)
                K.man(o, box, rest)
            } else {
                K.man(o, box, pose)
            }
            o.restore()
        }
        // the rim lies inside the disc's edge, and moves out to where the app's knob has its ring as it becomes it
        let out = (K.KNOB.ring - (K.KNOB.r - K.KNOB.width / 2)) * pop
        if rim > 0 { o.stroke(K.path(frame, rim / 2 - out), ink, width: rim) }
        if dot > 0 {
            o.alpha = dot
            o.fill(.circle(0, 0, K.KNOB.dot), ink)
            o.alpha = 1
        }
        o.restore()
    }
}
