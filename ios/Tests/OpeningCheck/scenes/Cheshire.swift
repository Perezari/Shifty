import Foundation

/// A check of the kit, not an opening of the app's: the mock's reference scene `cheshire` (mock/scenes/cheshire.js)
/// in Swift, line for line, to hold the kit's icon, man, sprite, ribbon and marks against the mock's
/// (`python tools/compare.py cheshire`). Written for the mock's own shift alone: it knows nothing of other days.
///
/// Only the mustache stays. The icon rises into the dial's place and becomes its round face, the man in it; he opens
/// his eyes and wags his mustache; then he fades away part by part and the mustache alone hangs in the empty dial,
/// grins once more, leaps onto the ring and stretches along it into the shift's arc.
struct CheshireCheck: OpeningScene {
    let id = "cheshire"
    let name = "רק השפם"
    let about = "מר משמרת עולה אל השעון, פוקח עיניים ומנענע את השפם. אז הוא נעלם חלק אחרי חלק, ורק השפם נשאר באוויר."
    let rest = 2.85
    let end = 4.5
    let haptics = [OpeningHaptic(1.7, .light), OpeningHaptic(2.04, .light)]
    let poster = 1.36

    func draw(_ t: Double, _ K: OpeningKit) {
        let E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, C = K.C, g = K.g, o = K.o
        let FACE = DIAL.r - DIAL.w / 2                              // the dial's face: the ring's inner edge, 149
        let MID = DIAL.start + DIAL.now / 2                         // the middle of the shift's arc, on the ring
        let (mx, my) = K.at(DIAL.x, DIAL.y, MID, DIAL.r)

        // ---- the icon rises to the dial's middle and grows into its face, its corners rounding into a circle
        let rise = K.spring(t, 0.12, 0.7, 0.8)
        let size = K.lerp(LAUNCH.size, FACE * 2, rise)
        let box = K.box(LAUNCH.x, K.lerp(LAUNCH.y, DIAL.y, rise), size, K.lerp(LAUNCH.r, size / 2, K.seg(t, 0.16, 0.56, E.io2)))

        // ---- the man's hello
        let open = K.seg(t, 0.54, 0.66, E.io2) - K.seg(t, 1.14, 1.22, E.io2)              // the eyes open, and close before he goes
        let lift = K.spring(t, 0.54, 0.3, 0.5) - K.seg(t, 0.96, 1.1, E.io2)               // the brows
        let wagOn = K.seg(t, 0.68, 0.72) - K.seg(t, 0.9, 0.96)                            // the mustache see-saws twice
        let wag = 13 * sin((t - 0.68) / 0.24 * 2 * Double.pi) * wagOn
        // its tips up: a grin
        let curl = 16 * (K.spring(t, 0.92, 0.26, 0.5) - K.seg(t, 1.32, 1.42, E.io2)) + 5 * K.wobble(t, 1.26, 0.16, 9)
        // ---- he goes, from the outside in; the mustache stays
        func gone(_ a: Double, _ b: Double) -> Double { 1 - K.seg(t, a, b, E.out2) }
        let leap = t >= 1.42

        // ---- the dial under it all: its track from the moment the face is round, then all that the mustache brings
        func wave(_ i: Int) -> Double {
            let d = abs((Double(i * 6) - MID + 540).truncatingRemainder(dividingBy: 360) - 180) / 180
            return K.seg(t, 1.72 + d * 0.34, 1.72 + d * 0.34 + 0.24, E.back)
        }
        let landed = t >= 2.3                                       // from here the dial's own arc stands for the ribbon
        K.dial(track: K.seg(t, 0.4, 0.7), numerals: K.seg(t, 1.9, 2.15), span: landed ? DIAL.now : 0,
               ahead: K.seg(t, 2.04, 2.28), marks: [0, 0, 0], tick: { i in OpeningDialTick(k: wave(i), a: min(1, wave(i) * 2)) })

        // ---- the face and the man
        if t < 1.32 {
            K.icon(o, box, ground: OpeningGround(alpha: gone(1.04, 1.3), hairline: 1 - K.seg(t, 0.16, 0.5)),
                   pose: OpeningPose(
                       body: OpeningMove(alpha: gone(1.0, 1.14)),
                       head: OpeningMove(rot: -4 * (K.seg(t, 0.54, 0.7, E.io2) - K.seg(t, 0.7, 0.96, E.io2)), alpha: gone(1.06, 1.22)),
                       brows: OpeningMove(dy: -6 * lift - 2.5 * abs(wag) / 13, alpha: gone(1.14, 1.26)),
                       eyes: OpeningMove(alpha: gone(1.2, 1.3), open: open),
                       stache: OpeningMove(dy: -1.5 * curl / 16, rot: wag, split: curl),
                       bow: OpeningMove(alpha: gone(1.0, 1.14))),
                   tick: { _, _ in OpeningLogoTick(a: gone(1.0, 1.12), out: -9 * K.seg(t, 1.0, 1.12, E.in2)) })
        } else if !leap {
            // the mustache alone, hanging where his face was: it lifts a little and its tips flick once more
            K.man(o, box, OpeningPose(head: OpeningMove(alpha: 0),
                                      stache: OpeningMove(dy: -1.5 * curl / 16 - 3 * K.seg(t, 1.3, 1.42, E.io2), split: curl),
                                      hide: [.body, .bow, .brows, .eyes]))
        }

        // ---- the leap: a crouch, a flight in an arc to the ring, turning to lie along it; then it stretches along the ring
        if leap && !landed {
            let k = box.k, (sx0, sy0) = box.pt(K.stache.middle.x, K.stache.middle.y - 3)
            let crouch = K.seg(t, 1.42, 1.5, E.out2) - K.seg(t, 1.5, 1.6, E.io2)
            let fly = K.seg(t, 1.5, 1.7, E.io3)
            let x = K.lerp(sx0, mx, fly) - 26 * sin(Double.pi * fly), y = K.lerp(sy0, my, fly) - 10 * sin(Double.pi * fly)
            let dir = K.lerp(0, MID - 360, K.seg(t, 1.5, 1.68, E.io2))                    // to the ring's direction at the arc's middle
            let bend = K.seg(t, 1.58, 1.7, E.io2) / DIAL.r
            let along = 1 + 0.1 * crouch + 0.14 * sin(Double.pi * fly)                    // squash, then stretch in flight
            let flat = K.seg(t, 1.66, 1.92, E.io2)                                        // its outline into the ring's even band
            let reach = K.spring(t, 1.7, 0.52, 0.8)                                       // its tips race apart to the arc's two ends
            let length = K.lerp(K.stache.length * k * along, DIAL.now * Double.pi / 180 * DIAL.r, reach)
            let thin = 1 - 0.2 * crouch
            let color = K.mix(K.stache.color, C.accent, K.seg(t, 1.72, 1.98, E.io2))
            // the picture of the mustache gives way to its shape as it takes off
            let drawn = K.seg(t, 1.44, 1.56)
            K.ribbon(fly < 1 ? o : g, x: x, y: y, dir: dir, length: length, bend: bend,
                     top: { u in K.lerp(K.stache.top(u) * k * thin, DIAL.w / 2, flat) },
                     bottom: { u in K.lerp(K.stache.bottom(u) * k * thin, DIAL.w / 2, flat) }, fill: color, alpha: 1, n: 72)
            if drawn < 1 {
                K.sprite(o, .stache, x, y, k: k, rot: dir, sx: along, sy: thin, alpha: 1 - drawn, anchor: K.stache.middle)
            }
        }

        // ---- the marks, over the ribbon's ends: the start mark where its tail stops, the knob on its leading tip
        K.mark(g, .start, K.seg(t, 1.98, 2.2, E.back))
        K.mark(g, .knob, K.seg(t, 2.04, 2.28, E.back))
        K.mark(g, .flag, K.seg(t, 2.2, 2.44, E.back))

        // ---- the Now screen comes in round the dial
        let words = K.seg(t, 1.78, 2.08, E.out3)
        K.part(.center, words, 0, scale: K.lerp(0.96, 1, words))
        K.parts(t, 1.96, gap: 0.07, dur: 0.42, order: [.cap, .facts, .buttons, .week, .tabs])
    }
}
