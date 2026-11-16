import Foundation

/// The colors an opening is drawn in: the app's, light or dark. The app fills one from its real colors as they
/// are on the screen; `light` and `dark` here are the same colors written out, for the checks and for a picture of
/// a scene where there is no screen to ask.
struct OpeningTheme: Equatable {
    /// The dark look: the man is then drawn with an edge round him (`edge`).
    var dark: Bool
    /// The screens' background, and a card on it.
    var background: OpeningColor
    var card: OpeningColor
    /// The app's accent, the teal.
    var accent: OpeningColor
    /// The logo's lines, its nine ticks: navy on the light icon, white on the dark one.
    var line: OpeningColor
    /// The icon's ground, at its top and at its bottom.
    var groundTop: OpeningColor
    var groundBottom: OpeningColor
    /// The faint line inside the light icon's edge; clear in the dark, which has none.
    var hairline: OpeningColor
    /// The shadow an icon's tile casts.
    var shade: OpeningColor
    /// The dial: its track, an hour's tick and a minute's, and its four numerals.
    var track: OpeningColor
    var tickBig: OpeningColor
    var tickSmall: OpeningColor
    var numerals: OpeningColor
    /// The screen's words, and its lesser words.
    var ink: OpeningColor
    var gray: OpeningColor
    var orange: OpeningColor
    var red: OpeningColor
    /// The brand's yellow, the man's skin and his hair: the same in both looks.
    var yellow: OpeningColor
    var skin: OpeningColor
    var hair: OpeningColor
    /// The edge round the man's whole silhouette in the dark look, for his navy lines to read on the dark ground,
    /// as the dark icon has it (scripts/icons.py): its color, and its width as a share of the icon's side. Nil in
    /// the light look.
    var edge: OpeningColor?
    var edgeShare: Double

    /// The app in its light look: the colors the openings were designed in.
    static let light = OpeningTheme(
        dark: false,
        background: OpeningColor(hex: 0xF4F5F7), card: OpeningColor(hex: 0xFFFFFF),
        accent: OpeningColor(hex: 0x0F9D8F), line: OpeningColor(hex: 0x0A1435),
        groundTop: OpeningColor(hex: 0xFFFFFF), groundBottom: OpeningColor(hex: 0xECEFF6),
        hairline: OpeningColor(0, 0, 0, 0.07), shade: OpeningColor(10, 20, 53),
        track: OpeningColor(0, 0, 0, 0.06), tickBig: OpeningColor(60, 60, 67, 0.6),
        tickSmall: OpeningColor(60, 60, 67, 0.27), numerals: OpeningColor(60, 60, 67, 0.42),
        ink: OpeningColor(hex: 0x0B0C0E), gray: OpeningColor(hex: 0x6C7077),
        orange: OpeningColor(hex: 0xFF9500), red: OpeningColor(hex: 0xFF3B30),
        yellow: OpeningColor(hex: 0xFEC802), skin: OpeningColor(hex: 0xFDDDC1), hair: OpeningColor(hex: 0x1B3168),
        edge: nil, edgeShare: 0.018)

    /// The app in its dark look: its dark background and accent (Assets.xcassets), the dark icon's ground and white
    /// ticks, and the dial as SwiftUI's primary and secondary draw it in the dark.
    static let dark = OpeningTheme(
        dark: true,
        background: OpeningColor(hex: 0x15171C), card: OpeningColor(33, 36, 41),
        accent: OpeningColor(hex: 0x1BB3A3), line: OpeningColor(hex: 0xFFFFFF),
        groundTop: OpeningColor(hex: 0x22252E), groundBottom: OpeningColor(hex: 0x0B0C10),
        hairline: .clear, shade: OpeningColor(0, 0, 0),
        track: OpeningColor(255, 255, 255, 0.06), tickBig: OpeningColor(235, 235, 245, 0.6),
        tickSmall: OpeningColor(235, 235, 245, 0.27), numerals: OpeningColor(235, 235, 245, 0.3),
        ink: OpeningColor(hex: 0xFFFFFF), gray: OpeningColor(235, 235, 245, 0.6),
        orange: OpeningColor(255, 159, 10), red: OpeningColor(255, 69, 58),
        yellow: OpeningColor(hex: 0xFEC802), skin: OpeningColor(hex: 0xFDDDC1), hair: OpeningColor(hex: 0x1B3168),
        edge: .white, edgeShare: 0.018)
}

/// The shift on the Now screen's dial, as an opening needs to know it: what the dial will show once the opening is
/// over. The app makes one of its own layout (Core/Dial.swift) with each piece's color as it is on the screen.
/// Angles are degrees; `start` clockwise from 12, the rest counted from `start` on.
struct OpeningLayout: Equatable {
    /// A piece of the arc.
    struct Piece: Equatable {
        var from: Double
        var to: Double
        var color: OpeningColor
        /// Ahead of now: the time to the goal, a plan's pieces, a day off's whole round. The others are behind
        /// now: time worked, breaks, the day's finished shifts.
        var ahead: Bool

        init(_ from: Double, _ to: Double, _ color: OpeningColor, ahead: Bool = false) {
            self.from = from
            self.to = to
            self.color = color
            self.ahead = ahead
        }
    }

    /// Where the arc starts on the dial.
    var start: Double
    var pieces: [Piece]
    /// Now: where the knob stands.
    var now: Double
    /// The goal, with a shift running; nil with none, and then the dial has no start mark and no flag, only the knob.
    var goal: Double?
    /// Where the flag stands: at the goal, or with a plan at the time to leave.
    var flag: Double?
    /// The knob's ring and dot: the accent on a shift, orange on a break, gold past the goal, gray with none
    /// running, a day off's color.
    var knob: OpeningColor
    /// The flag's color: the accent, or a plan's.
    var flagColor: OpeningColor
    /// The goal reached, with no plan: the app's flag is then a white check on a disc in the accent, not a flag on
    /// a white one. The flag is the app's own view either way (OpeningPen's `mark`); this is for a scene whose own
    /// shape becomes the flag's disc, and for the checks' pictures.
    var reached = false

    /// Where the pieces behind now end: now itself on a shift, the last finished shift's end with none running, 0
    /// with nothing behind.
    var worked: Double {
        pieces.filter { !$0.ahead }.map(\.to).max() ?? 0
    }

    /// Where the last piece ends.
    var end: Double {
        pieces.map(\.to).max() ?? 0
    }

    /// Where the flag stands, if there is one.
    var flagAt: Double? {
        goal == nil ? nil : flag ?? goal
    }

    /// The shift the openings were designed on: since 08:30, five hours and forty-two minutes in, the goal at
    /// 16:54.
    static func mock(_ theme: OpeningTheme) -> OpeningLayout {
        OpeningLayout(start: 255,
                      pieces: [Piece(0, 171, theme.accent), Piece(171, 252, theme.accent.alpha(0.18), ahead: true)],
                      now: 171, goal: 252, flag: 252, knob: theme.accent, flagColor: theme.accent)
    }
}

/// A rectangle of the screen.
struct OpeningRect: Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    /// The screen the openings were designed on.
    static let design = OpeningRect(x: 0, y: 0, w: 402, h: 874)
    /// The card of facts under the dial, on that screen.
    static let facts = OpeningRect(x: 20, y: 482, w: 362, h: 76)

    /// The rectangle with `d` more on every side.
    func grown(_ d: Double) -> OpeningRect {
        OpeningRect(x: x - d, y: y - d, w: w + 2 * d, h: h + 2 * d)
    }

    var path: OpeningPath { .rect(x, y, w, h) }
}
