import Foundation

// The openings' dumper: draws frames of a scene with the kit (ios/Shifty/Opening) and prints them as JSON, for the
// replay page to play on a browser's canvas (replay.js) and the tools to hold against the mock (tools/*.py).
// Built by tools/build.py with the kit, ONE scene's file and a line that names that scene (openingCheckScene),
// so that a scene half written never breaks another's build.
//
//     dump info
//         the scene's own numbers, and the layouts' names
//     dump frames <layout> <light|dark> [screen=x,y,w,h] [facts=x,y,w,h] <scene>@<t>,<t>,... [<scene>@<t>,...] ...
//         the frames of those moments; <scene> is the built scene's id, or `launch`, or `done`
//
// The layouts are days the Now screen's dial can show (Core/Dial.swift), on made-up hours: each as the app would give
// it (Calc.dial's pieces and angles, NowView.swift's colors for each kind of piece, for the knob and for the flag).
//
// A number that is not one (NaN, an infinity) is written as 0, as the kit writes it (OpeningJSON.number); each frame
// says how many of its numbers were such, as "bad", and tools/check.py fails a day that has any.

/// A day on the dial by its name; `mock` is the shift the openings were designed on, with the dial's ticks drawn as
/// the mock draws them, and `running` the same shift with the app's ticks.
func layoutPreset(_ name: String, _ theme: OpeningTheme) -> (layout: OpeningLayout, asMock: Bool)? {
    typealias Piece = OpeningLayout.Piece
    let accent = theme.accent
    // the app's colors (Assets.xcassets, Theme.swift, SwiftUI's own), light and dark
    let gold = theme.dark ? OpeningColor(hex: 0xD8A64E) : OpeningColor(hex: 0xB07D2A)
    let vacation = theme.dark ? OpeningColor(59, 158, 245) : OpeningColor(41, 148, 242)
    let secondary = theme.tickBig
    let ahead = accent.alpha(0.18)
    // a plan's pieces: short of the goal in a pale red, past it in a pale gold
    let short = theme.red.alpha(0.22)
    let longer = gold.alpha(0.4)
    switch name {
    case "mock":
        return (.mock(theme), true)
    case "running":
        return (.mock(theme), false)
    case "idle":
        // nothing today: no pieces, the knob at the clock's time (10:10)
        return (OpeningLayout(start: 305, pieces: [], now: 0, goal: nil, flag: nil, knob: secondary, flagColor: accent), false)
    case "idleToday":
        // two finished shifts today, pale, since 08:00; now 18:20
        return (OpeningLayout(start: 240, pieces: [Piece(0, 120, accent.alpha(0.45)), Piece(150, 255, accent.alpha(0.45))],
                              now: 310, goal: nil, flag: nil, knob: secondary, flagColor: accent), false)
    case "break":
        // work, a break, work again, and the time ahead to a goal the break moved on
        return (OpeningLayout(start: 255, pieces: [Piece(0, 95, accent), Piece(95, 110, theme.orange), Piece(110, 171, accent),
                                                   Piece(171, 267, ahead, ahead: true)],
                              now: 171, goal: 267, flag: 267, knob: accent, flagColor: accent), false)
    case "overtime":
        // an hour past the goal, and a plan to stay another: the flag at the time to leave, a dot left at the goal
        return (OpeningLayout(start: 210, pieces: [Piece(0, 255, accent), Piece(255, 285, gold),
                                                   Piece(285, 315, gold.alpha(0.4), ahead: true)],
                              now: 285, goal: 255, flag: 315, knob: gold, flagColor: gold), false)
    case "dayOff":
        // a vacation day: the whole round in its color, the knob at the clock's time (03:20)
        return (OpeningLayout(start: 100, pieces: [Piece(0, 360, vacation.alpha(0.85), ahead: true)], now: 0, goal: nil,
                              flag: nil, knob: vacation, flagColor: accent), false)
    case "justStarted":
        // four minutes in
        return (OpeningLayout(start: 255, pieces: [Piece(0, 2, accent), Piece(2, 255, ahead, ahead: true)],
                              now: 2, goal: 255, flag: 255, knob: accent, flagColor: accent), false)
    case "nearlyFull":
        // eleven hours in, the goal long behind: the arc has nearly come round to its start
        return (OpeningLayout(start: 300, pieces: [Piece(0, 255, accent), Piece(255, 330, gold)],
                              now: 330, goal: 255, flag: 255, knob: gold, flagColor: accent, reached: true), false)
    case "planShort":
        // the mock's hours with a plan to leave at 15:30, before the goal: the red flag stands mid-way on the time
        // ahead, which is pale up to it and a pale red from it to the goal, where a dot is left
        return (OpeningLayout(start: 255, pieces: [Piece(0, 171, accent), Piece(171, 210, ahead, ahead: true),
                                                   Piece(210, 255, short, ahead: true)],
                              now: 171, goal: 255, flag: 210, knob: accent, flagColor: theme.red), false)
    case "leaveNow":
        // that plan come due this minute: the flag on the knob, and nothing ahead but the pale red to the goal
        return (OpeningLayout(start: 255, pieces: [Piece(0, 210, accent), Piece(210, 255, short, ahead: true)],
                              now: 210, goal: 255, flag: 210, knob: accent, flagColor: theme.red), false)
    case "reachedJust":
        // the goal reached three minutes ago, no plan: the check a degree and a half behind the knob, the overtime
        // just begun
        return (OpeningLayout(start: 240, pieces: [Piece(0, 255, accent), Piece(255, 256.5, gold)],
                              now: 256.5, goal: 255, flag: 255, knob: gold, flagColor: accent, reached: true), false)
    case "fullRing":
        // a shift of twelve hours and more: now is 360, where the app stops it, and the knob is back on the start
        return (OpeningLayout(start: 210, pieces: [Piece(0, 255, accent), Piece(255, 360, gold)],
                              now: 360, goal: 255, flag: 255, knob: gold, flagColor: accent, reached: true), false)
    case "startNow":
        // started this very second: now is 0, nothing is worked yet, the knob stands on the start
        return (OpeningLayout(start: 255, pieces: [Piece(0, 255, ahead, ahead: true)],
                              now: 0, goal: 255, flag: 255, knob: accent, flagColor: accent), false)
    case "startAtTop":
        // since 12:00 sharp, three and a half hours in: the app gives such a start as 0, never as 360
        return (OpeningLayout(start: 0, pieces: [Piece(0, 105, accent), Piece(105, 255, ahead, ahead: true)],
                              now: 105, goal: 255, flag: 255, knob: accent, flagColor: accent), false)
    case "eveningAfter":
        // no shift running, one finished this morning (07:00 to 11:00), pale; the knob far on, at the clock's 18:30
        return (OpeningLayout(start: 210, pieces: [Piece(0, 120, accent.alpha(0.45))],
                              now: 345, goal: nil, flag: nil, knob: secondary, flagColor: accent), false)
    case "nightAfter":
        // no shift running, a day's work finished (08:00 to 17:00), pale, and thirteen hours since it began: now is
        // 360, where the app stops it, so the knob stands where the arc starts, on the pale arc's own beginning
        return (OpeningLayout(start: 240, pieces: [Piece(0, 270, accent.alpha(0.45))],
                              now: 360, goal: nil, flag: nil, knob: secondary, flagColor: accent), false)
    case "planLong":
        // a plan to stay an hour past the goal, set before the goal is reached: the time ahead pale to the goal,
        // where the plan's dot stands mid-way, and a pale gold from there to the gold flag
        return (OpeningLayout(start: 255, pieces: [Piece(0, 171, accent), Piece(171, 255, ahead, ahead: true),
                                                   Piece(255, 285, longer, ahead: true)],
                              now: 171, goal: 255, flag: 285, knob: accent, flagColor: gold), false)
    case "overdue":
        // past the goal, and a plan to stay on that has come due: the gold flag on the knob, the dot behind it at
        // the goal, and ahead the piece of no length at all that the app then gives
        return (OpeningLayout(start: 210, pieces: [Piece(0, 255, accent), Piece(255, 285, gold),
                                                   Piece(285, 285, longer, ahead: true)],
                              now: 285, goal: 255, flag: 285, knob: gold, flagColor: gold), false)
    case "onBreak":
        // on a break since 13:30, for twenty-four minutes now: the break's orange ends at the knob, which is orange
        // too, and the goal has moved on by as much
        return (OpeningLayout(start: 255, pieces: [Piece(0, 150, accent), Piece(150, 162, theme.orange),
                                                   Piece(162, 267, ahead, ahead: true)],
                              now: 162, goal: 267, flag: 267, knob: theme.orange, flagColor: accent), false)
    default:
        return nil
    }
}

let layoutNames = ["mock", "running", "idle", "idleToday", "break", "overtime", "dayOff", "justStarted", "nearlyFull",
                   "planShort", "leaveNow", "reachedJust", "fullRing", "startNow", "startAtTop", "eveningAfter",
                   "planLong", "overdue", "onBreak", "nightAfter"]

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(2)
}

func json(_ theme: OpeningTheme) -> String {
    let colors: [(String, OpeningColor)] = [
        ("background", theme.background), ("card", theme.card), ("accent", theme.accent), ("line", theme.line),
        ("groundTop", theme.groundTop), ("groundBottom", theme.groundBottom), ("hairline", theme.hairline),
        ("shade", theme.shade), ("track", theme.track), ("tickBig", theme.tickBig), ("tickSmall", theme.tickSmall),
        ("numerals", theme.numerals), ("ink", theme.ink), ("gray", theme.gray), ("orange", theme.orange), ("red", theme.red),
    ]
    return "{\"dark\":\(theme.dark)," + colors.map { "\"\($0.0)\":\($0.1.json)" }.joined(separator: ",") + "}"
}

func json(_ layout: OpeningLayout) -> String {
    func optional(_ x: Double?) -> String { x.map(OpeningJSON.number) ?? "null" }
    let pieces = layout.pieces.map { "[\(OpeningJSON.numbers([$0.from, $0.to])),\($0.color.json),\($0.ahead)]" }
    return "{\"start\":\(OpeningJSON.number(layout.start)),\"now\":\(OpeningJSON.number(layout.now)),\"goal\":\(optional(layout.goal)),"
        + "\"flag\":\(optional(layout.flagAt)),\"worked\":\(OpeningJSON.number(layout.worked)),\"end\":\(OpeningJSON.number(layout.end)),"
        + "\"knob\":\(layout.knob.json),\"flagColor\":\(layout.flagColor.json),\"reached\":\(layout.reached),"
        + "\"pieces\":[" + pieces.joined(separator: ",") + "]}"
}

func json(_ scene: OpeningScene) -> String {
    let taps = scene.haptics.map { "[\(OpeningJSON.number($0.at)),\"\($0.style.rawValue)\"]" }.joined(separator: ",")
    return "\"scene\":\(OpeningJSON.text(scene.id)),\"name\":\(OpeningJSON.text(scene.name)),\"about\":\(OpeningJSON.text(scene.about)),"
        + "\"rest\":\(OpeningJSON.number(scene.rest)),\"end\":\(OpeningJSON.number(scene.end)),\"arrive\":\(OpeningJSON.number(scene.arrive)),"
        + "\"poster\":\(OpeningJSON.number(scene.poster)),\"haptics\":[\(taps)]"
}

// MARK: - Numbers that are not numbers
//
// A scene that divides by an angle of the day's which is 0 (the mock's `ridden / DIAL.now`) makes a NaN or an
// infinity. The JSON has it as 0, and the shape lands at the screen's corner or is not drawn, without a word. So
// every number a frame writes is looked at here: the same ones the kit's `json` writes, and no others. What the pen
// or the kit has bounded before it reached the list is not seen, being a number by then: a color's parts and its
// alpha, a radius (an arc's, a shadow's, a blur's), an edge's width, K.clamp and so K.seg, a part's `shown` and
// K.count all make 0 of a NaN, and the pen's `alpha` does not take one at all.

/// How many of these are not numbers: NaN, or an infinity.
func notFinite(_ numbers: Double...) -> Int {
    numbers.filter { !$0.isFinite }.count
}

func notFinite(_ color: OpeningColor) -> Int {
    notFinite(color.r, color.g, color.b, color.a)
}

func notFinite(_ paint: OpeningPaint) -> Int {
    func each(_ stops: [OpeningStop]) -> Int {
        stops.reduce(0) { $0 + notFinite($1.at) + notFinite($1.color) }
    }
    switch paint {
    case .color(let color):
        return notFinite(color)
    case .linear(let x0, let y0, let x1, let y1, let stops):
        return notFinite(x0, y0, x1, y1) + each(stops)
    case .radial(let x, let y, let r0, let r1, let stops):
        return notFinite(x, y, r0, r1) + each(stops)
    }
}

func notFinite(_ path: OpeningPath) -> Int {
    path.elements.reduce(0) { sum, element in
        switch element {
        case .move(let x, let y), .line(let x, let y):
            return sum + notFinite(x, y)
        case .quad(let cx, let cy, let x, let y):
            return sum + notFinite(cx, cy, x, y)
        case .cubic(let c1x, let c1y, let c2x, let c2y, let x, let y):
            return sum + notFinite(c1x, c1y, c2x, c2y, x, y)
        case .arc(let x, let y, let r, let start, let delta):
            return sum + notFinite(x, y, r, start, delta)
        case .ellipse(let x, let y, let rx, let ry, let rotation, let start, let delta):
            return sum + notFinite(x, y, rx, ry, rotation, start, delta)
        case .roundRect(let x, let y, let w, let h, let r):
            return sum + notFinite(x, y, w, h, r)
        case .close:
            return sum
        }
    }
}

func notFinite(_ ops: [OpeningPen.Op]) -> Int {
    ops.reduce(0) { sum, op in
        switch op {
        case .save, .restore, .mark:
            return sum
        case .translate(let x, let y), .scale(let x, let y):
            return sum + notFinite(x, y)
        case .rotate(let x), .alpha(let x), .blur(let x), .hours(let x):
            return sum + notFinite(x)
        case .clip(let path, _):
            return sum + notFinite(path)
        case .fill(let path, let paint, _):
            return sum + notFinite(path) + notFinite(paint)
        case .stroke(let path, let paint, let width, _, _):
            return sum + notFinite(path) + notFinite(paint) + notFinite(width)
        case .image(_, let x, let y, let w, let h):
            return sum + notFinite(x, y, w, h)
        case .shadow(let color, let radius, let dx, let dy):
            return sum + notFinite(color) + notFinite(radius, dx, dy)
        case .group(let edge, let inside):
            return sum + (edge.map { notFinite($0.color) + notFinite($0.width) } ?? 0) + notFinite(inside)
        }
    }
}

/// How many numbers of a frame are not numbers: in its two lists, in its parts' states and in its count.
func notFinite(_ frame: OpeningFrame) -> Int {
    let parts = OpeningScreenPart.allCases.reduce(0) { sum, id in
        let s = frame.parts[id] ?? OpeningPartState()
        return sum + notFinite(s.shown, s.dx, s.dy, s.scale)
    }
    return notFinite(frame.under) + notFinite(frame.over) + parts + (frame.counted.map { notFinite($0) } ?? 0)
}

func json(_ frame: OpeningFrame, at t: Double) -> String {
    let parts = OpeningScreenPart.allCases.map { id -> String in
        let s = frame.parts[id] ?? OpeningPartState()
        return "\"\(id.rawValue)\":[\(OpeningJSON.numbers([s.shown, s.dx, s.dy, s.scale]))]"
    }
    return "{\"t\":\(OpeningJSON.number(t)),\"under\":\(OpeningJSON.list(frame.under)),\"over\":\(OpeningJSON.list(frame.over)),"
        + "\"parts\":{" + parts.joined(separator: ",") + "},\"count\":\(frame.counted.map(OpeningJSON.number) ?? "null"),"
        + "\"bad\":\(notFinite(frame))}"
}

let arguments = Array(CommandLine.arguments.dropFirst())
let built = openingCheckScene()
let scenes: [String: OpeningScene] = [built.id: built, "launch": OpeningLaunchScene(), "done": OpeningDoneScene()]
var out = ""

switch arguments.first {
case "info":
    out = "{" + json(built) + ",\"layouts\":[" + layoutNames.map(OpeningJSON.text).joined(separator: ",") + "]}"
case "frames":
    guard arguments.count >= 4 else { fail("dump frames <layout> <light|dark> [screen=x,y,w,h] [facts=x,y,w,h] <scene>@<t>,<t>,... ...") }
    guard arguments[2] == "light" || arguments[2] == "dark" else { fail("the theme is light or dark, not \(arguments[2])") }
    let theme = arguments[2] == "dark" ? OpeningTheme.dark : OpeningTheme.light
    guard let preset = layoutPreset(arguments[1], theme) else {
        fail("no layout \(arguments[1]); there are: " + layoutNames.joined(separator: ", "))
    }
    var screen = OpeningRect.design
    var facts = OpeningRect.facts
    var sets: [String] = []
    for argument in arguments.dropFirst(3) {
        if argument.hasPrefix("screen=") {
            let n = argument.dropFirst(7).split(separator: ",").compactMap { Double($0) }
            guard n.count == 4 else { fail("screen=x,y,w,h") }
            screen = OpeningRect(x: n[0], y: n[1], w: n[2], h: n[3])
            continue
        }
        if argument.hasPrefix("facts=") {
            let n = argument.dropFirst(6).split(separator: ",").compactMap { Double($0) }
            guard n.count == 4 else { fail("facts=x,y,w,h") }
            facts = OpeningRect(x: n[0], y: n[1], w: n[2], h: n[3])
            continue
        }
        let halves = argument.split(separator: "@", maxSplits: 1).map(String.init)
        guard halves.count == 2, let scene = scenes[halves[0]] else {
            fail("no scene in \(argument); there are: " + scenes.keys.sorted().joined(separator: ", "))
        }
        let times = halves[1].split(separator: ",").compactMap { Double($0) }
        let frames = times.map { t in
            json(scene.frame(at: t, layout: preset.layout, theme: theme, screen: screen, facts: facts,
                             asMock: preset.asMock), at: t)
        }
        sets.append("{" + json(scene) + ",\"frames\":[" + frames.joined(separator: ",") + "]}")
    }
    out = "{\"layoutName\":\(OpeningJSON.text(arguments[1])),\"layout\":\(json(preset.layout)),\"theme\":\(json(theme)),"
        + "\"screen\":[\(OpeningJSON.numbers([screen.x, screen.y, screen.w, screen.h]))],\"asMock\":\(preset.asMock),"
        + "\"sets\":[" + sets.joined(separator: ",") + "]}"
default:
    fail("dump info | dump frames <layout> <light|dark> [screen=x,y,w,h] [facts=x,y,w,h] <scene>@<t>,<t>,... ...")
}

FileHandle.standardOutput.write((out + "\n").data(using: .utf8)!)
