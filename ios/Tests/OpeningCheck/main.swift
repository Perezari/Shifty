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
// The layouts are days the Now screen's dial can show (Core/Dial.swift), on made-up hours.

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
    default:
        return nil
    }
}

let layoutNames = ["mock", "running", "idle", "idleToday", "break", "overtime", "dayOff", "justStarted", "nearlyFull"]

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

func json(_ frame: OpeningFrame, at t: Double) -> String {
    let parts = OpeningScreenPart.allCases.map { id -> String in
        let s = frame.parts[id] ?? OpeningPartState()
        return "\"\(id.rawValue)\":[\(OpeningJSON.numbers([s.shown, s.dx, s.dy, s.scale]))]"
    }
    return "{\"t\":\(OpeningJSON.number(t)),\"under\":\(OpeningJSON.list(frame.under)),\"over\":\(OpeningJSON.list(frame.over)),"
        + "\"parts\":{" + parts.joined(separator: ",") + "},\"count\":\(frame.counted.map(OpeningJSON.number) ?? "null")}"
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
