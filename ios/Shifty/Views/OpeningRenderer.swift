import SwiftUI
import UIKit

// An opening's list of drawing operations (Opening/OpeningPen.swift) played on a SwiftUI canvas: operation by
// operation as that file says each is played, which ios/Tests/OpeningCheck/replay.js does on a browser's canvas.

/// The app's own views a list is drawn with, a canvas's symbols: the dial's three marks (DialMarks.swift) and its
/// four hours (NowView's DialHours).
enum OpeningSymbol: Hashable {
    case start, knob, flag, hours
}

extension OpeningPicture {
    /// The picture's image set in Assets.xcassets, written by scripts/rig.py.
    var asset: String { "OpeningRig-" + rawValue }
}

/// Plays lists on one canvas, for one frame. The design's space lies on the canvas at `scale`, moved by `offset`.
///
/// What Apple's documentation leaves open is written here so as to be right either way:
/// - A layer's context (`drawLayer`) is not said to begin from the context it is drawn into, so each layer is given
///   its transform and its opacity outright.
/// - Filters are not said to follow a context's transform or not, and a shadow's and a blur's sizes are in the
///   design's points on the screen, whatever the pen has scaled or turned: so a filter is added to a context whose
///   transform is none at all, with its sizes multiplied by the host's scale here, and what it applies to is drawn
///   in a layer of that context, at the pen's transform.
/// - An edge round a group needs no filter and no blend mode: the group is stamped round a circle into a layer
///   whose alpha the context is then cut to (`clipToLayer`, whose documentation says just that), the edge's color
///   is filled through that cut, and the group is drawn over it, all in one layer.
final class OpeningPlayer {
    /// The pen's state that a `save` keeps: the context (its transform, its opacity and its clip) and the shadow and
    /// the blur in force, which are added to a context only as something is drawn with them.
    private struct Level {
        var context: GraphicsContext
        var shadow: Shadow?
        var blur: CGFloat?
    }

    /// A shadow as the canvas takes it: in the canvas's points.
    private struct Shadow {
        var color: Color
        var radius: CGFloat
        var x: CGFloat
        var y: CGFloat
    }

    /// Points of the canvas to one of the design's: the host's scale.
    private let scale: CGFloat
    /// How large the app's own views (the marks, the hours) are drawn against the design's. On the screen it is one
    /// over the host's scale: a mark's size then follows the pen's scale alone, and where the host's scale is under 1
    /// (a narrow iPhone, whose dial is smaller) the finished dial's marks are the real ones' size. In a small picture
    /// of a scene it is 1: the marks are as small as the rest.
    private let own: CGFloat
    /// The man's pictures made ready ahead (OpeningStage); one that is not there is read from the assets.
    private let pictures: [OpeningPicture: UIImage]
    /// The canvas's context as it was given, to resolve pictures and symbols with, and the same with the design's
    /// space laid on it: a list's clean state.
    private let source: GraphicsContext
    private let base: GraphicsContext
    private var images: [OpeningPicture: GraphicsContext.ResolvedImage] = [:]
    private var symbols: [OpeningSymbol: GraphicsContext.ResolvedSymbol] = [:]

    init(scale: CGFloat, offset: CGSize, own: CGFloat, pictures: [OpeningPicture: UIImage] = [:], on context: GraphicsContext) {
        self.scale = scale
        self.own = own
        self.pictures = pictures
        source = context
        var laid = context
        laid.translateBy(x: offset.width, y: offset.height)
        laid.scaleBy(x: scale, y: scale)
        base = laid
    }

    /// One list, from a clean state: the host's transform alone, alpha 1, no clip, no shadow, no blur.
    func play(_ ops: [OpeningPen.Op]) {
        guard !ops.isEmpty, scale.isFinite, scale > 0, own.isFinite, own > 0 else { return }
        play(ops, on: Level(context: base))
    }

    /// The operations in order, with a stack of states of their own; one that holds a number that is not a number is
    /// passed over.
    private func play(_ ops: [OpeningPen.Op], on first: Level) {
        var level = first
        var kept: [Level] = []
        for op in ops {
            switch op {
            case .save:
                kept.append(level)
            case .restore:
                if let last = kept.popLast() { level = last }
            case .translate(let x, let y):
                guard x.isFinite, y.isFinite else { continue }
                level.context.translateBy(x: CGFloat(x), y: CGFloat(y))
            case .rotate(let radians):
                guard radians.isFinite else { continue }
                level.context.rotate(by: .radians(radians))
            case .scale(let x, let y):
                guard x.isFinite, y.isFinite else { continue }
                level.context.scaleBy(x: CGFloat(x), y: CGFloat(y))
            case .alpha(let alpha):
                guard alpha.isFinite else { continue }
                level.context.opacity = min(1, max(0, alpha))
            case .clip(let path, let evenOdd):
                guard let shape = Self.shape(path) else { continue }
                level.context.clip(to: shape, style: FillStyle(eoFill: evenOdd))
            case .fill(let path, let paint, let evenOdd):
                guard let shape = Self.shape(path), let shading = Self.shading(paint) else { continue }
                let style = FillStyle(eoFill: evenOdd)
                draw(level) { context in
                    context.fill(shape, with: shading, style: style)
                }
            case .stroke(let path, let paint, let width, let cap, let join):
                guard width.isFinite, width > 0, let shape = Self.shape(path), let shading = Self.shading(paint) else { continue }
                let style = StrokeStyle(lineWidth: CGFloat(width), lineCap: Self.cap(cap), lineJoin: Self.join(join), miterLimit: 10)
                draw(level) { context in
                    context.stroke(shape, with: shading, style: style)
                }
            case .image(let picture, let x, let y, let w, let h):
                guard x.isFinite, y.isFinite, w.isFinite, h.isFinite, w > 0, h > 0 else { continue }
                guard let image = resolved(picture) else { continue }
                let rect = CGRect(x: x, y: y, width: w, height: h)
                draw(level) { context in
                    context.draw(image, in: rect)
                }
            case .shadow(let color, let radius, let dx, let dy):
                guard radius.isFinite, dx.isFinite, dy.isFinite, let tint = Self.color(color) else { continue }
                level.shadow = Shadow(color: tint, radius: CGFloat(radius) * scale, x: CGFloat(dx) * scale, y: CGFloat(dy) * scale)
            case .blur(let radius):
                guard radius.isFinite else { continue }
                level.blur = CGFloat(radius) * scale
            case .group(let edge, let inside):
                group(edge, inside, level)
            case .mark(let mark):
                guard let symbol = resolved(Self.symbol(of: mark)) else { continue }
                let own = self.own
                draw(level) { context in
                    var real = context
                    real.scaleBy(x: own, y: own)
                    real.draw(symbol, at: .zero)
                }
            case .hours(let share):
                guard share.isFinite, share > 0, let symbol = resolved(OpeningSymbol.hours) else { continue }
                let own = self.own
                draw(level) { context in
                    var real = context
                    real.opacity = context.opacity * min(1, share)
                    real.scaleBy(x: own, y: own)
                    real.draw(symbol, at: .zero)
                }
            }
        }
    }

    /// One thing drawn in a state: straight on its context, or with a shadow or a blur in force, as a layer of its
    /// own under them. Nothing where it could not be seen: at no opacity, or under a transform that leaves it no size.
    private func draw(_ level: Level, _ body: (GraphicsContext) -> Void) {
        guard Self.shows(level.context) else { return }
        if level.shadow == nil, level.blur == nil {
            body(level.context)
        } else {
            layer(level, body)
        }
    }

    /// What `body` draws, on a layer of its own that is put down as one thing: at the state's opacity, within its
    /// clip, and with its shadow and its blur, each once for the whole layer. Inside, the pen's transform and alpha 1.
    private func layer(_ level: Level, _ body: (GraphicsContext) -> Void) {
        var outer = level.context
        let full = outer.transform
        if level.shadow != nil || level.blur != nil {
            // the filters' sizes are the canvas's points: under no transform, whichever way a filter reads it
            outer.transform = .identity
            if let shadow = level.shadow {
                outer.addFilter(.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y))
            }
            // a blur added after the shadow: of the two, the last one added is the first to apply (as a blur added
            // after a threshold softens what the threshold then cuts), so that the shadow is the blurred thing's
            if let blur = level.blur {
                outer.addFilter(.blur(radius: blur))
            }
        }
        outer.drawLayer { inner in
            inner.transform = full
            inner.opacity = 1
            inner.blendMode = .normal
            body(inner)
        }
    }

    /// A group: its operations on a layer, with a stack of their own. With an edge, the layer's silhouette, widened by
    /// the edge's width, goes down under it in the edge's color and as one with it: the operations are played in
    /// place and at places round a circle of that radius (and round one of half of it, once it is wide enough to
    /// leave a gap inside) as a mask, the color is filled through the mask, and they are played once more over it.
    private func group(_ edge: OpeningEdge?, _ ops: [OpeningPen.Op], _ level: Level) {
        guard Self.shows(level.context) else { return }
        if let edge, !edge.width.isFinite { return }
        let reach: CGFloat = edge.map { CGFloat($0.width) * scale } ?? 0
        let tint: Color? = reach > 0.05 ? edge.flatMap { Self.color($0.color) } : nil
        let stamps: [CGSize] = tint == nil ? [] : Self.ring(reach)
        layer(level) { inner in
            if let tint {
                let full = inner.transform
                var edged = inner
                edged.clipToLayer { mask in
                    mask.opacity = 1
                    mask.blendMode = .normal
                    for stamp in stamps {
                        var moved = mask
                        moved.transform = full.concatenating(CGAffineTransform(translationX: stamp.width, y: stamp.height))
                        self.play(ops, on: Level(context: moved))
                    }
                }
                edged.transform = .identity
                edged.fill(Path(Self.everywhere), with: GraphicsContext.Shading.color(tint))
            }
            self.play(ops, on: Level(context: inner))
        }
    }

    /// Where a group is stamped for an edge `reach` points wide, in the canvas's points: in its own place (the edge's
    /// color lies under all of it, and shows through what is faint in it), at eight places round it, twelve for a wide
    /// one, and six more half way out, for a thin part of the group to leave no gap between itself and its edge.
    private static func ring(_ reach: CGFloat) -> [CGSize] {
        var out: [CGSize] = [.zero]
        func round(_ radius: CGFloat, _ count: Int) {
            for i in 0..<count {
                let angle = 2 * CGFloat.pi * CGFloat(i) / CGFloat(count)
                out.append(CGSize(width: radius * cos(angle), height: radius * sin(angle)))
            }
        }
        let wide = reach > 2.5
        round(reach, wide ? 12 : 8)
        if wide { round(reach / 2, 6) }
        return out
    }

    /// A rectangle that covers any canvas, whatever lies on it.
    private static let everywhere = CGRect(x: -20000, y: -20000, width: 40000, height: 40000)

    /// Whether anything drawn on the context could be seen.
    private static func shows(_ context: GraphicsContext) -> Bool {
        let t = context.transform
        let area = t.a * t.d - t.b * t.c
        return context.opacity > 0 && area.isFinite && abs(area) > 1e-12
    }

    // MARK: The pictures and the symbols

    private func resolved(_ picture: OpeningPicture) -> GraphicsContext.ResolvedImage? {
        if let known = images[picture] { return known }
        let image: Image
        if let ready = pictures[picture] {
            image = Image(uiImage: ready)
        } else {
            image = Image(picture.asset)
        }
        let resolved = source.resolve(image.interpolation(.high))
        images[picture] = resolved
        return resolved
    }

    private func resolved(_ id: OpeningSymbol) -> GraphicsContext.ResolvedSymbol? {
        if let known = symbols[id] { return known }
        guard let resolved = source.resolveSymbol(id: id) else { return nil }
        symbols[id] = resolved
        return resolved
    }

    private static func symbol(of mark: OpeningDialMark) -> OpeningSymbol {
        switch mark {
        case .start: return .start
        case .knob: return .knob
        case .flag: return .flag
        }
    }

    // MARK: The list's values as SwiftUI's

    /// A color, nil if a part of it is not a number.
    private static func color(_ color: OpeningColor) -> Color? {
        guard color.r.isFinite, color.g.isFinite, color.b.isFinite, color.a.isFinite else { return nil }
        return Color(.sRGB, red: color.r / 255, green: color.g / 255, blue: color.b / 255, opacity: color.a)
    }

    private static func gradient(_ stops: [OpeningStop]) -> Gradient? {
        var out: [Gradient.Stop] = []
        for stop in stops {
            guard stop.at.isFinite, let color = Self.color(stop.color) else { return nil }
            out.append(Gradient.Stop(color: color, location: CGFloat(stop.at)))
        }
        return out.isEmpty ? nil : Gradient(stops: out)
    }

    private static func shading(_ paint: OpeningPaint) -> GraphicsContext.Shading? {
        switch paint {
        case .color(let color):
            guard let tint = Self.color(color) else { return nil }
            return GraphicsContext.Shading.color(tint)
        case .linear(let x0, let y0, let x1, let y1, let stops):
            guard x0.isFinite, y0.isFinite, x1.isFinite, y1.isFinite, let gradient = Self.gradient(stops) else { return nil }
            return GraphicsContext.Shading.linearGradient(gradient, startPoint: CGPoint(x: x0, y: y0), endPoint: CGPoint(x: x1, y: y1))
        case .radial(let x, let y, let r0, let r1, let stops):
            guard x.isFinite, y.isFinite, r0.isFinite, r1.isFinite, let gradient = Self.gradient(stops) else { return nil }
            return GraphicsContext.Shading.radialGradient(gradient, center: CGPoint(x: x, y: y), startRadius: CGFloat(r0), endRadius: CGFloat(r1))
        }
    }

    private static func cap(_ cap: OpeningPen.Cap) -> CGLineCap {
        switch cap {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        }
    }

    private static func join(_ join: OpeningPen.Join) -> CGLineJoin {
        switch join {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        }
    }

    /// A path, piece by piece as OpeningPath says each is laid; nil if a number of it is not a number.
    private static func shape(_ path: OpeningPath) -> Path? {
        var out = Path()
        for element in path.elements {
            switch element {
            case .move(let x, let y):
                guard x.isFinite, y.isFinite else { return nil }
                out.move(to: CGPoint(x: x, y: y))
            case .line(let x, let y):
                guard x.isFinite, y.isFinite else { return nil }
                out.addLine(to: CGPoint(x: x, y: y))
            case .quad(let cx, let cy, let x, let y):
                guard cx.isFinite, cy.isFinite, x.isFinite, y.isFinite else { return nil }
                out.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: cx, y: cy))
            case .cubic(let c1x, let c1y, let c2x, let c2y, let x, let y):
                guard c1x.isFinite, c1y.isFinite, c2x.isFinite, c2y.isFinite, x.isFinite, y.isFinite else { return nil }
                out.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: c1x, y: c1y), control2: CGPoint(x: c2x, y: c2y))
            case .arc(let x, let y, let r, let start, let delta):
                guard x.isFinite, y.isFinite, r.isFinite, start.isFinite, delta.isFinite else { return nil }
                out.addRelativeArc(center: CGPoint(x: x, y: y), radius: CGFloat(r), startAngle: .radians(start), delta: .radians(delta))
            case .ellipse(let x, let y, let rx, let ry, let rotation, let start, let delta):
                guard x.isFinite, y.isFinite, rx.isFinite, ry.isFinite, rotation.isFinite, start.isFinite, delta.isFinite else { return nil }
                // a circle of radius 1 round nothing, scaled to the two radii, then turned, then moved to its place
                let placed = CGAffineTransform(translationX: CGFloat(x), y: CGFloat(y))
                let turned = placed.rotated(by: CGFloat(rotation))
                let sized = turned.scaledBy(x: CGFloat(rx), y: CGFloat(ry))
                out.addRelativeArc(center: .zero, radius: 1, startAngle: .radians(start), delta: .radians(delta), transform: sized)
            case .roundRect(let x, let y, let w, let h, let r):
                guard x.isFinite, y.isFinite, w.isFinite, h.isFinite, r.isFinite else { return nil }
                roundRect(&out, x, y, w, h, r)
            case .close:
                out.closeSubpath()
            }
        }
        return out
    }

    /// A rectangle with round corners, a closed piece of its own, clockwise on the screen from its top edge: written
    /// out, as OpeningPath does, for the way it runs to be the list's and not a framework's.
    private static func roundRect(_ out: inout Path, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) {
        let right = x + w
        let bottom = y + h
        guard r > 0 else {
            out.move(to: CGPoint(x: x, y: y))
            out.addLine(to: CGPoint(x: right, y: y))
            out.addLine(to: CGPoint(x: right, y: bottom))
            out.addLine(to: CGPoint(x: x, y: bottom))
            out.closeSubpath()
            return
        }
        let radius = CGFloat(r)
        let quarter = Angle.radians(Double.pi / 2)
        out.move(to: CGPoint(x: x + r, y: y))
        out.addLine(to: CGPoint(x: right - r, y: y))
        out.addRelativeArc(center: CGPoint(x: right - r, y: y + r), radius: radius, startAngle: .radians(-Double.pi / 2), delta: quarter)
        out.addLine(to: CGPoint(x: right, y: bottom - r))
        out.addRelativeArc(center: CGPoint(x: right - r, y: bottom - r), radius: radius, startAngle: .radians(0), delta: quarter)
        out.addLine(to: CGPoint(x: x + r, y: bottom))
        out.addRelativeArc(center: CGPoint(x: x + r, y: bottom - r), radius: radius, startAngle: .radians(Double.pi / 2), delta: quarter)
        out.addLine(to: CGPoint(x: x, y: y + r))
        out.addRelativeArc(center: CGPoint(x: x + r, y: y + r), radius: radius, startAngle: .radians(Double.pi), delta: quarter)
        out.closeSubpath()
    }
}
