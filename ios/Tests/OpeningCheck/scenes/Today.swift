import Foundation

/// A check of the kit, not an opening of the app's: the mock's scene `today` (mock/scenes/today.js, its picture of
/// what the app plays natively, Views/Opening.swift) in Swift, line for line, to hold the dial's options (the ring
/// wound round and unwinding, the ticks' wave, the marks popping) and a path filled by the even-odd rule against the
/// mock's (`python tools/compare.py today`). Written for the mock's own shift alone. (`check.py` finds a jump in it
/// at 0.6 seconds, where the icon's ring gives way to the dial's: the mock's own, kept as it is.)
struct TodayCheck: OpeningScene {
    let id = "today"
    let name = "היום"
    let about = "האייקון גדל במקומו לעיגול של השעון ונצבע בצבע האפליקציה, הדמות דוהה ונפתח חור באמצע עד שנשארת הטבעת."
    let rest = 2.6
    let end = 4.1
    let haptics = [OpeningHaptic(1.46, .light)]
    let poster = 0.5

    func draw(_ t: Double, _ K: OpeningKit) {
        let u = t / 1.7, E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, C = K.C, o = K.o
        let settled = K.seg(u, 0.66, 1.1, E.out5)                   // the dial, from the screen's middle up to its place
        let cy = K.lerp(LAUNCH.y, DIAL.y, settled), lift = cy - DIAL.y
        let unwind = K.seg(u, 0.38, 0.86, E.io3)
        func pop(_ a: Double) -> Double { max(0, K.seg(u, a, a + 0.18, E.back)) }
        // (the mock's `span: lerp(360, DIAL.now, unwind)`, a ring wound past the day, is `wind` here)
        K.dial(cy: cy, track: K.seg(u, 0.2, 0.38), numerals: K.seg(u, 0.52, 0.74), span: u >= 0.36 ? nil : 0,
               wind: u >= 0.36 ? K.lerp(360, DIAL.now, unwind) : nil, ahead: unwind * K.seg(u, 0.36, 0.5),
               marks: [pop(0.66), pop(0.74), pop(0.82)], tick: { i in
                   let from = 0.3 + Double(i) / 60 * 0.34, k = K.seg(u, from, from + 0.16, E.back)
                   return OpeningDialTick(k: k, a: min(1, k))
               })
        // the icon: a rounded square growing into the dial's circle in the accent, its mark fading, a hole opening in it
        let p = K.seg(u, 0.03, 0.36, E.io3)
        if p < 1 {
            let half = K.lerp(60, DIAL.r + DIAL.w / 2, p), corner = K.lerp(27, half, pow(p, 0.55))
            let hole = (DIAL.r - DIAL.w / 2) * K.seg(u, 0.13, 0.36, E.io3)
            let box = K.box(LAUNCH.x, cy, half * 2, corner)
            var shape = OpeningPath.roundRect(box.x, box.y, box.size, box.size, corner)
            if hole > 0 { shape.arc(box.cx, box.cy, hole, 0, Double.pi * 2) }
            o.fill(shape, .linear(x0: 0, y0: box.y, x1: 0, y1: box.y + box.size, stops: [
                OpeningStop(0, K.mix(C.groundTop, C.accent, p)), OpeningStop(1, K.mix(C.groundBottom, C.accent, p)),
            ]), evenOdd: true)
            K.icon(o, box, ground: nil, content: 1 - K.seg(u, 0.04, 0.17, E.out3))
            o.stroke(.roundRect(box.x + 1.1 * box.k, box.y + 1.1 * box.k, box.size - 2.2 * box.k, box.size - 2.2 * box.k,
                                max(0, corner - 1.1 * box.k)),
                     OpeningColor(0, 0, 0, 0.07 * (1 - p)), width: 2.2 * box.k)
        }
        K.part(.center, K.seg(u, 0.7, 0.98, E.out3), lift)
        func rise(_ id: OpeningScreenPart, _ a: Double) {
            let s = K.seg(u, a, a + 0.34, E.out3)
            K.part(id, s, (1 - s) * 46)
        }
        rise(.cap, 0.85)
        rise(.facts, 0.8)
        rise(.buttons, 0.8)
        rise(.week, 0.85)
        K.part(.tabs, K.seg(u, 0.96, 1.3, E.out3), 0)
    }
}
