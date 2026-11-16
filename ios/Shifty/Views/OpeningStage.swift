import SwiftUI
import UIKit

// One of the man's openings on the real screen. A scene (Opening/Scenes, drawn with the kit in Opening/) gives each
// moment's frame from nothing: two lists of drawing operations, one under the Now screen's parts and one over them,
// and each part's state. Here is its host: where the scenes' design lies on this iPhone's screen, the day and the
// colors they are told, the frame of each tick of the display (made once, for the two canvases and the parts
// alike), the canvases, and the Now screen's own parts following the frame. Opening.swift decides whether an opening
// is shown at all, begins it and ends it; with the classic opening nothing here is used.

/// The scenes' design (a screen of 402 x 874 points: OpeningKit) laid on the real screen: a point of the design times
/// `scale`, moved by x, y, is a point of the screen, in the global space.
struct OpeningPlace: Equatable {
    var scale: CGFloat
    var x: CGFloat
    var y: CGFloat

    /// The design's point `design` on the screen's point `point`, at a scale.
    init(scale: CGFloat, design: CGPoint, on point: CGPoint) {
        self.scale = scale
        x = point.x - design.x * scale
        y = point.y - design.y * scale
    }

    /// As the launch picture is: the icon at its own size, its middle (201, 437 in the design) in the screen's.
    static func launch(screen: CGRect) -> OpeningPlace {
        let icon = OpeningLaunchPlace()
        return OpeningPlace(scale: 1, design: CGPoint(x: icon.x, y: icon.y), on: CGPoint(x: screen.midX, y: screen.midY))
    }

    /// As the Now screen is: the design's dial (its middle at 201, 293, its size 350) on the real one, which is
    /// smaller on a narrow iPhone.
    static func settled(dial: CGRect) -> OpeningPlace {
        OpeningPlace(scale: dial.width / 350, design: CGPoint(x: 201, y: 293), on: CGPoint(x: dial.midX, y: dial.midY))
    }

    /// `k` of the way to another place, from 0 to 1.
    func eased(to other: OpeningPlace, _ k: CGFloat) -> OpeningPlace {
        var out = self
        out.scale = scale + (other.scale - scale) * k
        out.x = x + (other.x - x) * k
        out.y = y + (other.y - y) * k
        return out
    }

    /// A rectangle of the screen, in the design's points.
    func design(_ rect: CGRect) -> OpeningRect {
        let left = Double((rect.minX - x) / scale)
        let top = Double((rect.minY - y) / scale)
        return OpeningRect(x: left, y: top, w: Double(rect.width / scale), h: Double(rect.height / scale))
    }
}

/// The dial's marks as the Now screen has them now, for the canvases to draw them with the app's own views
/// (DialMarks.swift): the knob's color, the flag's, and whether the flag is a check.
struct OpeningMarksLook: Equatable {
    var knob: Color
    var flag: Color
    var reached: Bool
}

/// What a scene is told of the Now screen it ends on: the day on the dial, the colors, and the marks' look.
struct OpeningDay: Equatable {
    var layout: OpeningLayout
    var theme: OpeningTheme
    var marks: OpeningMarksLook

    /// The dial as ShiftDial draws it, in an environment's colors: each piece with its color as numbers and whether
    /// it is ahead of now, the flag where it stands (at the goal, or with a plan at the time to leave), the knob's
    /// color and the flag's.
    init(_ dial: DialLayout, reached: Bool, knob: Color, flag: Color, in environment: EnvironmentValues) {
        let pieces = dial.pieces.map { piece -> OpeningLayout.Piece in
            let color = OpeningColor(piece.kind.color.resolve(in: environment))
            return OpeningLayout.Piece(piece.from, piece.to, color, ahead: piece.kind.isAhead)
        }
        let stands: Double? = dial.goalDeg == nil ? nil : (dial.leaveDeg ?? dial.goalDeg)
        layout = OpeningLayout(start: dial.startDeg, pieces: pieces, now: dial.nowDeg, goal: dial.goalDeg, flag: stands,
                               knob: OpeningColor(knob.resolve(in: environment)),
                               flagColor: OpeningColor(flag.resolve(in: environment)), reached: reached)
        theme = OpeningTheme.real(in: environment)
        marks = OpeningMarksLook(knob: knob, flag: flag, reached: reached)
    }
}

extension DialLayout.Kind {
    /// Ahead of now on the dial, as a scene tells the arc's pieces apart: the time to the goal, a plan's pieces, a day
    /// off's whole round. The others are behind now: time worked, breaks, the day's finished shifts.
    var isAhead: Bool {
        switch self {
        case .work, .overtime, .pause, .today: return false
        case .ahead, .short, .plannedOvertime, .dayOff: return true
        }
    }
}

extension OpeningColor {
    /// A color of the app's as it is on the screen: its sRGB red, green and blue from 0 to 255.
    init(_ color: Color.Resolved) {
        /// A part of it, kept within 0...1.
        func share(_ value: Float) -> Double {
            let bounded: Float = min(1, max(0, value))
            return Double(bounded)
        }
        // each read as the number it is: a resolved color is a style too, and has an `opacity(_:)` beside its `opacity`
        let red: Float = color.red
        let green: Float = color.green
        let blue: Float = color.blue
        let alpha: Float = color.opacity
        self.init(share(red) * 255, share(green) * 255, share(blue) * 255, share(alpha))
    }
}

extension OpeningTheme {
    /// The app's colors as they are on the screen, light or dark: its background and its cards, the accent, the
    /// dial's track and ticks as DialFace draws them, the words' colors, orange and red. What the app has no color of
    /// its own for stays as written out in OpeningLook.swift: the logo's lines (navy, white in the dark), the icon's
    /// ground (as Opening.swift has it), the man's edge in the dark, and the dial's numerals, which the app's own
    /// view draws anyway.
    static func real(in environment: EnvironmentValues) -> OpeningTheme {
        func seen(_ color: Color) -> OpeningColor {
            OpeningColor(color.resolve(in: environment))
        }
        var theme = environment.colorScheme == .dark ? OpeningTheme.dark : OpeningTheme.light
        theme.background = seen(Color.appBackground)
        theme.card = seen(Color.cardBackground)
        theme.accent = seen(Color.accentColor)
        theme.track = seen(Color.primary.opacity(0.06))
        theme.tickBig = seen(Color.secondary)
        theme.tickSmall = seen(Color.secondary.opacity(0.45))
        theme.ink = seen(Color.primary)
        theme.gray = seen(Color.secondary)
        theme.orange = seen(Color.orange)
        theme.red = seen(Color.red)
        return theme
    }
}

/// A moment of a scene on the screen: its frame, and where the design lies then.
struct OpeningMoment {
    var frame: OpeningFrame
    var place: OpeningPlace
}

/// A part of the Now screen in a moment, as its view takes it: how much of it is there, how far it is moved on the
/// screen, and its scale about its own middle.
struct OpeningPartLook: Equatable {
    var shown = 1.0
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var scale: CGFloat = 1

    /// As it is on the Now screen.
    static let whole = OpeningPartLook()
    static let hidden = OpeningPartLook(shown: 0)
}

/// The host of a scene. Not observed: the views that draw by it are drawn again with each tick of the display while
/// an opening is on, and by Opening's own changes.
@MainActor
final class OpeningStage {
    static let shared = OpeningStage()

    /// The whole screen, and the real dial in its place, in the global space: the cover and the dial tell them.
    var screen: CGRect?
    var dial: CGRect?
    /// The day on the dial and the colors, as the Now screen has them now (OpeningDialReport).
    var day: OpeningDay?
    /// The card of facts under the dial, in its place, in the global space (OpeningFactsReport): as wide as this
    /// iPhone's screen lets it be, which is not everywhere the design's.
    var facts: CGRect?
    /// Of the scene to play: when its week's card is all but up, in seconds, for the card's bars to grow then; and
    /// whether it counts the time and the pay up in the dial's middle.
    private(set) var weekAt = 0.0
    private(set) var counts = false
    /// The man's pictures, read and made ready to draw before the first frame needs them; let go once it is over.
    private(set) var pictures: [OpeningPicture: UIImage] = [:]

    /// The last moment made, and whether the display's tick it was made in is still on: the tick's other views take
    /// it as it is.
    private var last: OpeningMoment?
    private var fresh = false
    /// What each scene was found to do, by its id.
    private var studied: [String: (week: Double, counts: Bool)] = [:]
    private var warming: Task<Void, Never>?
    private var resting: Task<Void, Never>?

    /// Before an opening: what its scene is asked ahead, and its pictures. With the classic, nothing.
    func ready(for scene: (any OpeningScene)?) {
        resting?.cancel()
        last = nil
        fresh = false
        dial = nil
        day = nil
        facts = nil
        guard let scene else {
            weekAt = 0
            counts = false
            return
        }
        let known = studied[scene.id] ?? Self.study(scene)
        studied[scene.id] = known
        weekAt = known.week
        counts = known.counts
        warm()
    }

    /// A scene's frames gone through once, a tenth of a second apart, on the made-up shift: the first moment its
    /// week's card is all but up, and whether any frame counts. A few thousandths of a second's work.
    private static func study(_ scene: any OpeningScene) -> (week: Double, counts: Bool) {
        let theme = OpeningTheme.light
        let layout = OpeningLayout.mock(theme)
        var week = scene.rest
        var found = false
        var counts = false
        var t = 0.0
        while t <= scene.rest {
            let frame = scene.frame(at: t, layout: layout, theme: theme)
            if !found, let part = frame.parts[.week], part.shown >= 0.8 {
                week = t
                found = true
            }
            if frame.counted != nil { counts = true }
            t += 0.1
        }
        return (week, counts)
    }

    /// The pictures decoded off the main thread, one after another: the first frame draws the whole man, and the
    /// rest of his layers as he first moves.
    private func warm() {
        guard pictures.isEmpty, warming == nil else { return }
        warming = Task {
            for picture in OpeningPicture.allCases {
                guard let image = UIImage(named: picture.asset) else { continue }
                let ready = await image.byPreparingForDisplay()
                if Task.isCancelled { return }
                pictures[picture] = ready ?? image
            }
            warming = nil
        }
    }

    /// The opening is over. Its last frame stays a moment longer, for a skip's canvases to fade away with; then
    /// nothing of it is kept.
    func rest() {
        resting?.cancel()
        resting = Task {
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled, Opening.shared.over else { return }
            last = nil
            warming?.cancel()
            warming = nil
            pictures = [:]
        }
    }

    /// The screen, the dial's place and the day are known: a scene can begin.
    var placed: Bool {
        guard let screen, let dial, day != nil else { return false }
        return screen.width > 0 && dial.width > 0
    }

    /// A frame of the scene has been made for its views: its first is on the canvases, under the still picture.
    var drawn: Bool {
        last != nil
    }

    /// The moment of this tick of the display: the scene's frame and where it lies. Made once for a tick, whichever
    /// of the canvases and the parts asks first, and by one clock: each view's own timeline has a date of its own for
    /// the same tick (each counts a hundred and twentieths of a second from its own beginning), so by their dates the
    /// two canvases and the parts would each be at a moment of its own, up to a tick apart. All the views of a tick
    /// are drawn in one go on the main thread, so the moment stands until the main thread is free again. Time is
    /// real seconds since the scene began; until it begins, its first frame, which is the launch picture, for the
    /// canvases to have it drawn under the still one. The design lies as the launch picture is at first, eases to
    /// its place on the real dial by the scene's `arrive`, and stays; the scene is told the real screen's bounds and
    /// the real card of facts' as they are once it has arrived. Nil with no scene, or before the dial's place is
    /// known; once it is over, the last one made.
    func moment() -> OpeningMoment? {
        let opening = Opening.shared
        guard let scene = opening.scene else { return nil }
        if opening.over || fresh { return last }
        guard let screen, let dial, let day, dial.width > 0 else { return last }
        let t: Double = opening.began.map { max(0, Date().timeIntervalSince($0)) } ?? 0
        let settled = OpeningPlace.settled(dial: dial)
        let share = min(1, max(0, t / max(scene.arrive, 0.001)))
        let place = OpeningPlace.launch(screen: screen).eased(to: settled, CGFloat(OpeningEase.io2(share)))
        // the real card of facts, for a scene that ends on it; the design's until its place is known
        var card = OpeningRect.facts
        if let facts, facts.width > 0, facts.height > 0 {
            card = settled.design(facts)
        }
        let frame = scene.frame(at: t, layout: day.layout, theme: day.theme, screen: settled.design(screen), facts: card)
        let moment = OpeningMoment(frame: frame, place: place)
        last = moment
        fresh = true
        // after this tick's views, before the next one's
        Task { fresh = false }
        return moment
    }

    /// A part of the Now screen at this tick of the display: as the scene's frame has it, its move in the screen's
    /// points; hidden if the frame does not name it, as the first one names none; whole once the opening is over.
    func look(of part: OpeningScreenPart?) -> OpeningPartLook {
        let opening = Opening.shared
        guard opening.scene != nil, !opening.over else { return .whole }
        guard let part, let dial, let state = moment()?.frame.parts[part] else { return .hidden }
        guard state.shown.isFinite, state.dx.isFinite, state.dy.isFinite, state.scale.isFinite else { return .hidden }
        let host = dial.width / 350
        // never quite no size, as a scale of nothing draws badly
        let scale = max(0.001, CGFloat(state.scale))
        return OpeningPartLook(shown: min(1, max(0, state.shown)), dx: CGFloat(state.dx) * host, dy: CGFloat(state.dy) * host,
                               scale: scale)
    }
}

/// The iPhone's taps in a scene: UIKit's generators, one for each kind of tap, each readied a little before its
/// moment.
@MainActor
final class OpeningTaps {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let success = UINotificationFeedbackGenerator()

    func ready(_ style: OpeningHaptic.Style) {
        switch style {
        case .light: light.prepare()
        case .medium: medium.prepare()
        case .rigid: rigid.prepare()
        case .success: success.prepare()
        }
    }

    func play(_ style: OpeningHaptic.Style) {
        switch style {
        case .light: light.impactOccurred()
        case .medium: medium.impactOccurred()
        case .rigid: rigid.impactOccurred()
        case .success: success.notificationOccurred(.success)
        }
    }
}

/// Behind the Now screen's dial while a scene is to play: tells the stage where the dial is on the screen, and the day
/// on it in the colors it has now; again whenever either changes, the iPhone turning dark among them.
struct OpeningDialReport: View {
    let layout: DialLayout
    /// The goal reached, with no plan: the flag is a check.
    let reached: Bool
    let knob: Color
    let flag: Color
    @Environment(\.self) private var environment

    var body: some View {
        let day = OpeningDay(layout, reached: reached, knob: knob, flag: flag, in: environment)
        GeometryReader { proxy in
            Color.clear
                .onChange(of: proxy.frame(in: .global), initial: true) { _, frame in
                    OpeningStage.shared.dial = frame
                }
                .onChange(of: day, initial: true) { _, day in
                    OpeningStage.shared.day = day
                }
        }
    }
}

/// Behind the Now screen's card of facts while a scene is to play: tells the stage where the card is on the screen,
/// in its own place (outside what moves it through the scene), and again whenever that changes.
struct OpeningFactsReport: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onChange(of: proxy.frame(in: .global), initial: true) { _, frame in
                    OpeningStage.shared.facts = frame
                }
        }
    }
}

/// A part of the Now screen while a scene plays: there as much as each frame says, moved and scaled as it says, and
/// once the opening is over as it is (a skip eases it there). The move is the screen's, to the right and down, in the
/// app's right-to-left too: the effects are set left to right, and the part itself keeps its own direction. It is
/// drawn again with each tick of the display only while the opening is on its way: not before the app is in front
/// and unlocked (hidden, it stands still), and not once it is over.
struct OpeningScenePart: ViewModifier {
    let part: OpeningScreenPart?
    @Environment(\.layoutDirection) private var direction

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: nil, paused: Opening.shared.over || !Opening.shared.started)) { _ in
            let look = OpeningStage.shared.look(of: part)
            content
                .environment(\.layoutDirection, direction)
                .opacity(look.shown)
                .scaleEffect(look.scale)
                .offset(x: look.dx, y: look.dy)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}

/// The dial's middle of a running shift while a scene plays: `content` is given the share of the time and the pay to
/// show, from 0 to 1, while the scene counts them up, a frame at a time, and nil otherwise: as they are.
struct OpeningCounted<Content: View>: View {
    @ViewBuilder var content: (Double?) -> Content

    var body: some View {
        let opening = Opening.shared
        let counting: Bool = !opening.over && opening.started && OpeningStage.shared.counts
        TimelineView(.animation(minimumInterval: nil, paused: !counting)) { _ in
            content(counting ? OpeningStage.shared.moment()?.frame.counted : nil)
        }
    }
}

/// Under the Now screen's parts and over its background (NowView): what a scene draws there, the dial first of all,
/// on a canvas the size of the screen. Drawn with each tick of the display from the moment the opening is on its way
/// (the app in front, and unlocked), so that its first frame is there under the still picture before it begins and
/// nothing is drawn again and again behind the lock. Gone once the opening is over.
struct OpeningUnder: View {
    var body: some View {
        let opening = Opening.shared
        if opening.scene != nil, !opening.over {
            TimelineView(.animation(minimumInterval: nil, paused: !opening.started)) { _ in
                OpeningStageCanvas(moment: OpeningStage.shared.moment(), over: false)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}

/// Over everything, the tab bar too (OpeningCover, while a scene is on): what the scene draws over the Now screen's
/// parts; and under that, since the tab bar cannot be hidden itself, the app's background over it, as much as the
/// scene's tabs part is not there yet. Drawn with each tick of the display as OpeningUnder is.
struct OpeningOver: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !Opening.shared.started)) { _ in
            let moment = OpeningStage.shared.moment()
            let tabs: Double = moment?.frame.parts[.tabs]?.shown ?? 0
            let shown: Double = min(1, max(0, tabs))
            ZStack {
                OpeningTabsCover()
                    .opacity(1 - shown)
                OpeningStageCanvas(moment: moment, over: true)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The app's background over the tab bar, its top edge soft: as the classic opening's (Opening.swift's OpeningCurtain).
private struct OpeningTabsCover: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(colors: [Color.appBackground.opacity(0), Color.appBackground], startPoint: .top, endPoint: .bottom)
                .frame(height: 16)
            Color.appBackground
                .frame(height: 106)
        }
    }
}

/// One of a moment's two lists on a canvas that fills what it is given. The two canvases are not assumed to lie alike:
/// each finds its own place on the screen, and lays the design from there.
private struct OpeningStageCanvas: View {
    let moment: OpeningMoment?
    /// The list over the Now screen's parts, or the one under them.
    let over: Bool

    var body: some View {
        if let moment, let day = OpeningStage.shared.day {
            GeometryReader { proxy in
                let origin = proxy.frame(in: .global).origin
                let offset = CGSize(width: moment.place.x - origin.x, height: moment.place.y - origin.y)
                OpeningCanvas(lists: [over ? moment.frame.over : moment.frame.under], scale: moment.place.scale, offset: offset,
                              own: 1 / moment.place.scale, marks: day.marks, pictures: OpeningStage.shared.pictures)
            }
        }
    }
}

/// Lists of an opening's drawing on a canvas, each played from a clean state, one over another: the design lies on the
/// canvas at `scale`, moved by `offset`. The dial's marks and hours are the app's own views, the canvas's symbols:
/// each in a frame that holds its shadow too. Drawn left to right, as the dial is, and with nothing that Dynamic Type
/// sizes.
struct OpeningCanvas: View {
    let lists: [[OpeningPen.Op]]
    let scale: CGFloat
    let offset: CGSize
    /// How large the app's own views are drawn against the design's (OpeningPlayer): one over the scale on the screen,
    /// 1 in a small picture.
    let own: CGFloat
    let marks: OpeningMarksLook
    var pictures: [OpeningPicture: UIImage] = [:]

    var body: some View {
        Canvas { context, _ in
            let player = OpeningPlayer(scale: scale, offset: offset, own: own, pictures: pictures, on: context)
            for list in lists {
                player.play(list)
            }
        } symbols: {
            DialStartMark()
                .tag(OpeningSymbol.start)
            DialKnob(color: marks.knob)
                .frame(width: 72, height: 72)
                .tag(OpeningSymbol.knob)
            DialFlag(color: marks.flag, reached: marks.reached)
                .frame(width: 72, height: 72)
                .tag(OpeningSymbol.flag)
            // the hours of a dial of the design's 350 points, at the size the marks are drawn at
            DialHours(size: 350 / own)
                .tag(OpeningSymbol.hours)
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}
