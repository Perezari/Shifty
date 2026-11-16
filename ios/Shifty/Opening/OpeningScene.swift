import Foundation

/// A tap of the iPhone during an opening: when, in seconds, and how.
struct OpeningHaptic: Equatable {
    enum Style: String {
        case light, medium, rigid, success
    }

    var at: Double
    var style: Style

    init(_ at: Double, _ style: Style) {
        self.at = at
        self.style = style
    }
}

/// One frame of an opening: what is drawn under the Now screen's parts and over them (two lists of operations, each
/// played from a clean state: OpeningPen), each part's state (a part not named is hidden), and how much of the time
/// and the pay the dial's middle shows, from 0 to 1 (nil: as they are). In the frames from a scene's `rest` on, the
/// lists hold the finished dial alone and every part is whole in its place: the app can change the canvas for its
/// own views there.
struct OpeningFrame {
    var under: [OpeningPen.Op]
    var over: [OpeningPen.Op]
    var parts: [OpeningScreenPart: OpeningPartState]
    var counted: Double?
}

/// An opening: the seconds from the launch picture (the icon, 120 points, in the screen's middle) to the Now
/// screen. A scene draws the whole frame of a moment from nothing, by the moment alone: no state is kept between
/// frames, and frames may be asked for in any order.
///
/// Its first frame is the launch picture and nothing else (`OpeningKit.launch`); from `rest` on, every frame is
/// the finished Now screen (`OpeningKit.dial` with nothing told, and every part shown in its place).
protocol OpeningScene {
    /// A short Latin name: the one kept in the settings.
    var id: String { get }
    /// Its name in the picker, and a line or two on what one sees.
    var name: String { get }
    var about: String { get }
    /// The moment everything has settled on the Now screen, in seconds.
    var rest: Double { get }
    /// When a loop of it starts again: `rest` and a good look at the Now screen.
    var end: Double { get }
    var haptics: [OpeningHaptic] { get }
    /// The moment by which the icon has left the launch picture's place. iOS leaves the icon in the real screen's
    /// middle, which is not everywhere the design's 437 points down: the app eases that difference away from the
    /// first frame to this moment.
    var arrive: Double { get }
    /// A moment that shows the scene's idea in one still, for a small picture of it.
    var poster: Double { get }

    /// Draws the frame of the moment `t`, in seconds since the opening began (0 or more).
    func draw(_ t: Double, _ K: OpeningKit)
}

extension OpeningScene {
    var arrive: Double { 0.6 }

    /// The frame of the moment `t` for a dial, in a theme, on a screen with its card of facts (both in the
    /// design's points).
    func frame(at t: Double, layout: OpeningLayout, theme: OpeningTheme, screen: OpeningRect = .design,
               facts: OpeningRect = .facts, asMock: Bool = false) -> OpeningFrame {
        let kit = OpeningKit(layout: layout, theme: theme, screen: screen, facts: facts, asMock: asMock)
        draw(max(0, t), kit)
        return OpeningFrame(under: kit.g.ops, over: kit.o.ops, parts: kit.parts, counted: kit.counted)
    }
}

/// The launch picture alone: what every opening's first frame is.
struct OpeningLaunchScene: OpeningScene {
    let id = "launch"
    let name = "מסך הפתיחה"
    let about = "האייקון במרכז המסך, כפי ש־iOS משאיר אותו."
    let rest = 0.0
    let end = 0.0
    let haptics: [OpeningHaptic] = []
    let poster = 0.0

    func draw(_ t: Double, _ K: OpeningKit) {
        K.launch()
    }
}

/// The finished Now screen alone: what every opening's frames are from its `rest` on.
struct OpeningDoneScene: OpeningScene {
    let id = "done"
    let name = "המסך המוכן"
    let about = "מסך עכשיו כשהוא שלם."
    let rest = 0.0
    let end = 0.0
    let haptics: [OpeningHaptic] = []
    let poster = 0.0

    func draw(_ t: Double, _ K: OpeningKit) {
        K.dial()
        for id in K.PARTS { K.part(id, 1, 0) }
    }
}
