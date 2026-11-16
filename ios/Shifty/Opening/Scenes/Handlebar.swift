import Foundation

/// The grand handlebar. The camera closes in on his mustache until its middle lies, level, on the dial's 6 o'clock.
/// He opens his eyes and winds it up; its two tips run out round him along the dial's own circle, each arm swelling
/// from the tip's point to the ring's own band, and meet over his head with a tap: the loop of mustache IS the ring.
/// The hoop rocks once about his lip; from the kiss a glint runs down both sides and the navy gives way, in place, to
/// the day; what is left is his own mustache again, which springs flat on his lip. He leans back into his own tilt
/// and goes down behind the facts card, which rises over him like a counter.
///
/// The mustache is drawn here as a shape (its picture's outline from K.stache, with the picture's own dark line and
/// navy inside) from the moment he winds it up until it is home again; its picture gives way to the shape and takes
/// over from it where the two are the same. The man is on K.g, in front of the dial and behind the Now screen's cards.
///
/// What the glint leaves is the day's own ring, whatever the day is: K.dial's band, cut to the wedge the glints have
/// opened from 12 (the bare track with no shift running, a day off's whole round, a break's pieces), and every mark
/// the day has, each popping as a glint passes it.
///
/// In the dark look the mustache keeps its own navy, as he does, and wears his white edge: the loop is a navy ring
/// edged in white on the dark ground. The edge lies under his head, so on his face the mustache is as on the icon.
/// His own edge is the icon's there, though his shirt is drawn apart from his head: none round the bow tie, and the
/// head's only above the shirt. And his white shirt fades into the dark page before the icon's square cuts it.
struct HandlebarOpening: OpeningScene {
    let id = "handlebar"
    let name = "השפם"
    let about = "מר משמרת מסלסל את השפם, ושני הקצוות צומחים, מקיפים אותו ונפגשים מעל הראש: השפם הוא הטבעת של השעון. הטבעת נדלקת בצבע האפליקציה, והוא יורד אל מאחורי הכרטיס."
    let rest = 2.3
    let end = 3.9
    let haptics = [OpeningHaptic(1.06, .rigid), OpeningHaptic(1.31, .light)]
    /// The two tips about to meet over his head.
    let poster = 0.95
    /// The camera's push has landed and the nine ticks have flown by; he then stands where the launch picture's icon
    /// stood, only larger, until the tips leave at 0.66.
    let arrive = 0.44

    func draw(_ t: Double, _ K: OpeningKit) {
        let E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, C = K.C, P = K.P, g = K.g
        if t <= 0.12 {
            K.launch()
            return
        }
        let PI = Double.pi, R = DIAL.r, HW = DIAL.w / 2
        func rad(_ d: Double) -> Double { d * PI / 180 }
        func sm(_ a: Double, _ b: Double, _ x: Double) -> Double {
            let v = K.clamp((x - a) / (b - a))
            return v * v * (3 - 2 * v)
        }

        let SIZE = 300.0, RHO = 8.5, KE = SIZE / 512                // the icon's size close up; the head's turn that levels the mustache
        let SIX: OpeningPoint = (DIAL.x, DIAL.y + R)                // the ring's 6 o'clock, where the mustache's middle parks
        let SL = K.stache.length, H0 = SL / 2 * KE                  // the mustache's half length on the screen, close up
        let FULL = PI * R - H0                                      // how far each tip runs: from the mustache's end to 12
        let GROW = 0.66, KISS = 1.06, GLINT = 0.32                  // the tips leave; they meet; the glint's run down to 6
        let BACK = KISS + GLINT * (1 - ((H0 / (PI * R)) / 2).squareRoot())   // the moment the loop is his mustache again
        let HANG = GROW + 0.16                                      // from here to BACK the head is dead still and the loop hangs from the ring's own 6 o'clock

        // ---- a point of the head on the icon's grid, the head turned by `a` degrees about the neck (and squashed by `q`)
        func turned(_ p: OpeningPoint, _ a: Double, _ q: Double = 0) -> OpeningPoint {
            let c = cos(rad(a)), s = sin(rad(a))
            let dx = (p.x - P.neck.x) * (1 + q / 2), dy = (p.y - P.neck.y) * (1 - q)
            return (P.neck.x + dx * c - dy * s, P.neck.y + dx * s + dy * c)
        }

        // ---- the camera: one push toward the mustache, its middle coming to rest on the ring's 6 o'clock
        let push = K.lerp(K.spring(t, 0.12, 0.42, 0.8), 1, K.seg(t, 0.44, 0.6, E.io2))
        let m = turned(K.stache.middle, RHO)
        let size = K.lerp(LAUNCH.size, SIZE, push)
        // ---- his exit: a small bow, then straight down behind the card
        let dip = K.seg(t, 1.36, 1.45, E.io2) - K.seg(t, 1.45, 1.52, E.in2)
        let sink = 178 * K.seg(t, 1.47, 1.74, E.in2) - 5 * dip
        let box = K.box(K.lerp(LAUNCH.x, SIX.x - (m.x - 256) * KE, push),
                        K.lerp(LAUNCH.y, SIX.y - (m.y - 256) * KE, push) + sink, size)
        let k = box.k

        // ---- the loop's own clock
        // the tips: off, round, a breath short of each other, and a snap
        let run = 0.93 * K.seg(t, GROW, KISS - 0.06, E.io2) + 0.07 * K.seg(t, KISS - 0.08, KISS, E.in3)
        let glint = E.io2(K.clamp((t - KISS) / GLINT))              // 0 at 12, 1 at 6, down both sides
        let ext = t < KISS ? FULL * run : max(0, FULL - glint * PI * R)   // each tip's way along the ring, in points
        // when the glint passes `deg` from 12
        func passed(_ deg: Double) -> Double {
            KISS + GLINT * (deg <= 90 ? (deg / 360).squareRoot() : 1 - ((1 - deg / 180) / 2).squareRoot())
        }
        // the kiss's wiggle: the hoop rocks once about his lip (the ring's 6 o'clock), the lit part of the dial with it:
        // his mustache only wags where it sits, the top swings about 10 points one way, 5 back, and is still before he
        // moves again
        let wig = 2.6 * K.wobble(t, KISS, 0.3, 5) * sm(KISS, KISS + 0.08, t) * (1 - sm(KISS + 0.24, KISS + 0.3, t))
        func rock() {
            if wig != 0 {
                g.translate(SIX.x, SIX.y)
                g.rotate(rad(wig))
                g.translate(-SIX.x, -SIX.y)
            }
        }

        // ---- the man's acting
        let wind = K.seg(t, 0.5, 0.62, E.io2)                       // he winds it up
        let open = K.seg(t, 0.3, 0.42, E.io2) - 0.45 * (wind - K.seg(t, GROW, GROW + 0.06, E.out2))
            - K.seg(t, KISS, KISS + 0.07, E.out2)
        let brow0 = -6 * K.spring(t, 0.33, 0.3, 0.5) + 5 * (wind - K.seg(t, GROW, GROW + 0.08, E.out3))
        let brow1 = -4 * K.seg(t, GROW, GROW + 0.1, E.out3) + 10 * K.seg(t, KISS, KISS + 0.1, E.io2)
        let brow = brow0 + brow1 - 3 * K.wobble(t, KISS + 0.02, 0.2, 9)
        let look = 2 * K.seg(t, 0.46, 0.6, E.io2) - 5 * K.seg(t, GROW + 0.04, 1.04, E.io2) + 3 * K.seg(t, KISS, KISS + 0.06)
        // he straightens up; and leans back into his own tilt as he goes
        let up = K.seg(t, 0.14, 0.54, E.io2) - 0.7 * K.seg(t, 1.36, 1.5, E.io2)
        // (and counter-sways a little under the rocking hoop, while it hangs from the ring)
        let headRot = RHO * up - 0.4 * wig * (1 - sm(KISS + 0.14, BACK, t))
        // the head gathers with the mustache as he winds up, and springs a little tall as the tips leave
        let spring0 = K.seg(t, GROW - 0.01, GROW + 0.05, E.out2)
        let squash = 0.035 * (wind - spring0) - 0.02 * (spring0 - K.seg(t, GROW + 0.05, HANG, E.io2))
        // the bow tie turns a little with the head (it keeps the neck covered), kicks as the tips leave, and shivers at
        // the kiss
        let kick = K.seg(t, GROW, GROW + 0.07, E.out2) - K.seg(t, GROW + 0.07, GROW + 0.34, E.io2)
        let bowRot = 6 * up + 8 * kick + 3 * K.wobble(t, KISS, 0.2, 9)

        // ---- the facts card, the counter he bows out behind
        // (it comes into sight below his bust, where the page is empty, and is whole before it reaches his shirt)
        let cardUp = t >= 1.9 ? 1 : K.lerp(K.spring(t, 1.28, 0.46, 0.75), 1, K.seg(t, 1.6, 1.9))
        let cardY = K.facts.y + 112 * (1 - cardUp)
        K.part(.facts, K.seg(t, 1.28, 1.33), cardY - K.facts.y)

        // ---- the dial under it all: from the kiss, as far as the glint has come down each side
        if t >= KISS + GLINT + 0.24 {
            K.dial()                                                // all of it has popped by now: the finished dial
        } else if t >= KISS {
            // how far from 12 a place on the ring is, either way round: where a glint passes it
            func from12(_ deg: Double) -> Double {
                let a = deg.truncatingRemainder(dividingBy: 360), b = a < 0 ? a + 360 : a
                return min(b, 360 - b)
            }
            func pop(_ deg: Double, _ d: Double = 0.2) -> Double { K.seg(t, passed(deg), passed(deg) + d, E.back) }
            g.save()
            rock()
            // the ring's band (the track, the day's pieces behind now and ahead), cut to the wedge the glints have
            // opened from 12
            g.save()
            var wedge = OpeningPath()
            wedge.move(DIAL.x, DIAL.y)
            wedge.arc(DIAL.x, DIAL.y, R + 40, K.rad(-glint * 180), K.rad(glint * 180))
            wedge.close()
            g.clip(wedge)
            K.dial(numerals: 0, marks: [0, 0, 0], tick: { _ in OpeningDialTick(k: 0, a: 0) })
            g.restore()
            // the ticks and the marks pop as a glint passes each; the numerals fade in
            let numerals = K.seg(t, KISS + 0.1, KISS + 0.4)
            let tick: (Int) -> OpeningDialTick = { i in
                let d = min(Double(i * 6), 360 - Double(i * 6)), v = K.seg(t, passed(d), passed(d) + 0.18, E.back)
                return OpeningDialTick(k: v, a: min(1, v * 2))
            }
            let started = pop(from12(DIAL.start)), knob = pop(from12(DIAL.start + DIAL.now))
            let flagged = DIAL.flag.map { pop(from12(DIAL.start + $0)) } ?? 0
            if let goal = DIAL.goal, let flag = DIAL.flag, flag != goal {
                // a plan: its dot pops at the goal as a glint passes there, its flag where it stands. The marks one
                // by one, in the order K.dial draws them (the start, the dot, the knob, the flag)
                func mark(_ deg: Double, _ s: Double, _ draw: () -> Void) {
                    if s <= 0 { return }
                    let p = K.at(DIAL.x, DIAL.y, deg, R)
                    g.save()
                    g.translate(p.x, p.y)
                    g.scale(s, s)
                    draw()
                    g.restore()
                }
                mark(DIAL.start, started) { K.startMark(g) }
                mark(DIAL.start + goal, pop(from12(DIAL.start + goal))) { K.planDot(g) }
                K.dial(track: 0, numerals: numerals, span: 0, ahead: 0, marks: [0, knob, 0], tick: tick)
                mark(DIAL.start + flag, flagged) { K.flag(g) }
            } else {
                K.dial(track: 0, numerals: numerals, span: 0, ahead: 0, marks: [started, knob, flagged], tick: tick)
            }
            g.restore()
        }

        // ---- the man, in front of the dial; cut at the card's top edge as it rises over him
        let gone = sink >= 178
        if !gone {
            g.save()
            g.clip(.rect(K.bounds.x, K.bounds.y, K.bounds.w, cardY + 30 - K.bounds.y))
            // the plate melts into the page from its edges inward, and with it the shirt, which is kept only as a bust:
            // the page's color over both, clear round the bow tie and whole from the plate's edges on
            let melt = K.seg(t, 0.12, 0.3, E.io2), plate = 1 - K.seg(t, 0.12, 0.32, E.io2)
            if plate > 0 { K.ground(g, box, alpha: plate, hairline: 1 - K.seg(t, 0.12, 0.17)) }
            K.clip(g, box) { K.man(g, box, OpeningPose(hide: [.head, .bow])) }
            if melt > 0 {
                // (in the dark look a little flatter: the fade is whole before the square's bottom edge, where the
                // mock's leaves a sixth of the shirt, cut straight: white on the dark page shows, on the light it did not)
                let b = box.pt(P.knot.x, P.knot.y + 6), Y = C.dark ? 0.45 : 0.52
                // once the plate is gone, only over the shirt (the dial is above it)
                let from = plate > 0 ? box.y - 2 : box.pt(0, 350).y
                g.save()
                g.alpha = melt
                g.translate(b.x, b.y)
                g.scale(1, Y)
                g.fill(.rect(box.x - 2 - b.x, (from - b.y) / Y, box.size + 4, (box.y + box.size + 2 - from) / Y),
                       .radial(x: 0, y: 0, r0: 96 * k, r1: 215 * k,
                               stops: [OpeningStop(0, C.background.alpha(0)), OpeningStop(1, C.background.alpha(1))]))
                g.restore()
            }
            // the nine ticks fly past the camera
            let fly = K.seg(t, 0.12, 0.44, E.in2), tk = 1 - K.seg(t, 0.16, 0.34)
            if tk > 0 {
                K.ticks(g, K.box(box.cx, box.cy, box.size * K.lerp(1, 3.6, fly))) { _, _ in
                    OpeningLogoTick(a: tk, w: K.lerp(1, 0.55, fly))
                }
            }
            // the mustache: its picture, or the shape that stands in for it
            let shape = K.seg(t, 0.46, 0.54) - K.seg(t, BACK + 0.18, BACK + 0.26)
            // The mustache as a shape: its picture's outline, turned level with the head; bent onto the ring's circle;
            // its two tips running out along that circle. While it is a loop it hangs from the ring's 6 o'clock itself.
            // (Its outline, the point its circle hangs from, and its middle's place on his lip.)
            func traced() -> (outline: OpeningPath, ax: Double, ay: Double, home: OpeningPoint) {
                typealias Edge = [(s: Double, d: Double)]
                let loop = t >= HANG && t <= BACK
                let turn = loop ? RHO : headRot
                let home = box.pt(turned(K.stache.middle, turn, loop ? 0 : squash))
                let ax = loop ? SIX.x : home.x, ay = loop ? SIX.y : home.y
                // its curl: wound up to two and a half times the ring's, let go onto the ring's own; home again it
                // springs flat, a touch past and back
                let bend = 2.5 * K.seg(t, 0.5, 0.63, E.io2) - 1.5 * K.seg(t, 0.63, 0.74, E.out3) - K.spring(t, BACK + 0.01, 0.18, 0.45)
                let squeeze = 1 - 0.12 * (K.seg(t, 0.5, 0.63, E.io2) - K.spring(t, GROW - 0.02, 0.2, 0.5))
                // as he winds it up its tips round and thicken a little, ready to run; and go back when it is home
                let even = K.seg(t, 0.55, 0.67, E.io2) - K.seg(t, BACK, BACK + 0.08, E.io2)
                // first its curled tips straighten to points, then the points fatten
                let slim = K.clamp(even / 0.6), fat = K.clamp((even - 0.4) / 0.6)
                // the tips' half thickness then; the way over which an arm swells from it to the ring's band
                let NECK = 4.5, SWELL = 64.0
                // the leading bulb against its arm; even with it from the kiss on
                let plump = K.lerp(1.16, 1, K.seg(t, KISS - 0.02, KISS + 0.03))
                let kap = bend / R, flat = abs(kap) < 1e-6
                func at(_ s: Double, _ d: Double) -> OpeningPoint {
                    if flat { return (ax + s, ay + d) }
                    return (ax + (1 / kap + d) * sin(kap * s), ay - 1 / kap + (1 / kap + d) * cos(kap * s))
                }
                // its two edges, each from the left end to the right, as (s, d): s along the line from the middle, d
                // across it
                let c = cos(rad(turn)), sn = sin(rad(turn)), N = 64
                var top: Edge = [], bot: Edge = []
                for i in 0...N {
                    let u = Double(i) / Double(N), x = (u - 0.5) * SL
                    for (upper, y, side) in [(true, -K.stache.top(u), -1.0), (false, K.stache.bottom(u), 1.0)] {
                        var s = (x * c - y * sn) * k, d = (x * sn + y * c) * k
                        d = K.lerp(d, side * K.lerp(1.6, NECK, fat), sm(0.82, 1, abs(s) / H0) * slim)
                        if i == 0 || i == N { s = K.lerp(s, (s > 0 ? 1.0 : s < 0 ? -1.0 : 0.0) * H0, even) }
                        if upper { top.append((s * squeeze, d)) } else { bot.append((s * squeeze, d)) }
                    }
                }
                // each end: an arm along the line, swelling from the tip's thickness to the ring's band, and the round
                // bulb that leads it; once the two bulbs touch at 12 they are one
                var closed = false
                if even > 0 {
                    for sign in [1.0, -1.0] {
                        let a = top[sign < 0 ? 0 : top.count - 1], b = bot[sign < 0 ? 0 : bot.count - 1]
                        let s0 = abs(a.s + b.s) / 2, mid0 = (a.d + b.d) / 2, h0 = max(0.01, (b.d - a.d) / 2)
                        func midAt(_ x: Double) -> Double { K.lerp(mid0, 0, sm(0, SWELL, x)) }
                        func halfAt(_ x: Double) -> Double { K.lerp(h0, HW, sm(0, SWELL, x)) }
                        let mid = midAt(ext), h = halfAt(ext), r = h * K.lerp(1, plump, fat)
                        // the bulb's middle; its way to 12
                        let th1 = PI - asin(min(1, h / r)), pc = s0 + ext - r * cos(th1), gap = PI * R - pc
                        closed = gap < r
                        let th0 = closed ? min(th1, acos(K.clamp(gap / r, -1, 1))) : 0
                        let n = max(1, Int((ext / 4).rounded(.up)))
                        for side in [-1.0, 1.0] {
                            var more: Edge = []
                            for j in 1...n {
                                let x = ext * Double(j) / Double(n)
                                more.append((sign * (s0 + x), midAt(x) + side * halfAt(x)))
                            }
                            for j in stride(from: 9, through: 0, by: -1) {
                                let th = K.lerp(th0, th1, Double(j) / 10)
                                more.append((sign * (pc + r * cos(th)), mid + side * r * sin(th)))
                            }
                            if side < 0 {
                                if sign > 0 { top.append(contentsOf: more) } else { top.insert(contentsOf: more.reversed(), at: 0) }
                            } else {
                                if sign > 0 { bot.append(contentsOf: more) } else { bot.insert(contentsOf: more.reversed(), at: 0) }
                            }
                        }
                    }
                }
                var outline = OpeningPath()
                let lines: [Edge] = closed ? [bot, top.reversed()] : [top + bot.reversed()]
                for line in lines {
                    for (i, q) in line.enumerated() {
                        let p = at(q.s, q.d)
                        if i == 0 { outline.move(p.x, p.y) } else { outline.line(p.x, p.y) }
                    }
                    outline.close()
                }
                return (outline, ax, ay, home)
            }
            let made = shape > 0 ? traced() : nil
            // In the dark look the shape wears the man's white edge, as his own navy does. The edge lies under his
            // head, as the icon's lies under all of him: on his face the mustache shows it only where it stands out
            // of his outline, and the loop has it all the way round him
            if let made, C.edge != nil {
                g.save()
                rock()
                K.edged(g, C.edgeShare * box.size) { g.fill(made.outline, K.stache.color) }
                g.restore()
            }
            var pose = OpeningPose(
                head: OpeningMove(rot: headRot, sx: 1 + squash / 2, sy: 1 - squash),
                brows: OpeningMove(dy: brow), eyes: OpeningMove(dy: look, open: open),
                stache: OpeningMove(alpha: shape > 0 ? 0 : 1), bow: OpeningMove(rot: bowRot), hide: [.body])
            if C.edge != nil {
                // In the dark look the icon's edge lies under all of him, and here his shirt is drawn apart, under his
                // head: an edge round the bow tie, or round the head where it stands on the shirt, would lie over the
                // shirt and cut the shoulders' lines short of the bow tie (a white wedge beside a wing, which the
                // launch picture does not have). So the bow tie has no edge, and the head has its own only above the
                // shirt: with its edge it is cut to above the shirt's upper outline, where the shirt's own edge goes
                // on, and below that it is drawn without one (the two cuts overlap by a hair)
                pose.hide = [.body, .bow]
                // the shirt's upper outline on the icon's grid, from left to right (its picture's, OpeningRig's body)
                let shirt: [OpeningPoint] = [
                    (96, 404.5), (112, 397.5), (128, 391), (144, 385.5), (160, 381), (176, 377.5), (184, 369.5),
                    (192, 363), (208, 357.5), (320, 364.5), (336, 372), (344, 379.5), (352, 383.5), (368, 388),
                    (384, 393.5), (400, 400), (416, 407.5), (432, 416),
                ]
                let rise = 0.8, lap = 2.0                           // the cut's height over that outline, and the overlap (the grid's units)
                // the screen above that outline raised by `up`, or below it
                func side(_ up: Double, above: Bool) -> OpeningPath {
                    let b = K.bounds, far = above ? b.y : b.y + b.h
                    var p = OpeningPath()
                    p.move(b.x, far)
                    p.line(b.x, box.pt(shirt[0].x, shirt[0].y - up).y)
                    for q in shirt { p.line(box.pt(q.x, q.y - up)) }
                    p.line(b.x + b.w, box.pt(shirt[shirt.count - 1].x, shirt[shirt.count - 1].y - up).y)
                    p.line(b.x + b.w, far)
                    p.close()
                    return p
                }
                g.save()
                g.clip(side(rise, above: true))
                K.man(g, box, pose)
                g.restore()
                pose.edge = 0
                g.save()
                g.clip(side(rise + lap, above: false))
                K.man(g, box, pose)
                g.restore()
                K.man(g, box, OpeningPose(bow: OpeningMove(rot: bowRot), hide: [.body, .head], edge: 0))
            } else {
                K.man(g, box, pose)
            }

            if let made {
                let outline = made.outline, ax = made.ax, ay = made.ay, home = made.home
                // drawn as his mustache is drawn: the dark line round it, a little heavier below, and the navy inside
                g.save()
                rock()
                g.fill(outline, .radial(x: ax, y: ay - R, r0: R - 15, r1: R + 21, stops: [
                    OpeningStop(0, OpeningColor(hex: 0x1B3064)), OpeningStop(1, OpeningColor(hex: 0x0E214C)),
                ]))
                g.clip(outline)
                g.translate(0, -1.2 * k / KE)
                g.stroke(outline, OpeningColor(hex: 0x02132F), width: 10 * k / KE, join: .round)
                g.restore()
                // the glint on the loop's two receding ends: on the navy's very end, where the day begins. The left one
                // goes out as it comes to his hair (white over the navy hair is a smudge), the right one at his
                // mustache's tip
                let spark = K.seg(t, KISS - 0.01, KISS + 0.03) - K.seg(t, BACK - 0.07, BACK + 0.01), down = glint * 180
                g.save()
                rock()
                if spark > 0 {
                    for sign in [-1.0, 1.0] {
                        let a = spark * (sign < 0 ? 1 - sm(116, 130, down) : 1)
                        if a <= 0 { continue }
                        let p = K.at(DIAL.x, DIAL.y, sign * max(0, down - 3.4), R)
                        g.fill(.circle(p.x, p.y, 13), .radial(x: p.x, y: p.y, r0: 0, r1: 13, stops: [
                            OpeningStop(0, OpeningColor(255, 255, 255, a)), OpeningStop(0.3, OpeningColor(255, 255, 255, 0.6 * a)),
                            OpeningStop(1, OpeningColor(255, 255, 255, 0)),
                        ]))
                    }
                }
                g.restore()
                // its picture gives way to the shape, and takes over from it again (with no edge of its own in the dark
                // look: the shape's, under his head, is the edge of both)
                if shape < 1 {
                    K.sprite(g, .stache, home.x, home.y, k: k, rot: headRot, alpha: 1 - shape, anchor: K.stache.middle,
                             edge: 0)
                }
            }
            g.restore()
        }

        // ---- the Now screen comes in round the dial
        let words = K.seg(t, 1.56, 1.86, E.out3)
        K.part(.center, words, 0, scale: K.lerp(0.94, 1, words))
        K.parts(t, 1.56, gap: 0.07, dur: 0.42, order: [.cap, .buttons, .week, .tabs])
    }
}
