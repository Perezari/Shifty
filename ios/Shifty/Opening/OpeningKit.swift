import Foundation

// The kit an opening's scene draws with: one for each frame. It holds the frame's two pens (`g` under the Now
// screen's parts, `o` over them), the parts' states, the dial as it will be (the layout), the colors (the theme)
// and the screen's bounds. It is the browser mock's kit (ios/Tests/OpeningCheck/mock/engine.js) in Swift, its
// names kept (K.dial, K.man, K.seg, LAUNCH, DIAL...) so that a scene written there reads the same here.
//
// The design's space: a screen of 402 x 874 points, the dial's middle at 201, 293, its ring's radius 160 and
// width 22; the launch picture's icon at 201, 437, 120 points wide. The app lays this space over the real
// screen, so that the dial here falls on the real dial; the real screen may reach beyond 402 x 874 (`screen`).

/// The easings: each takes how far a move has come in time, from 0 to 1, and gives how far it has come in place.
enum OpeningEase {
    static func lin(_ t: Double) -> Double { t }
    static func in2(_ t: Double) -> Double { t * t }
    static func in3(_ t: Double) -> Double { t * t * t }
    static func out2(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }
    static func out3(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
    static func out4(_ t: Double) -> Double { 1 - pow(1 - t, 4) }
    static func out5(_ t: Double) -> Double { 1 - pow(1 - t, 5) }
    static func io2(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }
    static func io3(_ t: Double) -> Double { t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2 }
    /// Past 1 a little on the way, and back.
    static func back(_ t: Double) -> Double {
        let c = 1.9
        return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)
    }
    /// Back a little first, then on.
    static func backIn(_ t: Double) -> Double {
        let c = 1.9
        return (c + 1) * t * t * t - c * t * t
    }
}

/// The launch picture's icon: its middle on the screen, its side, its corner.
struct OpeningLaunchPlace {
    let x = 201.0
    let y = 437.0
    let size = 120.0
    let r = 27.0
}

/// The Now screen's dial: its middle, its ring's radius and width, and the shift on it (OpeningLayout): where the
/// arc starts (degrees clockwise from 12) and, counted from there, now, where the pieces behind now end, the goal,
/// the flag and the last piece's end.
struct OpeningDialPlace {
    let x = 201.0
    let y = 293.0
    let r = 160.0
    let w = 22.0
    let start: Double
    /// Where the knob stands.
    let now: Double
    /// Where the pieces behind now end: `now` itself while a shift runs.
    let worked: Double
    /// The goal; nil with no shift running: no start mark and no flag then.
    let goal: Double?
    /// Where the flag stands: the goal, or a plan's time to leave. Nil with no goal.
    let flag: Double?
    /// Where the last piece ends: the goal on a shift under way, 360 on a day off, 0 with no pieces.
    let end: Double
}

/// The knob as the app's dial draws it: a white disc of the radius `r`; a ring `width` wide, in the knob's color,
/// whose middle runs `ring` from the knob's middle, along the disc's edge, so that it stands half out of the disc
/// (the mock draws it inside the disc: 14.25); and a dot of the radius `dot`.
struct OpeningKnobShape {
    let r = 16.0
    let ring: Double
    let width = 3.5
    let dot = 4.5
}

/// The icon's square on the screen: its middle, its side and its corner; `k` points to one unit of the icon's
/// grid of 512.
struct OpeningBox {
    let cx: Double
    let cy: Double
    let size: Double
    let r: Double
    let x: Double
    let y: Double
    let k: Double

    /// A point of the icon's grid, on the screen.
    func pt(_ gx: Double, _ gy: Double) -> OpeningPoint {
        (x + gx * k, y + gy * k)
    }

    func pt(_ p: OpeningPoint) -> OpeningPoint {
        pt(p.x, p.y)
    }
}

/// How a part of the man is moved, about its own pivot: `dx`, `dy` in the grid's units, `rot` in degrees
/// clockwise, `s`, `sx`, `sy` its scale, `alpha`; `pivot` another point to move about. `open` is the eyes' alone
/// (0, the logo's smiling arcs, to 1, round eyes) and `split` the mustache's (its halves turned about its middle,
/// in degrees, the tips up).
struct OpeningMove {
    var dx = 0.0
    var dy = 0.0
    var rot = 0.0
    var s = 1.0
    var sx = 1.0
    var sy = 1.0
    var alpha = 1.0
    var pivot: OpeningPoint?
    var open: Double?
    var split = 0.0

    init(dx: Double = 0, dy: Double = 0, rot: Double = 0, s: Double = 1, sx: Double = 1, sy: Double = 1,
         alpha: Double = 1, pivot: OpeningPoint? = nil, open: Double? = nil, split: Double = 0) {
        self.dx = dx
        self.dy = dy
        self.rot = rot
        self.s = s
        self.sx = sx
        self.sy = sy
        self.alpha = alpha
        self.pivot = pivot
        self.open = open
        self.split = split
    }

    /// Nothing moved at all.
    var still: Bool {
        dx == 0 && dy == 0 && rot == 0 && s == 1 && sx == 1 && sy == 1 && alpha == 1 && pivot == nil
            && (open ?? 0) == 0 && split == 0
    }
}

/// The man's parts that can be left out.
enum OpeningManPart {
    case body, head, brows, eyes, stache, bow, wings, knot
}

/// The man's pose: each part moved on its own (K.man).
struct OpeningPose {
    var all: OpeningMove?
    var body: OpeningMove?
    var head: OpeningMove?
    var brows: OpeningMove?
    var browL: OpeningMove?
    var browR: OpeningMove?
    var eyes: OpeningMove?
    var eyeL: OpeningMove?
    var eyeR: OpeningMove?
    var stache: OpeningMove?
    var bow: OpeningMove?
    var wings: OpeningMove?
    var knot: OpeningMove?
    var hide: Set<OpeningManPart> = []
    var alpha = 1.0
    /// The dark look's edge round him: its width's share, from 0 (none) to 1 (the icon's).
    var edge = 1.0

    init(all: OpeningMove? = nil, body: OpeningMove? = nil, head: OpeningMove? = nil, brows: OpeningMove? = nil,
         browL: OpeningMove? = nil, browR: OpeningMove? = nil, eyes: OpeningMove? = nil, eyeL: OpeningMove? = nil,
         eyeR: OpeningMove? = nil, stache: OpeningMove? = nil, bow: OpeningMove? = nil, wings: OpeningMove? = nil,
         knot: OpeningMove? = nil, hide: Set<OpeningManPart> = [], alpha: Double = 1, edge: Double = 1) {
        self.all = all
        self.body = body
        self.head = head
        self.brows = brows
        self.browL = browL
        self.browR = browR
        self.eyes = eyes
        self.eyeL = eyeL
        self.eyeR = eyeR
        self.stache = stache
        self.bow = bow
        self.wings = wings
        self.knot = knot
        self.hide = hide
        self.alpha = alpha
        self.edge = edge
    }
}

/// One of the dial's sixty ticks, as K.dial is told to draw it: its length's share and its alpha.
struct OpeningDialTick {
    var k = 1.0
    var a = 1.0

    init(k: Double = 1, a: Double = 1) {
        self.k = k
        self.a = a
    }
}

/// One of the logo's nine ticks, as K.ticks is told to draw it: its alpha, its length's and width's shares, its
/// color, how far it is moved outward along its ray and by dx, dy (the grid's units), and turned (degrees).
struct OpeningLogoTick {
    var a = 1.0
    var len = 1.0
    var w = 1.0
    var color: OpeningColor?
    var out = 0.0
    var dx = 0.0
    var dy = 0.0
    var rot = 0.0

    init(a: Double = 1, len: Double = 1, w: Double = 1, color: OpeningColor? = nil, out: Double = 0, dx: Double = 0,
         dy: Double = 0, rot: Double = 0) {
        self.a = a
        self.len = len
        self.w = w
        self.color = color
        self.out = out
        self.dx = dx
        self.dy = dy
        self.rot = rot
    }
}

/// The icon's ground, as K.ground is told to draw it: mixed toward a color by a share, its alpha, the faint line
/// inside its edge (0 to 1), and a shadow under it (its radius, how far down, its alpha).
struct OpeningGround {
    var toward: (color: OpeningColor, share: Double)?
    var alpha = 1.0
    var hairline = 1.0
    var shadow: (radius: Double, dy: Double, alpha: Double)?

    init(toward: (color: OpeningColor, share: Double)? = nil, alpha: Double = 1, hairline: Double = 1,
         shadow: (radius: Double, dy: Double, alpha: Double)? = nil) {
        self.toward = toward
        self.alpha = alpha
        self.hairline = hairline
        self.shadow = shadow
    }
}

/// The Now screen's parts, which are the app's own views: the capsule on top, the words in the dial's middle, the
/// card of facts, the buttons, the week's card and the tab bar.
enum OpeningScreenPart: String, CaseIterable {
    case cap, center, facts, buttons, week, tabs
}

/// A part's state in a frame: how much of it is there (its opacity, from 0 to 1), how far it is moved from its
/// place, in the design's points (times the host's scale on the screen), and its scale about its own middle; the
/// move is not scaled. A part a frame does not name is hidden.
struct OpeningPartState: Equatable {
    var shown = 0.0
    var dx = 0.0
    var dy = 0.0
    var scale = 1.0
}

/// How K.dial is told to draw the dial: every option of it, each with the finished dial's value.
struct OpeningDialLook {
    /// Its middle (the dial's own place) and its size.
    var cx: Double?
    var cy: Double?
    var k = 1.0
    /// All of it.
    var alpha = 1.0
    /// The pale track under the ring.
    var track = 1.0
    /// How much of the track and the ticks is drawn, in degrees clockwise from 12.
    var reveal = 360.0
    /// Each of the sixty ticks (the tick i stands at i * 6 degrees); nil: all there.
    var tick: ((Int) -> OpeningDialTick)?
    /// The 12, 3, 6 and 9.
    var numerals = 1.0
    /// How many degrees of the pieces behind now are drawn, from the start; nil: all of them. On a running shift,
    /// more than now's draws the last piece on to there: the arc ends at the knob, wherever a scene has the knob.
    var span: Double?
    /// The ring wound on in the accent past the pieces behind now, to this many degrees from the start (360: the
    /// whole ring); nil: no further than the pieces.
    var wind: Double?
    /// Where those pieces are drawn from, clockwise from 12; nil: the layout's start.
    var from: Double?
    /// A color every piece behind now is mixed toward, and by how much, from 0 to 1.
    var tint: (color: OpeningColor, share: Double)?
    /// The alpha of the pieces ahead of now, and of the part behind now that `span` has not reached yet, which is
    /// drawn pale with them.
    var ahead = 1.0
    /// How far the pieces ahead are drawn, in degrees from the start; nil: to their end.
    var aheadTo: Double?
    /// The size of the start mark, of the knob and of the flag, each from 0 to 1.
    var marks: [Double] = [1, 1, 1]
    /// Where the knob stands, clockwise from 12; nil: at now.
    var knobAt: Double?
    /// The pen; nil: `g`.
    var ctx: OpeningPen?
}

final class OpeningKit {
    /// The design's screen.
    let W = 402.0
    let H = 874.0
    let LAUNCH = OpeningLaunchPlace()
    let DIAL: OpeningDialPlace
    /// The knob's shape, for a scene that draws a knob of its own and hands it over to the dial's.
    let KNOB: OpeningKnobShape
    /// The logo's nine ticks, clockwise from 12, the hour each stands at, and their circle.
    let TICKS = OpeningRig.ticks
    let HOURS = OpeningRig.hours
    let TC = OpeningRig.ticksCircle
    /// The man's points on the icon's grid.
    let P = OpeningRig.points
    /// The colors.
    let C: OpeningTheme
    /// The knob's ring and dot, and the flag: the colors the app's dial gives them in this state.
    let knobColor: OpeningColor
    let flagColor: OpeningColor
    let E = OpeningEase.self
    let PARTS = OpeningScreenPart.allCases

    /// The pen under the Now screen's parts, where the dial belongs, and the pen over them.
    let g = OpeningPen()
    let o = OpeningPen()

    let layout: OpeningLayout
    let theme: OpeningTheme
    /// The real screen, in the design's points: 0, 0, 402, 874 on the iPhone the openings were designed on.
    let screen: OpeningRect
    /// The screen and well beyond it: what a fill or a clip of the whole screen takes.
    let bounds: OpeningRect
    /// The real card of facts, in the design's points: 20, 482, 362, 76 on the iPhone the openings were designed
    /// on; on another it is as wide as that screen lets it be, and as tall as its words are. For a scene whose own
    /// shape becomes the card, or that hides something behind it.
    let facts: OpeningRect
    /// The dial as the browser mock draws it where that is not quite as the app does: its ticks' round caps
    /// beyond their length (the app's are capsules of that length, caps and all), the knob's ring inside its disc
    /// (the app's stands astride the disc's edge). For holding a scene against the mock, picture by picture; the
    /// app never sets it.
    let asMock: Bool

    /// The Now screen's parts in this frame: every one hidden until a scene shows it.
    private(set) var parts: [OpeningScreenPart: OpeningPartState] = [:]
    /// How much of the real time and pay the dial's middle shows, from 0 to 1, as they count up; nil: as they are.
    private(set) var counted: Double?

    init(layout: OpeningLayout, theme: OpeningTheme, screen: OpeningRect = .design, facts: OpeningRect = .facts,
         asMock: Bool = false) {
        self.layout = layout
        self.theme = theme
        self.screen = screen
        self.bounds = screen.grown(120)
        self.facts = facts
        self.asMock = asMock
        C = theme
        knobColor = layout.knob
        KNOB = OpeningKnobShape(ring: asMock ? 14.25 : 16)
        flagColor = layout.flagColor
        DIAL = OpeningDialPlace(start: layout.start, now: layout.now, worked: layout.worked, goal: layout.goal,
                                flag: layout.flagAt, end: layout.end)
    }

    // MARK: - Numbers

    func clamp(_ x: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double {
        min(hi, max(lo, x))
    }

    func lerp(_ a: Double, _ b: Double, _ k: Double) -> Double {
        a + (b - a) * k
    }

    /// How far a move from the moment `a` to the moment `b` has come at `t`, from 0 to 1, on the curve `ease`.
    func seg(_ t: Double, _ a: Double, _ b: Double, _ ease: (Double) -> Double = OpeningEase.lin) -> Double {
        ease(clamp((t - a) / (b - a)))
    }

    /// A spring let go at the moment `a`: from 0 to 1, overshooting and settling. `period` is one swing in
    /// seconds, `damping` from 0 (rings on) to 1 (no overshoot).
    func spring(_ t: Double, _ a: Double, _ period: Double = 0.45, _ damping: Double = 0.45) -> Double {
        let x = t - a
        if x <= 0 { return 0 }
        let w = 2 * Double.pi / period, z = damping
        if z >= 1 { return 1 - exp(-w * x) * (1 + w * x) }
        let wd = w * (1 - z * z).squareRoot()
        return 1 - exp(-z * w * x) * (cos(wd * x) + z * w / wd * sin(wd * x))
    }

    /// A swing that dies away, begun at the moment `a`: 0, then to and fro round 0.
    func wobble(_ t: Double, _ a: Double, _ period: Double = 0.3, _ decay: Double = 6) -> Double {
        t <= a ? 0 : sin((t - a) * 2 * Double.pi / period) * exp(-(t - a) * decay)
    }

    /// The color `k` of the way from `a` to `b`.
    func mix(_ a: OpeningColor, _ b: OpeningColor, _ k: Double) -> OpeningColor {
        a.mixed(b, k)
    }

    /// The color at another alpha.
    func rgba(_ color: OpeningColor, _ alpha: Double) -> OpeningColor {
        color.alpha(alpha)
    }

    /// A color for a line on the knob's white disc, which is white in the dark look too: `color` itself where it
    /// reads there, or the gray that does. (With no shift running the knob is ringed in a gray that is all but
    /// white in the dark look: the app's knob shows it only where the ring stands out of the disc.)
    func onWhite(_ color: OpeningColor) -> OpeningColor {
        func over(_ c: Double) -> Double { c * color.a + 255 * (1 - color.a) }
        let light = 0.299 * over(color.r) + 0.587 * over(color.g) + 0.114 * over(color.b)
        return light > 200 ? OpeningColor(60, 60, 67, 0.6) : color
    }

    /// Degrees clockwise from 12, as a path's radians.
    func rad(_ deg: Double) -> Double {
        (deg - 90) * Double.pi / 180
    }

    /// The point `r` away from x, y toward `deg`, clockwise from 12.
    func at(_ x: Double, _ y: Double, _ deg: Double, _ r: Double) -> OpeningPoint {
        (x + r * cos(rad(deg)), y + r * sin(rad(deg)))
    }

    // MARK: - The dial

    /// A tick of the dial: its line's length between its two ends (its round caps reach half its width beyond
    /// each), its width, and how far from the dial's middle its own middle is. An hour's tick is 9 points long
    /// and 2 wide with its caps, a minute's 4 and 1.5.
    func tick(_ big: Bool) -> (line: Double, width: Double, mid: Double) {
        let width = big ? 2.0 : 1.5, long = big ? 9.0 : 4.0
        return (asMock ? long : long - width, width, DIAL.r - DIAL.w / 2 - (big ? 11.5 : 9))
    }

    /// The two ends of the dial's tick at `deg`, an hour's or a minute's, at `k` of its length, on the screen (or
    /// round cx, cy).
    func tickEnds(_ deg: Double, _ big: Bool, _ k: Double = 1, _ cx: Double? = nil, _ cy: Double? = nil) -> (a: OpeningPoint, b: OpeningPoint) {
        let look = tick(big), len = look.line * k
        let x = cx ?? DIAL.x, y = cy ?? DIAL.y
        return (at(x, y, deg, look.mid - len / 2), at(x, y, deg, look.mid + len / 2))
    }

    /// A stretch of the ring in one color, in degrees.
    private struct Run {
        var from: Double
        var to: Double
        var color: OpeningColor
    }

    /// Runs that touch and share a color, as one.
    private func joined(_ runs: [Run]) -> [Run] {
        var out: [Run] = []
        for run in runs where run.to > run.from {
            if let last = out.last, last.to == run.from, last.color == run.color {
                out[out.count - 1].to = run.to
            } else {
                out.append(run)
            }
        }
        return out
    }

    /// The runs' arcs round the origin, each from `origin` on.
    private func strokeRuns(_ ctx: OpeningPen, _ runs: [Run], _ origin: Double) {
        for run in joined(runs) {
            let a = origin + run.from, b = origin + run.to
            if b <= a { continue }
            ctx.stroke(.arc(0, 0, DIAL.r, rad(a), rad(min(b, a + 360))), run.color, width: DIAL.w, cap: .butt)
        }
    }

    /// The pieces behind now between `from` and `to` (degrees from the start), in their own colors or tinted; and
    /// past them, the ring wound on in the accent to `wind`.
    private func workedRuns(_ from: Double, _ to: Double, _ tint: (color: OpeningColor, share: Double)?,
                            wind: Double? = nil) -> [Run] {
        var runs: [Run] = []
        func color(_ c: OpeningColor) -> OpeningColor {
            guard let tint else { return c }
            return c.mixed(tint.color, tint.share)
        }
        for piece in layout.pieces where !piece.ahead {
            runs.append(Run(from: max(piece.from, from), to: min(piece.to, to), color: color(piece.color)))
        }
        // on a running shift the time worked ends at the knob: asked for beyond now (a knob that overshoots its
        // place), its last piece goes on
        if let last = layout.pieces.last(where: { !$0.ahead }), last.to == layout.now, to > last.to {
            runs.append(Run(from: max(last.to, from), to: to, color: color(last.color)))
        }
        if let wind, wind > layout.worked {
            runs.append(Run(from: max(layout.worked, from), to: wind, color: color(theme.accent)))
        }
        return runs
    }

    /// What lies ahead between `from` and `to` (degrees from the start), at `alpha`: the part behind now that is
    /// not drawn yet, pale, and the pieces ahead in their own colors.
    private func aheadRuns(_ from: Double, _ to: Double, _ alpha: Double) -> [Run] {
        var runs: [Run] = []
        for piece in layout.pieces where !piece.ahead {
            runs.append(Run(from: max(piece.from, from), to: min(piece.to, to), color: piece.color.faded(0.18).faded(alpha)))
        }
        for piece in layout.pieces where piece.ahead {
            runs.append(Run(from: max(piece.from, from), to: min(piece.to, to), color: piece.color.faded(alpha)))
        }
        return runs
    }

    /// The Now screen's dial, as the app draws it; with nothing told, the finished dial of the layout. On `g`
    /// unless told another pen.
    func dial(_ op: OpeningDialLook = OpeningDialLook()) {
        let ctx = op.ctx ?? g, x = op.cx ?? DIAL.x, y = op.cy ?? DIAL.y, k = op.k
        let r = DIAL.r, w = DIAL.w, reveal = op.reveal
        let span = op.span ?? DIAL.worked, from = op.from ?? DIAL.start
        ctx.save()
        ctx.alpha *= op.alpha
        ctx.translate(x, y)
        ctx.scale(k, k)
        if op.track > 0 && reveal > 0 {
            ctx.stroke(.arc(0, 0, r, rad(0), rad(min(reveal, 360))), theme.track.faded(op.track), width: w, cap: .butt)
        }
        for i in 0..<60 {
            if Double(i * 6) > reveal { continue }
            let fx = op.tick?(i), tk = fx?.k ?? 1, ta = fx?.a ?? 1
            if ta <= 0 || tk <= 0 { continue }
            let big = i % 5 == 0
            let ends = tickEnds(Double(i * 6), big, tk, 0, 0)
            ctx.stroke(.line(ends.a, ends.b), (big ? theme.tickBig : theme.tickSmall).faded(ta), width: big ? 2 : 1.5, cap: .round)
        }
        if op.numerals > 0 { ctx.hours(op.numerals) }
        if op.ahead > 0 {
            strokeRuns(ctx, aheadRuns(max(op.wind ?? span, span, 0), op.aheadTo ?? Double.infinity, op.ahead), DIAL.start)
        }
        if span > 0 || (op.wind ?? 0) > 0 {
            strokeRuns(ctx, workedRuns(0, span, op.tint, wind: op.wind), from)
        }
        func pop(_ s: Double, _ deg: Double, _ draw: () -> Void) {
            if s <= 0 { return }
            let p = at(0, 0, deg, r)
            ctx.save()
            ctx.translate(p.x, p.y)
            ctx.scale(s, s)
            draw()
            ctx.restore()
        }
        let marks = op.marks + [1, 1, 1]
        pop(marks[0], DIAL.start) { startMark(ctx) }
        if let goal = DIAL.goal { pop(marks[2], DIAL.start + goal) { planDot(ctx) } }
        pop(marks[1], op.knobAt ?? DIAL.start + DIAL.now) { knob(ctx) }
        if let flag = DIAL.flag { pop(marks[2], DIAL.start + flag) { self.flag(ctx) } }
        ctx.restore()
    }

    /// K.dial with its options by name: `K.dial(cx: 201, k: 2, ahead: 0, marks: [1, 0, 0])`.
    func dial(cx: Double? = nil, cy: Double? = nil, k: Double = 1, alpha: Double = 1, track: Double = 1,
              reveal: Double = 360, numerals: Double = 1, span: Double? = nil, wind: Double? = nil, from: Double? = nil,
              tint: (color: OpeningColor, share: Double)? = nil, ahead: Double = 1, aheadTo: Double? = nil,
              marks: [Double] = [1, 1, 1], knobAt: Double? = nil, ctx: OpeningPen? = nil,
              tick: ((Int) -> OpeningDialTick)? = nil) {
        dial(OpeningDialLook(cx: cx, cy: cy, k: k, alpha: alpha, track: track, reveal: reveal, tick: tick,
                             numerals: numerals, span: span, wind: wind, from: from, tint: tint, ahead: ahead, aheadTo: aheadTo,
                             marks: marks, knobAt: knobAt, ctx: ctx))
    }

    /// The pieces behind now between `from` and `to` (degrees from the layout's start), as K.dial draws them, on
    /// a dial whose middle is at cx, cy and whose size is k: for a scene that shows a part of the ring itself.
    func worked(_ ctx: OpeningPen, from: Double = 0, to: Double, tint: (color: OpeningColor, share: Double)? = nil,
                cx: Double? = nil, cy: Double? = nil, k: Double = 1) {
        ctx.save()
        ctx.translate(cx ?? DIAL.x, cy ?? DIAL.y)
        ctx.scale(k, k)
        strokeRuns(ctx, workedRuns(from, to, tint), DIAL.start)
        ctx.restore()
    }

    /// What lies ahead between `from` and `to` (degrees from the layout's start), as K.dial draws it with `span:
    /// from`: the part behind now not reached yet, pale, and the pieces ahead; on a dial at cx, cy of the size k.
    func ahead(_ ctx: OpeningPen, from: Double, to: Double, alpha: Double = 1, cx: Double? = nil, cy: Double? = nil,
               k: Double = 1) {
        ctx.save()
        ctx.translate(cx ?? DIAL.x, cy ?? DIAL.y)
        ctx.scale(k, k)
        strokeRuns(ctx, aheadRuns(max(from, 0), to, alpha), DIAL.start)
        ctx.restore()
    }

    /// Whether pieces behind now, solid ones, cover all of the ring between `from` and `to` (degrees from the
    /// start): the track under them does not show.
    func covered(from: Double, to: Double) -> Bool {
        var reached = from
        for piece in layout.pieces where !piece.ahead && piece.color.a >= 1 {
            if piece.from <= reached && piece.to > reached { reached = piece.to }
        }
        return reached >= to
    }

    /// The dial's marks, each round the origin of the pen as it is (move and scale it first): where the shift
    /// started (a disc of 22 points) and the goal's flag (42 with its halo), which a dial with no shift running
    /// does not have, and the knob (32).
    func startMark(_ ctx: OpeningPen? = nil) {
        guard DIAL.goal != nil else { return }
        (ctx ?? g).mark(.start)
    }

    func knob(_ ctx: OpeningPen? = nil) {
        (ctx ?? g).mark(.knob)
    }

    func flag(_ ctx: OpeningPen? = nil) {
        guard DIAL.goal != nil else { return }
        (ctx ?? g).mark(.flag)
    }

    /// The small dot a plan leaves at the goal, when the flag has been taken elsewhere, round the origin; nothing
    /// with no plan.
    func planDot(_ ctx: OpeningPen? = nil) {
        guard let goal = DIAL.goal, let flag = DIAL.flag, flag != goal else { return }
        let ctx = ctx ?? g
        ctx.fill(.circle(0, 0, 5), OpeningColor.white)
        ctx.stroke(.circle(0, 0, 5), theme.accent, width: 2.5)
    }

    /// Where a mark stands on the screen. With no shift running the start and the flag, which are not there,
    /// are given the knob's place.
    func markAt(_ which: OpeningDialMark) -> OpeningPoint {
        let deg: Double
        switch which {
        case .start: deg = DIAL.goal == nil ? DIAL.now : 0
        case .knob: deg = DIAL.now
        case .flag: deg = DIAL.flag ?? DIAL.now
        }
        return at(DIAL.x, DIAL.y, DIAL.start + deg, DIAL.r)
    }

    /// A mark at its place on the dial, at the size `s` (nothing at 0 or less), moved by dx, dy; with the flag, a
    /// plan's dot at the goal too.
    func mark(_ ctx: OpeningPen, _ which: OpeningDialMark, _ s: Double, dx: Double = 0, dy: Double = 0) {
        if s <= 0 { return }
        func put(_ p: OpeningPoint, _ draw: () -> Void) {
            ctx.save()
            ctx.translate(p.x + dx, p.y + dy)
            ctx.scale(s, s)
            draw()
            ctx.restore()
        }
        switch which {
        case .start:
            put(markAt(.start)) { startMark(ctx) }
        case .knob:
            put(markAt(.knob)) { knob(ctx) }
        case .flag:
            if let goal = DIAL.goal { put(at(DIAL.x, DIAL.y, DIAL.start + goal, DIAL.r)) { planDot(ctx) } }
            put(markAt(.flag)) { flag(ctx) }
        }
    }

    /// The app's own way of finishing, from the moment T, about 0.9 seconds: the whole ring in the accent unwinds
    /// to the day, the sixty ticks come in as a wave from 12, the marks pop up. `change` may set more of the
    /// dial's look. Nothing before T.
    func settle(_ t: Double, _ T: Double, _ change: ((inout OpeningDialLook) -> Void)? = nil) {
        if t < T { return }
        let unwind = seg(t, T, T + 0.7, E.io3)
        func pop(_ d: Double) -> Double { seg(t, T + d, T + d + 0.26, E.back) }
        var look = OpeningDialLook()
        look.wind = lerp(360, DIAL.worked, unwind)
        look.ahead = unwind
        look.marks = [pop(0.5), pop(0.58), pop(0.66)]
        look.tick = { i in
            let from = T + Double(i) / 60 * 0.45
            return OpeningDialTick(k: self.seg(t, from, from + 0.24, OpeningEase.back), a: self.seg(t, from, from + 0.12))
        }
        change?(&look)
        dial(look)
    }

    // MARK: - The Now screen's parts

    /// One part of the Now screen: how much of it is there (0 to 1), and how far it is moved (points) or scaled.
    func part(_ id: OpeningScreenPart, _ shown: Double, _ dy: Double = 0, dx: Double = 0, scale: Double = 1) {
        parts[id] = OpeningPartState(shown: clamp(shown), dx: dx, dy: dy, scale: scale)
    }

    /// The parts rising one after another from the moment T, as the app brings them: each over `dur` seconds from
    /// `rise` points below, `gap` seconds apart. `order` picks which, and in what order.
    func parts(_ t: Double, _ T: Double, gap: Double = 0.08, dur: Double = 0.45, rise: Double = 46,
               order: [OpeningScreenPart] = OpeningScreenPart.allCases) {
        for (i, id) in order.enumerated() {
            let shown = seg(t, T + Double(i) * gap, T + Double(i) * gap + dur, E.out3)
            part(id, shown, (1 - shown) * rise)
        }
    }

    /// The time and the pay in the dial's middle count up: this frame they show `share` of what they really are,
    /// from 0 to 1. Left alone, they are as they are.
    func count(_ share: Double) {
        counted = clamp(share)
    }

    // MARK: - The icon and the man

    /// The icon's square: its middle on the screen, its side, its corner's radius (the icon's own, 27 to 120, if
    /// left out). With nothing told, the launch picture's.
    func box(_ cx: Double? = nil, _ cy: Double? = nil, _ size: Double? = nil, _ r: Double? = nil) -> OpeningBox {
        let cx = cx ?? LAUNCH.x, cy = cy ?? LAUNCH.y, size = size ?? LAUNCH.size
        return OpeningBox(cx: cx, cy: cy, size: size, r: r ?? size * LAUNCH.r / LAUNCH.size, x: cx - size / 2,
                          y: cy - size / 2, k: size / 512)
    }

    /// The icon's rounded square as a path, `inset` points inside its edge.
    func path(_ box: OpeningBox, _ inset: Double = 0) -> OpeningPath {
        let r = max(0, min(box.r - inset, box.size / 2 - inset))
        return .roundRect(box.x + inset, box.y + inset, box.size - 2 * inset, box.size - 2 * inset, r)
    }

    /// The icon's ground: its top color going to its bottom one downward, as the app's own icon.
    func ground(_ ctx: OpeningPen, _ box: OpeningBox, _ op: OpeningGround = OpeningGround()) {
        let toward = op.toward ?? (theme.accent, 0)
        ctx.save()
        ctx.alpha *= op.alpha
        let fill = OpeningPaint.linear(x0: 0, y0: box.y, x1: 0, y1: box.y + box.size, stops: [
            OpeningStop(0, mix(theme.groundTop, toward.color, toward.share)),
            OpeningStop(1, mix(theme.groundBottom, toward.color, toward.share)),
        ])
        if let shadow = op.shadow {
            ctx.save()
            ctx.shadow(theme.shade.alpha(shadow.alpha), radius: shadow.radius, dx: 0, dy: shadow.dy)
            ctx.fill(path(box), fill)
            ctx.restore()
        } else {
            ctx.fill(path(box), fill)
        }
        if op.hairline > 0 && theme.hairline.a > 0 {
            let inset = 1.1 * box.size / 512
            ctx.stroke(path(box, inset), theme.hairline.faded(op.hairline), width: 2.2 * box.size / 512)
        }
        ctx.restore()
    }

    func ground(_ ctx: OpeningPen, _ box: OpeningBox, toward: (color: OpeningColor, share: Double)? = nil,
                alpha: Double = 1, hairline: Double = 1, shadow: (radius: Double, dy: Double, alpha: Double)? = nil) {
        ground(ctx, box, OpeningGround(toward: toward, alpha: alpha, hairline: hairline, shadow: shadow))
    }

    /// Everything `draw` draws is cut to the icon's rounded square.
    func clip(_ ctx: OpeningPen, _ box: OpeningBox, _ draw: () -> Void) {
        ctx.save()
        ctx.clip(path(box))
        draw()
        ctx.restore()
    }

    /// The logo's nine ticks, in the icon's square, in the logo's line color or `color`. `each` may change every
    /// one (i from 0, clockwise from 12), or hide it with nil. Each tick is drawn at its own alpha, whatever the
    /// pen's was.
    func ticks(_ ctx: OpeningPen, _ box: OpeningBox, color: OpeningColor? = nil,
               _ each: ((Int, OpeningRig.Tick) -> OpeningLogoTick?)? = nil) {
        ctx.save()
        ctx.translate(box.x, box.y)
        ctx.scale(box.k, box.k)
        for (i, tk) in TICKS.enumerated() {
            let f: OpeningLogoTick
            if let each {
                guard let told = each(i, tk) else { continue }
                f = told
            } else {
                f = OpeningLogoTick()
            }
            if f.a <= 0 { continue }
            let far = hypot(tk.cx - TC.x, tk.cy - TC.y)
            let ux = (tk.cx - TC.x) / far, uy = (tk.cy - TC.y) / far
            let half = hypot(tk.x2 - tk.x1, tk.y2 - tk.y1) / 2 * f.len
            let mx = tk.cx + ux * f.out + f.dx, my = tk.cy + uy * f.out + f.dy
            let a = atan2(tk.y2 - tk.y1, tk.x2 - tk.x1) + f.rot * Double.pi / 180
            ctx.alpha = f.a
            ctx.stroke(.line(mx - cos(a) * half, my - sin(a) * half, mx + cos(a) * half, my + sin(a) * half),
                       f.color ?? color ?? theme.line, width: tk.w * f.w, cap: .round)
        }
        ctx.restore()
    }

    /// A tick of the logo on the screen, in the icon's square: its two ends, its width and its middle, in points.
    func tickOnScreen(_ box: OpeningBox, _ i: Int) -> (a: OpeningPoint, b: OpeningPoint, w: Double, mid: OpeningPoint) {
        let tk = TICKS[i]
        return (box.pt(tk.x1, tk.y1), box.pt(tk.x2, tk.y2), tk.w * box.k, box.pt(tk.cx, tk.cy))
    }

    /// In the dark look, what `draw` draws gets the edge round its silhouette that the dark icon's man has, `width`
    /// points wide (the icon's own is `C.edgeShare` of its side); in the light look it is only drawn. K.man and
    /// K.sprite draw through it; a scene's own shape in the man's dark colors may need it too.
    func edged(_ ctx: OpeningPen, _ width: Double, _ draw: () -> Void) {
        if let color = theme.edge, width > 0 {
            ctx.group(edge: OpeningEdge(color: color, width: width), draw)
        } else {
            draw()
        }
    }

    private func moveBy(_ ctx: OpeningPen, _ move: OpeningMove?, _ pivot: OpeningPoint) {
        guard let move else { return }
        let p = move.pivot ?? pivot
        ctx.translate(p.x + move.dx, p.y + move.dy)
        if move.rot != 0 { ctx.rotate(move.rot * Double.pi / 180) }
        ctx.scale(move.sx * move.s, move.sy * move.s)
        ctx.translate(-p.x, -p.y)
    }

    /// One layer's picture in its place, moved about `pivot` (its own middle if left out).
    private func put(_ ctx: OpeningPen, _ name: OpeningPicture, _ move: OpeningMove? = nil, _ pivot: OpeningPoint? = nil) {
        let layer = OpeningRig.layer(name)
        if let move, move.alpha <= 0 { return }
        ctx.save()
        if let move {
            ctx.alpha *= move.alpha
            moveBy(ctx, move, pivot ?? layer.middle)
        }
        ctx.image(name, layer.x, layer.y, layer.w, layer.h)
        ctx.restore()
    }

    /// The man, in the icon's square, each part moved on its own (OpeningPose): `all` the whole man about the
    /// neck, `body` the shirt (the bow tie goes with it), `head` the head with its face about the neck, `brows`
    /// and `eyes` both of each or one alone, `stache` the mustache about its middle, `bow` the bow tie with its
    /// knot about the knot, `wings` and `knot` each alone. With nothing moved it is the launch picture's man. Under
    /// the bow tie the shirt goes on to a round collar; under the mustache, the brows and the eyes the skin goes on.
    func man(_ ctx: OpeningPen, _ box: OpeningBox, _ pose: OpeningPose = OpeningPose()) {
        let hide = pose.hide
        ctx.save()
        ctx.translate(box.x, box.y)
        ctx.scale(box.k, box.k)
        ctx.alpha *= pose.alpha
        let moves = [pose.all, pose.body, pose.head, pose.brows, pose.browL, pose.browR, pose.eyes, pose.eyeL, pose.eyeR,
                     pose.stache, pose.bow, pose.wings, pose.knot]
        edged(ctx, theme.edgeShare * box.size * pose.edge) {
            if hide.isEmpty && moves.allSatisfy({ $0?.still ?? true }) {
                ctx.image(.man, 0, 0, 512, 512)
                return
            }
            let foot: OpeningPoint = (256, 512), knot: OpeningPoint = (P.knot.x, P.knot.y)
            moveBy(ctx, pose.all, P.neck)
            ctx.save()
            moveBy(ctx, pose.body, foot)
            if !hide.contains(.body) { put(ctx, .body, OpeningMove(alpha: pose.body?.alpha ?? 1)) }
            ctx.restore()
            // the head and its face
            ctx.save()
            moveBy(ctx, pose.body, foot)
            moveBy(ctx, pose.head, P.neck)
            if !hide.contains(.head) {
                put(ctx, .head, OpeningMove(alpha: pose.head?.alpha ?? 1))
                if !hide.contains(.brows) {
                    for (name, at, own) in [(OpeningPicture.browL, P.browL, pose.browL), (.browR, P.browR, pose.browR)] {
                        ctx.save()
                        ctx.alpha *= pose.brows?.alpha ?? 1
                        moveBy(ctx, pose.brows, at)
                        put(ctx, name, own ?? OpeningMove(), at)
                        ctx.restore()
                    }
                }
                if !hide.contains(.eyes) {
                    for (name, at, told) in [(OpeningPicture.eyeL, P.eyeL, pose.eyeL), (.eyeR, P.eyeR, pose.eyeR)] {
                        // opening: the smiling arc flattens to a line, and from the line a round eye grows
                        var own = told ?? OpeningMove()
                        let open = clamp(own.open ?? pose.eyes?.open ?? 0)
                        ctx.save()
                        ctx.alpha *= pose.eyes?.alpha ?? 1
                        moveBy(ctx, pose.eyes, at)
                        if open < 0.35 {
                            own.sy = own.sy * lerp(1, 0.22, open / 0.35)
                            put(ctx, name, own, at)
                        } else {
                            let k = (open - 0.35) / 0.65
                            ctx.fill(OpeningPath { $0.ellipse(at.x, at.y + 4 * k, lerp(11, 9.5, k), lerp(2.4, 13.5, k), 0, 0, 7) },
                                     OpeningColor(hex: 0x02132F))
                            ctx.fill(.circle(at.x - 3, at.y - 1 * k, 3.2 * k), OpeningColor.white)
                        }
                        ctx.restore()
                    }
                }
                if !hide.contains(.stache) {
                    let st = pose.stache ?? OpeningMove()
                    ctx.save()
                    ctx.alpha *= st.alpha
                    moveBy(ctx, st, P.stache)
                    if st.split != 0 {
                        put(ctx, .stacheL, OpeningMove(rot: st.split), P.stache)
                        put(ctx, .stacheR, OpeningMove(rot: -st.split), P.stache)
                    } else {
                        put(ctx, .stache)
                    }
                    ctx.restore()
                }
            }
            ctx.restore()
            // the bow tie, over the neck
            if !hide.contains(.bow) {
                ctx.save()
                moveBy(ctx, pose.body, foot)
                ctx.alpha *= pose.bow?.alpha ?? 1
                moveBy(ctx, pose.bow, knot)
                if !hide.contains(.wings) { put(ctx, .wings, pose.wings, knot) }
                if !hide.contains(.knot) { put(ctx, .knot, pose.knot, knot) }
                ctx.restore()
            }
        }
        ctx.restore()
    }

    /// One part alone, anywhere: its picture with the point `anchor` of the grid (its own middle if left out) at
    /// x, y of the screen. `k` is points to a unit of the grid (the launch icon's if left out); `rot` in degrees;
    /// `edge` the dark look's edge round it, from 0 (none) to 1 (the icon's).
    func sprite(_ ctx: OpeningPen, _ name: OpeningPicture, _ x: Double, _ y: Double, k: Double? = nil, rot: Double = 0,
                sx: Double = 1, sy: Double = 1, alpha: Double = 1, anchor: OpeningPoint? = nil, edge: Double = 1) {
        let layer = OpeningRig.layer(name)
        let a = anchor ?? layer.middle, k = k ?? LAUNCH.size / 512
        ctx.save()
        ctx.alpha *= alpha
        ctx.translate(x, y)
        if rot != 0 { ctx.rotate(rot * Double.pi / 180) }
        ctx.scale(k * sx, k * sy)
        edged(ctx, theme.edgeShare * 512 * k * edge) {
            ctx.image(name, layer.x - a.x, layer.y - a.y, layer.w, layer.h)
        }
        ctx.restore()
    }

    /// Where a part's picture lies on the icon's grid.
    func partBox(_ name: OpeningPicture) -> OpeningRig.Layer {
        OpeningRig.layer(name)
    }

    /// A ribbon: a band along a line that may bend, its thickness changing along it; for a shape that stretches
    /// along the dial's ring. `x`, `y` its middle; `dir` its line's direction there (degrees: 0 to the right,
    /// clockwise); `length` along the line; `bend` its curvature, 1 / radius: positive bends clockwise, and with 1 /
    /// DIAL.r a ribbon whose middle is on the ring lies along the ring; `top(u)` and `bottom(u)` how far its two
    /// edges are from the line at u, from 0 (its start) to 1 (its end): `top` is the outer side when it lies along
    /// the ring clockwise; `n` how many pieces it is drawn in.
    func ribbon(_ ctx: OpeningPen, x: Double, y: Double, dir: Double = 0, length: Double, bend: Double = 0,
                top: (Double) -> Double, bottom: (Double) -> Double, fill: OpeningPaint, alpha: Double = 1, n: Int = 48) {
        let th0 = dir * Double.pi / 180, flat = abs(bend) < 1e-6
        var pts: [(px: Double, py: Double, nx: Double, ny: Double, u: Double)] = []
        for i in 0...n {
            let u = Double(i) / Double(n), d = (u - 0.5) * length, th = th0 + bend * d
            pts.append((flat ? x + d * cos(th0) : x + (sin(th) - sin(th0)) / bend,
                        flat ? y + d * sin(th0) : y - (cos(th) - cos(th0)) / bend, sin(th), -cos(th), u))
        }
        var path = OpeningPath()
        for (i, p) in pts.enumerated() {
            let d = top(p.u)
            if i == 0 { path.move(p.px + p.nx * d, p.py + p.ny * d) } else { path.line(p.px + p.nx * d, p.py + p.ny * d) }
        }
        for p in pts.reversed() {
            let d = bottom(p.u)
            path.line(p.px - p.nx * d, p.py - p.ny * d)
        }
        path.close()
        ctx.save()
        ctx.alpha *= alpha
        ctx.fill(path, fill)
        ctx.restore()
    }

    func ribbon(_ ctx: OpeningPen, x: Double, y: Double, dir: Double = 0, length: Double, bend: Double = 0,
                top: (Double) -> Double, bottom: (Double) -> Double, fill: OpeningColor, alpha: Double = 1, n: Int = 48) {
        ribbon(ctx, x: x, y: y, dir: dir, length: length, bend: bend, top: top, bottom: bottom, fill: .color(fill),
               alpha: alpha, n: n)
    }

    /// The mustache's outline, for K.ribbon: its length and its middle on the icon's grid, and how far its upper
    /// and lower edges are from its level middle line at u, from 0 (its left end) to 1 (multiply by box.k). A
    /// ribbon of this outline, level and unbent at the mustache's place, covers the mustache's picture.
    struct Stache {
        let length = OpeningRig.stacheX1 - OpeningRig.stacheX0
        let middle: OpeningPoint = ((OpeningRig.stacheX0 + OpeningRig.stacheX1) / 2, OpeningRig.stacheY)
        /// The picture's own navy.
        let color = OpeningColor(hex: 0x111F4A)

        private func sample(_ u: Double, _ pick: ((top: Double, bottom: Double)) -> Double) -> Double {
            let samples = OpeningRig.stacheSamples
            let f = min(1, max(0, u)) * Double(samples.count - 1)
            let i = min(samples.count - 2, Int(f.rounded(.down)))
            let a = pick(samples[i]), b = pick(samples[i + 1])
            return a + (b - a) * (f - Double(i))
        }

        func top(_ u: Double) -> Double { sample(u) { $0.top } }
        func bottom(_ u: Double) -> Double { sample(u) { $0.bottom } }
    }

    let stache = Stache()

    /// The whole icon in one call: its ground, then, cut to its rounded square, the ticks and the man. `ground`
    /// nil: none; `ticks` false: none, or `tick` changes each (K.ticks); `pose` nil: no man; `content` the man's
    /// alpha (the ticks keep their own, as K.ticks draws them); `clip` false: not cut to the square.
    func icon(_ ctx: OpeningPen, _ box: OpeningBox, ground: OpeningGround? = OpeningGround(), ticks: Bool = true,
              tickColor: OpeningColor? = nil, pose: OpeningPose? = OpeningPose(), content: Double = 1, clip: Bool = true,
              tick: ((Int, OpeningRig.Tick) -> OpeningLogoTick?)? = nil) {
        if let ground { self.ground(ctx, box, ground) }
        let inside = {
            ctx.save()
            ctx.alpha *= content
            if ticks { self.ticks(ctx, box, color: tickColor, tick) }
            if let pose { self.man(ctx, box, pose) }
            ctx.restore()
        }
        if clip { self.clip(ctx, box, inside) } else { inside() }
    }

    /// The launch picture itself, as iOS leaves it: where every opening begins. On `o` unless told another pen.
    /// (With anything changed in it, it is `icon(ctx, box(), ...)`.)
    func launch(_ ctx: OpeningPen? = nil) {
        icon(ctx ?? o, box())
    }

    /// The app's background, or `color`, over everything under it on this pen, to the screen's edges and beyond.
    func backdrop(_ ctx: OpeningPen, _ alpha: Double = 1, _ color: OpeningColor? = nil) {
        if alpha <= 0 { return }
        ctx.save()
        ctx.alpha *= alpha
        ctx.fill(bounds.path, color ?? theme.background)
        ctx.restore()
    }
}
