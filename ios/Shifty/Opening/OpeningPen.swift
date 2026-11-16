import Foundation

// The openings' drawing, as a list of operations (the display list). A scene (OpeningScene) draws a frame with two
// pens, one under the Now screen's parts and one over them; each pen only writes down what it is told, and the app
// plays the list on a SwiftUI Canvas. Nothing here knows SwiftUI: the same lists are written out as JSON and played
// on a browser's canvas to check the scenes (ios/Tests/OpeningCheck/replay.js, which is also a worked example of
// playing a list, operation by operation).
//
// Everything is in the design's points: a screen of 402 x 874, x to the right and y down, which the app lays over
// the real screen by one scale and a move ("the host's scale" below). Angles are radians, growing from the x axis
// toward the y axis: clockwise on the screen, as a canvas counts them.

/// A color: red, green and blue from 0 to 255, as the design's hex colors count them (sRGB, not multiplied by the
/// alpha; a mixed color may have fractions), and alpha from 0 to 1.
struct OpeningColor: Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// 0x0F9D8F, as "#0F9D8F".
    init(hex: UInt32, _ a: Double = 1) {
        self.init(Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF), a)
    }

    static let white = OpeningColor(255, 255, 255)
    static let black = OpeningColor(0, 0, 0)
    static let clear = OpeningColor(0, 0, 0, 0)

    /// The same color at the alpha `a`.
    func alpha(_ a: Double) -> OpeningColor {
        OpeningColor(r, g, b, a)
    }

    /// The same color, its alpha multiplied by `k`.
    func faded(_ k: Double) -> OpeningColor {
        OpeningColor(r, g, b, a * k)
    }

    /// The same color, its red, green and blue to whole numbers, as a hex color has them.
    var whole: OpeningColor {
        OpeningColor((r + 0.5).rounded(.down), (g + 0.5).rounded(.down), (b + 0.5).rounded(.down), a)
    }

    /// The color `k` of the way to `other`, from 0 to 1: red, green and blue to whole numbers, as a hex color has
    /// them, the alpha as it comes.
    func mixed(_ other: OpeningColor, _ k: Double) -> OpeningColor {
        let k = min(1, max(0, k))
        func channel(_ x: Double, _ y: Double) -> Double {
            (x + (y - x) * k + 0.5).rounded(.down)
        }
        return OpeningColor(channel(r, other.r), channel(g, other.g), channel(b, other.b), a + (other.a - a) * k)
    }

    /// The color as a list holds it: each part within its bounds (an alpha a scene has multiplied past 1 is 1, as a
    /// canvas takes it).
    fileprivate var bounded: OpeningColor {
        OpeningColor(min(255, max(0, r)), min(255, max(0, g)), min(255, max(0, b)), min(1, max(0, a)))
    }
}

/// A gradient's stop: where along it, from 0 to 1, and its color.
struct OpeningStop: Equatable {
    var at: Double
    var color: OpeningColor

    init(_ at: Double, _ color: OpeningColor) {
        self.at = at
        self.color = color
    }
}

/// What a shape is filled or stroked with. A gradient's points are in the coordinates of the moment it is drawn
/// with, as the path's are; its stops are in rising order; between them the colors run evenly, red, green, blue and
/// alpha each on its own (not premultiplied), and beyond its ends the first and the last color go on.
enum OpeningPaint: Equatable {
    case color(OpeningColor)
    /// Along the line from the point x0, y0 (stop 0) to the point x1, y1 (stop 1).
    case linear(x0: Double, y0: Double, x1: Double, y1: Double, stops: [OpeningStop])
    /// Round the point x, y, both circles about it: from the radius r0 (stop 0) to the radius r1 (stop 1).
    case radial(x: Double, y: Double, r0: Double, r1: Double, stops: [OpeningStop])

    /// The paint as a list holds it: its colors within their bounds.
    fileprivate var bounded: OpeningPaint {
        func each(_ stops: [OpeningStop]) -> [OpeningStop] {
            stops.map { OpeningStop(min(1, max(0, $0.at)), $0.color.bounded) }
        }
        switch self {
        case .color(let color):
            return .color(color.bounded)
        case .linear(let x0, let y0, let x1, let y1, let stops):
            return .linear(x0: x0, y0: y0, x1: x1, y1: y1, stops: each(stops))
        case .radial(let x, let y, let r0, let r1, let stops):
            return .radial(x: x, y: y, r0: r0, r1: r1, stops: each(stops))
        }
    }
}

/// A point of the screen, or of the icon's grid.
typealias OpeningPoint = (x: Double, y: Double)

/// A path: its pieces in order, in the coordinates of the moment it is filled, stroked or clipped to (the pen's
/// moves and turns until then). A value: built first, then handed to the pen.
///
/// Its elements are written so that whoever plays them needs no rule of a canvas's: every piece begins with a
/// `move`, an arc or a `roundRect`; where a canvas would go on from a closed piece's beginning, the `move` there is
/// written out. On SwiftUI's Path: `move(to:)`, `addLine(to:)`, `addQuadCurve(to:control:)`,
/// `addCurve(to:control1:control2:)`, `addRelativeArc(center:radius:startAngle:delta:transform:)` (never
/// `addArc(…clockwise:)`, whose flag reads the other way where y points down), `closeSubpath()`.
struct OpeningPath: Equatable {
    enum Element: Equatable {
        /// A new piece begins at x, y.
        case move(Double, Double)
        /// A straight line to x, y.
        case line(Double, Double)
        /// A curve to x, y, bent toward the point cx, cy.
        case quad(cx: Double, cy: Double, Double, Double)
        /// A curve to x, y, bent toward two points.
        case cubic(c1x: Double, c1y: Double, c2x: Double, c2y: Double, Double, Double)
        /// A part of the circle round x, y: from the angle `start` on by `delta` radians, clockwise on the screen
        /// when positive and the other way when negative; 2π or -2π is the whole circle, and it is never more. If
        /// the piece has a point already, a straight line joins it to the arc's beginning; if not, the piece
        /// begins there. (`addRelativeArc(center:radius:startAngle:delta:)` does both.)
        case arc(x: Double, y: Double, r: Double, start: Double, delta: Double)
        /// The same of an ellipse with the radii rx and ry, turned by `rotation` radians: its angles are counted on
        /// the ellipse before it is turned. As the arc of a circle of radius 1 round 0, 0 from `start` by `delta`,
        /// under a transform that scales it by rx, ry, then turns it by `rotation`, then moves it to x, y
        /// (`CGAffineTransform(translationX: x, y: y).rotated(by: rotation).scaledBy(x: rx, y: ry)`).
        case ellipse(x: Double, y: Double, rx: Double, ry: Double, rotation: Double, start: Double, delta: Double)
        /// A whole rectangle, a closed piece of its own: w and h are positive, its corners quarter circles of the
        /// radius r (0: square corners; never more than half its shorter side). It runs clockwise on the screen
        /// from its top edge, which matters only where pieces overlap and the fill is not even-odd. Written out:
        /// move(x + r, y), line(x + w - r, y), arc(x + w - r, y + r, r, -π/2, by π/2), line(x + w, y + h - r),
        /// arc(x + w - r, y + h - r, r, 0, by π/2), line(x + r, y + h), arc(x + r, y + h - r, r, π/2, by π/2),
        /// line(x, y + r), arc(x + r, y + r, r, π, by π/2), close. (Or `addRoundedRect(in:cornerSize:style:)` with
        /// the style `.circular`, never `.continuous`.)
        case roundRect(x: Double, y: Double, w: Double, h: Double, r: Double)
        /// A straight line back to where the piece began, closing it.
        case close
    }

    private(set) var elements: [Element] = []
    /// Where the piece being drawn began, and whether it is still open to go on from. After a closed piece a canvas
    /// goes on from that piece's beginning: here that is written out as a `move`, for every renderer to agree.
    private var beganX: Double?
    private var beganY = 0.0
    private var open = false

    init() {}

    /// A path built in place: `OpeningPath { $0.move(1, 2); $0.line(3, 4) }`.
    init(_ build: (inout OpeningPath) -> Void) {
        build(&self)
    }

    var isEmpty: Bool { elements.isEmpty }

    /// Before a line or a curve: a closed piece is gone on from its beginning.
    private mutating func resume() {
        guard !open, let x = beganX else { return }
        elements.append(.move(x, beganY))
        open = true
    }

    private mutating func begin(_ x: Double, _ y: Double) {
        beganX = x
        beganY = y
        open = true
    }

    mutating func move(_ x: Double, _ y: Double) {
        elements.append(.move(x, y))
        begin(x, y)
    }

    mutating func move(_ p: OpeningPoint) {
        move(p.x, p.y)
    }

    mutating func line(_ x: Double, _ y: Double) {
        // as on a canvas, a line with nothing before it only sets the point
        guard beganX != nil else { return move(x, y) }
        resume()
        elements.append(.line(x, y))
    }

    mutating func line(_ p: OpeningPoint) {
        line(p.x, p.y)
    }

    mutating func quad(_ cx: Double, _ cy: Double, _ x: Double, _ y: Double) {
        if beganX == nil { move(cx, cy) }
        resume()
        elements.append(.quad(cx: cx, cy: cy, x, y))
    }

    mutating func cubic(_ c1x: Double, _ c1y: Double, _ c2x: Double, _ c2y: Double, _ x: Double, _ y: Double) {
        if beganX == nil { move(c1x, c1y) }
        resume()
        elements.append(.cubic(c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x, y))
    }

    /// A canvas's arc: round x, y from the angle `a0` to the angle `a1`, clockwise on the screen, or the other way
    /// with `counter`. From 0 to 7 (anything of a whole turn or more) is the whole circle.
    mutating func arc(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, counter: Bool = false) {
        resume()
        elements.append(.arc(x: x, y: y, r: max(0, r), start: a0, delta: Self.sweep(a0, a1, counter)))
        if !open { begin(x + r * cos(a0), y + r * sin(a0)) }
    }

    /// A canvas's ellipse: as `arc`, with two radii, turned by `rotation` radians.
    mutating func ellipse(_ x: Double, _ y: Double, _ rx: Double, _ ry: Double, _ rotation: Double, _ a0: Double,
                          _ a1: Double, counter: Bool = false) {
        resume()
        elements.append(.ellipse(x: x, y: y, rx: max(0, rx), ry: max(0, ry), rotation: rotation, start: a0,
                                 delta: Self.sweep(a0, a1, counter)))
        if !open {
            let px = rx * cos(a0), py = ry * sin(a0)
            begin(x + px * cos(rotation) - py * sin(rotation), y + px * sin(rotation) + py * cos(rotation))
        }
    }

    /// A whole circle.
    mutating func circle(_ x: Double, _ y: Double, _ r: Double) {
        arc(x, y, r, 0, 2 * Double.pi)
    }

    mutating func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        roundRect(x, y, w, h, 0)
    }

    /// A rectangle with round corners of the radius r, never more than half its shorter side. A canvas goes on
    /// from its corner x, y afterwards.
    mutating func roundRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) {
        elements.append(.roundRect(x: min(x, x + w), y: min(y, y + h), w: abs(w), h: abs(h),
                                   r: max(0, min(r, min(abs(w), abs(h)) / 2))))
        beganX = x
        beganY = y
        open = false
    }

    mutating func close() {
        guard open else { return }
        elements.append(.close)
        open = false
    }

    /// How far an arc from `a0` to `a1` turns, as a canvas reads the two angles.
    private static func sweep(_ a0: Double, _ a1: Double, _ counter: Bool) -> Double {
        let turn = 2 * Double.pi
        if !counter {
            if a1 - a0 >= turn { return turn }
            var d = (a1 - a0).truncatingRemainder(dividingBy: turn)
            if d < 0 { d += turn }
            return d
        }
        if a0 - a1 >= turn { return -turn }
        var d = (a0 - a1).truncatingRemainder(dividingBy: turn)
        if d < 0 { d += turn }
        return -d
    }

    static func circle(_ x: Double, _ y: Double, _ r: Double) -> OpeningPath {
        OpeningPath { $0.circle(x, y, r) }
    }

    static func arc(_ x: Double, _ y: Double, _ r: Double, _ a0: Double, _ a1: Double, counter: Bool = false) -> OpeningPath {
        OpeningPath { $0.arc(x, y, r, a0, a1, counter: counter) }
    }

    static func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> OpeningPath {
        OpeningPath { $0.rect(x, y, w, h) }
    }

    static func roundRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> OpeningPath {
        OpeningPath { $0.roundRect(x, y, w, h, r) }
    }

    static func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> OpeningPath {
        OpeningPath { $0.move(x0, y0); $0.line(x1, y1) }
    }

    static func line(_ a: OpeningPoint, _ b: OpeningPoint) -> OpeningPath {
        line(a.x, a.y, b.x, b.y)
    }
}

/// The pictures the man is put together of (OpeningRig.layers), and `man`, all of him in one. A case's name is
/// the picture's: "man", "head", "stacheL"... (the checks' are ios/Tests/OpeningCheck/mock/assets/<name>.png: each
/// its layer's rectangle of the icon's grid, two pixels to a unit, on clear).
enum OpeningPicture: String, CaseIterable {
    case man, body, head, wings, knot, stache, stacheL, stacheR, browL, browR, eyeL, eyeR
}

/// The dial's marks, which the app draws with its own views: where the shift started, now, and the goal's flag.
enum OpeningDialMark: String {
    case start, knob, flag
}

/// An edge round all that a group draws: its silhouette widened by `width` points, in `color`, under it.
struct OpeningEdge: Equatable {
    var color: OpeningColor
    var width: Double
}

/// A pen: it writes down what it is told to draw, in order. Its state is a canvas's: where and how large things are
/// drawn (`translate`, `rotate`, `scale`), how clear (`alpha`), cut to what (`clip`), with what shadow and blur.
/// `save` keeps the whole state and `restore` brings the last kept one back; nothing else undoes a clip, a shadow or
/// a blur.
///
/// Playing a list. It starts from a clean state: the host's transform alone (the design's space laid over the
/// screen), alpha 1, no clip, no shadow, no blur. A frame's two lists (OpeningFrame) are played apart, each from
/// that state: `under`, then the Now screen's parts, then `over`. On SwiftUI's Canvas all of the state is in the
/// GraphicsContext, which is a value, so the kept states are a stack of contexts:
///
///     save        a copy of the context goes on the stack
///     restore     the context is the copy taken off the stack (the pen never writes one without its `save`)
///     translate   context.translateBy(x:y:)        rotate   context.rotate(by: .radians(a))
///     scale       context.scaleBy(x:y:)            alpha    context.opacity = a (set, not multiplied)
///     clip        context.clip(to: path, style: FillStyle(eoFill: evenOdd))
///     fill        context.fill(path, with: shading, style: FillStyle(eoFill: evenOdd))
///     stroke      context.stroke(path, with: shading, style: StrokeStyle(lineWidth:lineCap:lineJoin:miterLimit: 10))
///     image       context.draw(the picture, resolved, in: the rectangle)
///     shadow      context.addFilter(.shadow(color:radius:x:y:)): the radius and the offsets times the host's scale
///     blur        context.addFilter(.blur(radius:)): the radius times the host's scale
///     group       context.drawLayer { layer in ... }: the operations inside played on `layer`, with a stack of its own
///     mark        context.draw(the mark's view as a resolved symbol, at: .zero)
///     hours       context.draw(the four numerals' view as a resolved symbol, at: .zero), at `share` of the opacity
///
/// A shading is `.color(_:)`, `.linearGradient(_:startPoint:endPoint:)` or `.radialGradient(_:center:startRadius:
/// endRadius:)`; OpeningPath says how a path's elements are laid. A list may end with a `save` still open: the stack
/// is then dropped. Each case of `Op` says exactly what it means.
final class OpeningPen {
    enum Cap: String {
        case butt, round, square
    }

    enum Join: String {
        case miter, round, bevel
    }

    /// One operation, and what it means to whoever plays the list.
    enum Op: Equatable {
        /// Keeps the state: the transform, the alpha, the clip, the shadow and the blur.
        case save
        /// Brings back the state kept by the `save` it answers.
        case restore
        /// What follows is moved by x, y, in the coordinates as they are now.
        case translate(Double, Double)
        /// What follows is turned about the origin of the coordinates as they are now, by radians, clockwise on
        /// the screen.
        case rotate(Double)
        /// What follows is scaled about the origin of the coordinates as they are now, x by the first number and y
        /// by the second.
        case scale(Double, Double)
        /// What follows is drawn at this alpha, from 0 to 1, until another `alpha` or the `restore`: this value
        /// itself, not a share of the one before (the pen has multiplied already). A color's own alpha is
        /// multiplied by it.
        case alpha(Double)
        /// From here to the `restore`, what is drawn is cut to this path as well (the clips before it still hold).
        /// The path is in the coordinates as they are now, and stays where it is when they change later.
        /// `evenOdd`: the path's inside by the even-odd rule, else by the nonzero one.
        case clip(OpeningPath, evenOdd: Bool)
        /// The path's inside in the paint, by the even-odd rule if `evenOdd`, else by the nonzero one. An open
        /// piece is filled as if it were closed.
        case fill(OpeningPath, OpeningPaint, evenOdd: Bool)
        /// The path's line in the paint, its middle on the path, `width` wide in the coordinates as they are now
        /// (a scale widens it). Open ends take the cap and corners the join; mitered joins up to ten times the
        /// width, as a canvas has them.
        case stroke(OpeningPath, OpeningPaint, width: Double, cap: Cap, join: Join)
        /// A picture of the man's, stretched over the rectangle x, y, w, h (w and h positive) in the coordinates
        /// as they are now, at the alpha in force.
        case image(OpeningPicture, x: Double, y: Double, w: Double, h: Double)
        /// From here to the `restore`, each thing drawn (a fill, a stroke, a picture, a mark, a group as a whole)
        /// casts a shadow of its own shape under itself: in `color`, blurred by `radius`, moved by dx, dy. The
        /// three are in the design's points as they come out on the screen: times the host's scale, and neither
        /// scaled nor turned by the pen's own moves (dy is down the screen under any `rotate`). The radius is the
        /// one SwiftUI's shadow takes, as the Now screen's own views give theirs (the knob's is 7): it is passed on
        /// as it is. (The checks' browser draws the same number less soft; that is the browser's.) No more than
        /// one shadow is in force at a time: the pen takes no second one before the `restore`.
        case shadow(OpeningColor, radius: Double, dx: Double, dy: Double)
        /// From here to the `restore`, each thing drawn is blurred by this radius, as SwiftUI's blur takes it; in
        /// the design's points as they come out on the screen, as a shadow's. No more than one at a time.
        case blur(Double)
        /// The operations inside are drawn on a clear layer of their own, and the layer is then put down as one
        /// thing. Inside: the transform as it is now; alpha 1; no shadow and no blur, whatever is in force
        /// outside; and saves and restores of its own (whatever state the inside changes ends with the group).
        /// The layer is put down at the alpha in force outside, within the clip, and with the shadow and the blur
        /// in force outside, each once for the whole layer.
        ///
        /// With an edge, the layer's silhouette goes down under the layer and as one with it (the same alpha, one
        /// shadow for the two): in the edge's color, widened all round by the edge's width, so that a point is in
        /// it if the layer has anything within that distance. The width is in the design's points as they come
        /// out on the screen: times the host's scale, not scaled by the pen's moves. The checks draw it so
        /// (replay.js): the layer stamped at a dozen or more places round a circle of that radius (and round one
        /// of half the radius, once that is more than a pixel or two), the stamps filled with the color, the
        /// layer over them.
        case group(OpeningEdge?, [Op])
        /// A mark of the dial, its middle at the origin: the app's own view of it, as the Now screen's dial draws
        /// it at its own size (the start's disc 22 points across, the knob 32, the flag's halo 42) and in the
        /// day's colors, drawn in the transform and at the alpha as they are (a scale of 0.5 halves it). The start
        /// and the flag are written only for a day that has them.
        case mark(OpeningDialMark)
        /// The dial's 12, 3, 6 and 9, the dial's middle at the origin: the app's own view of them, as the Now
        /// screen's dial of 350 points draws them (each 120 points from the middle), at this share of their own
        /// opacity (0 to 1; more is 1), in the transform and at the alpha as they are.
        case hours(Double)
    }

    /// What the pen keeps with each `save`: the alpha in force, and whether a shadow and a blur are.
    private struct State {
        var alpha = 1.0
        var shadow = false
        var blur = false
    }

    /// The list being written, and before it the lists of the groups it is inside of.
    private var lists: [[Op]] = [[]]
    /// The state at each `save` of the list being written, the one in force last.
    private var states: [State] = [State()]

    /// All that was drawn, in order.
    var ops: [Op] { lists[0] }

    private func write(_ op: Op) {
        lists[lists.count - 1].append(op)
    }

    func save() {
        states.append(states[states.count - 1])
        write(.save)
    }

    /// Without a `save` to answer it does nothing, as on a canvas.
    func restore() {
        guard states.count > 1 else { return }
        states.removeLast()
        write(.restore)
    }

    func translate(_ x: Double, _ y: Double) {
        write(.translate(x, y))
    }

    /// By radians, clockwise on the screen.
    func rotate(_ radians: Double) {
        write(.rotate(radians))
    }

    func scale(_ sx: Double, _ sy: Double) {
        write(.scale(sx, sy))
    }

    /// The alpha of what is drawn from here on, a canvas's globalAlpha: `pen.alpha *= 0.5` halves it, `pen.alpha =
    /// 1` sets it. A value outside 0...1 is not taken, as on a canvas, and the alpha stays.
    var alpha: Double {
        get { states[states.count - 1].alpha }
        set {
            guard newValue.isFinite, newValue >= 0, newValue <= 1, newValue != states[states.count - 1].alpha else { return }
            states[states.count - 1].alpha = newValue
            write(.alpha(newValue))
        }
    }

    func clip(_ path: OpeningPath, evenOdd: Bool = false) {
        write(.clip(path, evenOdd: evenOdd))
    }

    func fill(_ path: OpeningPath, _ paint: OpeningPaint, evenOdd: Bool = false) {
        write(.fill(path, paint.bounded, evenOdd: evenOdd))
    }

    func fill(_ path: OpeningPath, _ color: OpeningColor, evenOdd: Bool = false) {
        write(.fill(path, .color(color.bounded), evenOdd: evenOdd))
    }

    func stroke(_ path: OpeningPath, _ paint: OpeningPaint, width: Double, cap: Cap = .butt, join: Join = .miter) {
        write(.stroke(path, paint.bounded, width: width, cap: cap, join: join))
    }

    func stroke(_ path: OpeningPath, _ color: OpeningColor, width: Double, cap: Cap = .butt, join: Join = .miter) {
        write(.stroke(path, .color(color.bounded), width: width, cap: cap, join: join))
    }

    func image(_ picture: OpeningPicture, _ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        write(.image(picture, x: x, y: y, w: w, h: h))
    }

    /// Until the `restore`: a shadow under each thing drawn. `radius`, `dx` and `dy` in the design's points, as
    /// SwiftUI's shadow takes them, not scaled with what is drawn. Wrap what casts it in `save` and `restore`:
    /// while one shadow is in force another is not taken (a canvas would change it; whoever plays the list could
    /// only add to it).
    func shadow(_ color: OpeningColor, radius: Double, dx: Double = 0, dy: Double = 0) {
        guard !states[states.count - 1].shadow else {
            assertionFailure("a second shadow before the restore: give each its own save and restore")
            return
        }
        states[states.count - 1].shadow = true
        write(.shadow(color.bounded, radius: max(0, radius), dx: dx, dy: dy))
    }

    /// Until the `restore`: each thing drawn blurred. `radius` in the design's points, as SwiftUI's blur takes it.
    /// One at a time, as a shadow.
    func blur(_ radius: Double) {
        guard !states[states.count - 1].blur else {
            assertionFailure("a second blur before the restore: give each its own save and restore")
            return
        }
        states[states.count - 1].blur = true
        write(.blur(max(0, radius)))
    }

    /// What `draw` draws as one thing: on a layer of its own, put down whole (Op.group). Inside, the alpha starts
    /// from 1, no shadow or blur is in force, and the state it changes is its own.
    func group(edge: OpeningEdge? = nil, _ draw: () -> Void) {
        let outer = states
        states = [State()]
        lists.append([])
        draw()
        var inside = lists.removeLast()
        // a `save` left open inside ends with the group
        inside.append(contentsOf: Array(repeating: Op.restore, count: states.count - 1))
        states = outer
        write(.group(edge.map { OpeningEdge(color: $0.color.bounded, width: max(0, $0.width)) }, inside))
    }

    func mark(_ mark: OpeningDialMark) {
        write(.mark(mark))
    }

    func hours(_ share: Double = 1) {
        write(.hours(max(0, share)))
    }
}

// MARK: - As JSON, for the checks

extension OpeningColor {
    /// [r, g, b, a].
    var json: String { "[" + OpeningJSON.numbers([r, g, b, a]) + "]" }
}

extension OpeningPaint {
    /// A color as [r, g, b, a]; a gradient as ["linear", x0, y0, x1, y1, [[at, color], ...]] or ["radial", x, y,
    /// r0, r1, [[at, color], ...]].
    var json: String {
        func list(_ stops: [OpeningStop]) -> String {
            "[" + stops.map { "[" + OpeningJSON.number($0.at) + "," + $0.color.json + "]" }.joined(separator: ",") + "]"
        }
        switch self {
        case .color(let color):
            return color.json
        case .linear(let x0, let y0, let x1, let y1, let stops):
            return "[\"linear\"," + OpeningJSON.numbers([x0, y0, x1, y1]) + "," + list(stops) + "]"
        case .radial(let x, let y, let r0, let r1, let stops):
            return "[\"radial\"," + OpeningJSON.numbers([x, y, r0, r1]) + "," + list(stops) + "]"
        }
    }
}

extension OpeningPath {
    /// One flat list, each piece a letter and its numbers: "M" x y, "L" x y, "Q" cx cy x y, "C" c1x c1y c2x c2y x y,
    /// "A" x y r start delta, "E" x y rx ry rotation start delta, "R" x y w h r, "Z".
    var json: String {
        var out: [String] = []
        for element in elements {
            switch element {
            case .move(let x, let y):
                out.append("\"M\"," + OpeningJSON.numbers([x, y]))
            case .line(let x, let y):
                out.append("\"L\"," + OpeningJSON.numbers([x, y]))
            case .quad(let cx, let cy, let x, let y):
                out.append("\"Q\"," + OpeningJSON.numbers([cx, cy, x, y]))
            case .cubic(let c1x, let c1y, let c2x, let c2y, let x, let y):
                out.append("\"C\"," + OpeningJSON.numbers([c1x, c1y, c2x, c2y, x, y]))
            case .arc(let x, let y, let r, let start, let delta):
                out.append("\"A\"," + OpeningJSON.numbers([x, y, r, start, delta]))
            case .ellipse(let x, let y, let rx, let ry, let rotation, let start, let delta):
                out.append("\"E\"," + OpeningJSON.numbers([x, y, rx, ry, rotation, start, delta]))
            case .roundRect(let x, let y, let w, let h, let r):
                out.append("\"R\"," + OpeningJSON.numbers([x, y, w, h, r]))
            case .close:
                out.append("\"Z\"")
            }
        }
        return "[" + out.joined(separator: ",") + "]"
    }
}

extension OpeningPen.Op {
    /// A list: the operation's name, then what it takes, in the order of its case.
    var json: String {
        switch self {
        case .save:
            return "[\"save\"]"
        case .restore:
            return "[\"restore\"]"
        case .translate(let x, let y):
            return "[\"translate\"," + OpeningJSON.numbers([x, y]) + "]"
        case .rotate(let radians):
            return "[\"rotate\"," + OpeningJSON.number(radians) + "]"
        case .scale(let sx, let sy):
            return "[\"scale\"," + OpeningJSON.numbers([sx, sy]) + "]"
        case .alpha(let alpha):
            return "[\"alpha\"," + OpeningJSON.number(alpha) + "]"
        case .clip(let path, let evenOdd):
            return "[\"clip\"," + path.json + "," + (evenOdd ? "1" : "0") + "]"
        case .fill(let path, let paint, let evenOdd):
            return "[\"fill\"," + path.json + "," + paint.json + "," + (evenOdd ? "1" : "0") + "]"
        case .stroke(let path, let paint, let width, let cap, let join):
            return "[\"stroke\"," + path.json + "," + paint.json + "," + OpeningJSON.number(width)
                + ",\"" + cap.rawValue + "\",\"" + join.rawValue + "\"]"
        case .image(let picture, let x, let y, let w, let h):
            return "[\"image\",\"" + picture.rawValue + "\"," + OpeningJSON.numbers([x, y, w, h]) + "]"
        case .shadow(let color, let radius, let dx, let dy):
            return "[\"shadow\"," + color.json + "," + OpeningJSON.numbers([radius, dx, dy]) + "]"
        case .blur(let radius):
            return "[\"blur\"," + OpeningJSON.number(radius) + "]"
        case .group(let edge, let ops):
            let around = edge.map { $0.color.json + "," + OpeningJSON.number($0.width) } ?? "null,0"
            return "[\"group\"," + around + "," + OpeningJSON.list(ops) + "]"
        case .mark(let mark):
            return "[\"mark\",\"" + mark.rawValue + "\"]"
        case .hours(let share):
            return "[\"hours\"," + OpeningJSON.number(share) + "]"
        }
    }
}

/// Numbers and lists as JSON has them, written by hand: short, and each number whole to its last digit.
enum OpeningJSON {
    /// A number at its full precision; one that is not a number at all, as 0.
    static func number(_ x: Double) -> String {
        guard x.isFinite else { return "0" }
        if x == x.rounded(), abs(x) < 1e15 { return String(Int64(x)) }
        return "\(x)"
    }

    static func numbers(_ list: [Double]) -> String {
        list.map(number).joined(separator: ",")
    }

    static func list(_ ops: [OpeningPen.Op]) -> String {
        "[" + ops.map(\.json).joined(separator: ",") + "]"
    }

    /// A text between quotes, with what JSON asks to be escaped.
    static func text(_ s: String) -> String {
        var out = "\""
        for c in s.unicodeScalars {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            default: out.unicodeScalars.append(c)
            }
        }
        return out + "\""
    }
}
