# Porting an opening from the mock to the app

The six openings were designed in a browser (`mock/`: read `mock/SCENES.md` first) and approved as the mock plays
them. Each is ported to Swift as ONE file, `ios/Shifty/Opening/Scenes/<Name>.swift`, which draws with the kit in
`ios/Shifty/Opening/` (the mock's kit `K` in Swift). Nobody can watch the app here, so a port is proven by pictures:
its frames are dumped as JSON by a small program built in WSL, replayed on a canvas inside the mock's own page, and
held against the mock's frames and against the two fixed ends.

`Scenes/MrNow.swift` is a finished port: read it beside `mock/scenes/mrnow.js`. `scenes/Cheshire.swift` and
`scenes/Today.swift` here are two more, line for line, which only check the kit (they are not the app's).

You write your scene's file and nothing else. Do not edit the kit, another scene, `main.swift`, `replay.*` or the
tools: several scenes are ported at the same time, each built on its own. If the kit lacks something, draw it in
your scene with the pen, and say so when you are done.

The checks build your scene alone, but the app compiles all the scenes together. So the file declares ONE name at
its top, the scene's type, called `<Name>Opening`; every helper and small type of yours goes inside that struct
(or inside `draw`), or is `private`. Two files that each declare a top-level `Band` or `sind` would both pass here
and break the app.

## The file

```swift
import Foundation

/// What one sees, as the mock's file says it.
struct MonocleOpening: OpeningScene {          // the file is Scenes/Monocle.swift: its name in small letters is the id
    let id = "monocle"                         // the mock's id
    let name = "המונוקל"                        // the mock's `chip`
    let about = "…"                            // the mock's `about`
    let rest = 2.35                            // the mock's
    let end = 3.8                              // the mock's
    let haptics = [OpeningHaptic(0.84, .rigid), OpeningHaptic(1.47, .light)]
    let poster = 1.1                           // a moment that shows the idea in one still (a thumbnail)
    // let arrive = 0.6                        // only if not 0.6: see below

    func draw(_ t: Double, _ K: OpeningKit) {
        let E = K.E, DIAL = K.DIAL, LAUNCH = K.LAUNCH, C = K.C, g = K.g, o = K.o
        …
    }
}
```

`arrive` is the moment by which the icon has left the launch picture's place (its middle 201, 437). On a real
iPhone the launch picture's icon is in the real screen's middle, which is not always the design's y 437 once the
design is laid over the real dial; the app eases that difference away between 0 and `arrive`. Leave it 0.6 unless
your icon stays put longer, or leaves sooner.

Port faithfully: the same moments, the same numbers, the same order of drawing. Only what the sections "Not as in
the mock" and "Every day on the dial" ask for differs.

## JavaScript to Swift

| the mock | Swift |
| --- | --- |
| `.12`, `5 * .3` | `0.12`, `5 * 0.3` (a number needs its 0) |
| `const { E, seg, lerp, … } = K` | `let E = K.E, DIAL = K.DIAL, …`; the functions stay on the kit: `K.seg(…)`, `K.lerp(…)` |
| `seg(t, a, b, E.io2)` | `K.seg(t, a, b, E.io2)` |
| `const f = (a, b) => …` | `func f(_ a: Double, _ b: Double) -> Double { … }` inside `draw` |
| `const [x, y] = K.at(…)` | `let (x, y) = K.at(…)`; a point is `(x: Double, y: Double)`: `p.x`, `p.y` for `p[0]`, `p[1]` |
| `Math.sin`, `Math.hypot`, `Math.pow`, `Math.min`, `Math.PI` | `sin`, `hypot`, `pow`, `min`, `Double.pi` |
| `Math.round(x)` | `(x + 0.5).rounded(.down)` (halves go up, as in JavaScript) |
| `Math.floor(x)`, `Math.ceil(x)`, `Math.sign(x)` | `x.rounded(.down)`, `x.rounded(.up)`, `x > 0 ? 1.0 : x < 0 ? -1.0 : 0.0` |
| `a % b` on numbers | `a.truncatingRemainder(dividingBy: b)` |
| `i * 6 - a` with a whole `i` | `Double(i * 6) - a` |
| `K.TICKS.forEach((tk, i) => …)` | `for (i, tk) in K.TICKS.enumerated() { … }` |
| `cond ? i => … : null` | give the closure's type: `let tick: ((Int) -> OpeningDialTick)? = cond ? { i in … } : nil` |
| `'#0F9D8F'` | `OpeningColor(hex: 0x0F9D8F)` |
| `'rgba(0,0,0,${.22 * s})'` | `OpeningColor(0, 0, 0, 0.22 * s)` |
| `'rgb(' + c.map(Math.round) + ')'` | `OpeningColor(r, g, b).whole` |
| `x / DIAL.now`, `x / DIAL.goal` | guard it: on another day `DIAL.now` and `DIAL.worked` may be 0 and `DIAL.goal` is nil (see "Every day on the dial") |

A struct's arguments go in the order it declares them, whatever order the mock's object had:
`OpeningMove(dx:dy:rot:s:sx:sy:alpha:pivot:open:split:)`,
`OpeningPose(all:body:head:brows:browL:browR:eyes:eyeL:eyeR:stache:bow:wings:knot:hide:alpha:edge:)`,
`OpeningLogoTick(a:len:w:color:out:dx:dy:rot:)`, `OpeningDialTick(k:a:)`,
`OpeningGround(toward:alpha:hairline:shadow:)`; and `K.dial(cx:cy:k:alpha:track:reveal:numerals:span:wind:from:
tint:ahead:aheadTo:marks:knobAt:ctx:tick:)`. The compiler says which one is out of place.

## The kit, call for call

Numbers, unchanged in meaning: `K.seg`, `K.E.lin in2 in3 out2 out3 out4 out5 io2 io3 back backIn`, `K.spring(t, a,
period, damping)`, `K.wobble(t, a, period, decay)`, `K.lerp`, `K.clamp(x, lo, hi)`, `K.rad(deg)`, `K.at(x, y, deg, r)`.

| the mock | Swift |
| --- | --- |
| `K.mix('#a', '#b', k)` | `K.mix(a, b, k)` on `OpeningColor`s (whole red, green and blue, as the mock's) |
| `K.rgba('#a', alpha)` | `K.rgba(a, alpha)`, or `a.alpha(alpha)`; `a.faded(k)` multiplies its alpha |
| `K.LAUNCH`, `K.TICKS`, `K.HOURS`, `K.TC`, `K.P`, `K.PARTS` | the same; `K.TC.x .y .r`; `K.P.neck` … are points, `K.P.knot` has `.x .y .r`, the two boxes `.left .top .right .bottom` |
| `K.W`, `K.H` | the design's 402 and 874 still; for "the whole screen" use `K.bounds` (below) |
| `K.DIAL.x .y .r .w .start .now` | the same |
| `K.DIAL.goal` | `K.DIAL.flag` (where the flag stands, nil with no shift running), `K.DIAL.end` (where the last piece ends), `K.DIAL.goal` (the goal itself, nil with none): see "Every day on the dial" |
| `K.C.teal` | `C.accent`; and for a knob, `K.knobColor` |
| `K.C.navy` | `C.line` (the logo's lines: white in the dark look) |
| `K.C.bg`, `.card`, `.ink`, `.gray`, `.orange`, `.red`, `.yellow`, `.groundTop`, `.groundBottom`, `.skin`, `.hair` | `C.background`, the rest by the same names; more: `C.track`, `C.tickBig`, `C.tickSmall`, `C.numerals`, `C.hairline`, `C.shade` |
| `K.dial({ cx, cy, k, alpha, track, reveal, tick, numerals, span, from, ahead, marks, knobAt, ctx })` | `K.dial(cx: …, …, tick: { i in OpeningDialTick(k: …, a: …) })`: by name, in the order above |
| `K.dial({ color: c })` | `K.dial(tint: (c, 1))`: every piece behind now mixed toward `c` by the share |
| `K.dial({ span: 360 … })` (a whole ring in teal, wound past the day) | `K.dial(wind: 360 …)`: the accent wound on past the day's pieces. `span` is the day's own pieces: past now, on a running shift, it only carries the last piece on to a knob that overshoots |
| `K.settle(t, T, { cx })` | `K.settle(t, T) { $0.cx = … }` |
| `K.tickEnds(deg, big, k, cx, cy)` | the same; gives `(a: point, b: point)`. `K.tick(big)` gives the tick's `.line` (its length between its ends), `.width`, `.mid` (radius) |
| `K.startMark(ctx)`, `K.knob(ctx)`, `K.flag(ctx)` | the same (`ctx` may be left out for `g`); the start and the flag draw nothing with no shift running |
| `K.markAt('start' / 'now' / 'goal')` | `K.markAt(.start / .knob / .flag)` |
| the scenes' own `mark(which, s, fn)` | `K.mark(ctx, .flag, s)`, also `dx: dy:` |
| `K.center({ time: K.clock(K.SHIFT.seconds * p), pay: … K.SHIFT.pay * p })` | `K.count(p)`: the share of the real time and pay shown |
| `K.part('center', shown, dy, { dx, scale })` | `K.part(.center, shown, dy, dx: dx, scale: scale)` |
| `K.parts(t, T, { gap, dur, rise, order: ['facts', …] })` | `K.parts(t, T, gap: …, dur: …, rise: …, order: [.facts, …])` |
| `K.box(cx, cy, size, r)`, `box.k`, `box.pt(gx, gy)` | the same; `box.pt` gives a point |
| `K.path(ctx, box, inset); ctx.fill()` | `ctx.fill(K.path(box, inset), paint)`: `K.path` gives the path |
| `K.ground(ctx, box, { toward: [c, s], alpha, hairline, shadow: [blur, dy, alpha] })` | `K.ground(ctx, box, toward: (c, s), alpha: …, hairline: …, shadow: (blur, dy, alpha))` |
| `K.clip(ctx, box, fn)` | `K.clip(ctx, box) { … }` |
| `K.ticks(ctx, box, fn, color)` | `K.ticks(ctx, box, color: color) { i, tk in OpeningLogoTick(len: …, out: …) }`; `nil` hides one; `OpeningLogoTick()` for the mock's `{}` |
| `K.tickOnScreen(box, i)` | the same: `.a .b` (points), `.w`, `.mid` |
| `K.man(ctx, box, { head: { rot, dy }, eyes: { open }, hide: ['knot'] })` | `K.man(ctx, box, OpeningPose(head: OpeningMove(dy: …, rot: …), eyes: OpeningMove(open: …), hide: [.knot]))` |
| `K.sprite(ctx, 'stache', x, y, { k, rot, sx, sy, alpha, anchor })` | `K.sprite(ctx, .stache, x, y, k: …, rot: …, sx: …, sy: …, alpha: …, anchor: …)`; also `edge:` (the dark look) |
| `K.partBox('stache')` | `K.partBox(.stache)`: `.x .y .w .h .middle` |
| `K.ribbon(ctx, { x, y, dir, length, bend, top, bottom, fill, alpha, n })` | `K.ribbon(ctx, x: …, y: …, dir: …, length: …, bend: …, top: { u in … }, bottom: { u in … }, fill: …, alpha: …, n: …)` |
| `K.stache.length .middle .top(u) .bottom(u) .color` | the same; `.middle` is a point |
| `K.icon(ctx, box, { ground, ticks, tickColor, pose, content, clip })` | `K.icon(ctx, box, ground: OpeningGround(…), ticks: true, tickColor: …, pose: OpeningPose(…), content: …, clip: true, tick: { i, tk in … })`; `ground: nil` and `pose: nil` for the mock's `false`, `ticks: false` |
| `K.launch()`, `K.launch(ctx)` | the same; for the mock's `K.launch(ctx, { … })` (none of the six has it) `K.icon(ctx, K.box(), …)` |
| `K.backdrop(ctx, alpha, color)` | the same; it covers the real screen |
| `K.unit` | gone: shadows and blurs are in points (below) |

New in the kit, for what the app needs: `K.knobColor`, `K.flagColor`, `K.KNOB` (the knob's shape), `K.planDot(ctx)`,
`K.worked(ctx, from:to:tint:cx:cy:k:)` and `K.ahead(ctx, from:to:alpha:cx:cy:k:)` (stretches of the ring as
`K.dial` draws them, for a scene that shows the ring itself), `K.covered(from:to:)`, `K.onWhite(color)`, `K.screen`,
`K.bounds`, `K.layout`, `K.theme`, `K.asMock`.

## A canvas's calls as the pen's

The two canvases are two pens, `K.g` (under the Now screen's parts) and `K.o` (over them). A pen writes down what it
is told; `OpeningPen.swift` says what each operation means. A path is a value built first and handed over: there is
no `beginPath`.

| the canvas | the pen |
| --- | --- |
| `ctx.save()`, `ctx.restore()`, `ctx.translate(x, y)`, `ctx.scale(a, b)` | the same |
| `ctx.rotate(radians)` | the same (radians, as on the canvas; the kit's own angles are degrees) |
| `ctx.globalAlpha *= a`, `ctx.globalAlpha = a` | `ctx.alpha *= a`, `ctx.alpha = a` (a value outside 0...1 is not taken, as on a canvas) |
| `ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.fillStyle = c; ctx.fill()` | `ctx.fill(.circle(x, y, r), c)` |
| `ctx.beginPath(); ctx.arc(x, y, r, a0, a1); ctx.strokeStyle = c; ctx.lineWidth = w; ctx.lineCap = 'butt'; ctx.stroke()` | `ctx.stroke(.arc(x, y, r, a0, a1), c, width: w, cap: .butt)` |
| `ctx.moveTo(x1, y1); ctx.lineTo(x2, y2)` and a round stroke | `ctx.stroke(.line(x1, y1, x2, y2), c, width: w, cap: .round)` |
| a longer path | `var p = OpeningPath(); p.move(x, y); p.line(x, y); p.quad(cx, cy, x, y); p.cubic(…); p.arc(x, y, r, a0, a1, counter: true); p.ellipse(x, y, rx, ry, rotation, a0, a1); p.rect(…); p.roundRect(x, y, w, h, r); p.close()` |
| `ctx.fillRect(x, y, w, h)` | `ctx.fill(.rect(x, y, w, h), c)` |
| `ctx.roundRect(x, y, w, h, r)` | `.roundRect(x, y, w, h, r)` |
| `ctx.fill('evenodd')`, `ctx.clip('evenodd')` | `ctx.fill(p, c, evenOdd: true)`, `ctx.clip(p, evenOdd: true)` |
| `ctx.clip()` | `ctx.clip(p)`: until the `restore`, as on the canvas |
| `ctx.lineCap`, `ctx.lineJoin` | each stroke says its own: `cap: .round`, `join: .round` (`.butt` and `.miter` if left out). The canvas keeps the last one set: read back in the mock which one is in force for an open path |
| `ctx.fillStyle`, `ctx.strokeStyle`, `ctx.lineWidth` | each fill and stroke says its own. The canvas keeps them too, and `restore()` brings back the ones from before the `save()`: a `fill()` after a `restore()` may be in an earlier color than the line above it suggests |
| `const f = ctx.createLinearGradient(x0, y0, x1, y1); f.addColorStop(0, a); f.addColorStop(1, b)` | `.linear(x0: x0, y0: y0, x1: x1, y1: y1, stops: [OpeningStop(0, a), OpeningStop(1, b)])`, given where a color is |
| `ctx.createRadialGradient(x, y, r0, x, y, r1)` | `.radial(x: x, y: y, r0: r0, r1: r1, stops: […])`: one middle for both circles only |
| `ctx.shadowColor = c; ctx.shadowBlur = b * K.unit; ctx.shadowOffsetY = d * K.unit` | `ctx.shadow(c, radius: b, dx: 0, dy: d)`: in points, no `K.unit`; it lasts until the `restore`, so wrap what casts it in `save` and `restore` (there is no `shadowColor = 'transparent'`). One shadow at a time: a second one before the `restore` stops the dumper with a message |
| `ctx.filter = 'blur(' + b * K.unit + 'px)'` | `ctx.blur(b)`: until the `restore`; one at a time, as a shadow |
| `ctx.drawImage(…)` | the kit's `K.man` and `K.sprite` only |
| `globalCompositeOperation`, text, dashes | not there: none of the six uses them |

A path's points are in the coordinates of the moment it is filled, stroked or clipped to. On a canvas they are in
those of the moment each point was added: where the mock moves or restores the canvas between building a path and
drawing it, build the path's points for the transform you draw under.

## Not as in the mock

**The dial is real.** The mock's shift (start 255, now 171, goal 252, one teal arc and a pale one ahead) is one day
of many: see "Every day on the dial". `K.dial()` with nothing told draws the finished dial of whatever day it is, as
the app's own dial is drawn.

**The colors are a theme.** No literal hex that only reads on a light ground: the background, the logo's lines, the
icon's ground, the accent and the dial's grays come from `C`. A literal is right only for what is the same in both
looks: the man's own colors (his skin, `K.stache.color`, the ink of his lines), and the knob's white disc.

**The dark look's edge.** In the dark the launch picture's man has a white edge round his whole silhouette, and
`K.man` and `K.sprite` draw it (a group with an edge: they do it by themselves). `K.launch()` is the dark launch
picture. A part that leaves him (hidden in his pose, drawn by `K.sprite` from the same place) gets an edge of its
own, which he did not have there: let it grow in with `K.sprite(…, edge: share)` from 0, and look at it.
A shape you draw yourself in his colors (a ribbon in `K.stache.color`) has no edge: on the dark ground it needs
one, or to be on something light. `K.edged(ctx, width) { … }` gives what it draws the same edge, `width` points wide
(the icon's is `C.edgeShare * box.size`), in the dark look alone.
The edge lies under all of him, as one with him: `pose.alpha` and a sprite's `alpha` fade the man and his edge
together, as they should. But a part faded by a move's own `alpha` inside `K.man` (`wings: OpeningMove(alpha: 0.5)`)
lets the edge's white show through it wherever nothing else of him is behind it. Look at it in the dark; if it
shows, fade that part as a sprite instead (hidden in the pose, drawn by `K.sprite` with `alpha:`).
With `clip: false`, or the man drawn smaller than the square he is cut to, the edge also runs along the straight
cuts of his shirt at the picture's bottom and sides, which the light look never shows.

**The screen may be larger than 402 x 874.** The app lays the design over the real screen so that the dial here is
the real dial. Whatever fills or clips "the whole screen" takes `K.bounds` (the real screen and well beyond):
`ctx.fill(K.bounds.path, c)`; for the mock's `rect(0, 0, K.W, y)`, `.rect(K.bounds.x, K.bounds.y, K.bounds.w, y -
K.bounds.y)`. `K.backdrop` does. Nothing may rely on the screen's edge to hide it.

**The Now screen's parts are the app's views.** `K.part` and `K.parts` only write down each part's state; a part
not set in a frame is hidden, as in the mock. `K.center`'s count-up is one number, `K.count(share)`.

**Shadows and blurs are in points.** Drop `K.unit`. They do not scale with the canvas: `7 * z` stays `7 * z`.

**The dial's own shapes are the app's.** Where the mock's dial is not quite the app's, the kit follows the app:
a tick is a capsule 9 x 2 or 4 x 1.5 points, caps and all (the mock's is that long between its caps), and the
knob's ring stands astride its disc's edge (the mock's is inside it). For the mock's own layout the kit draws as the
mock (`K.asMock`), which is how a port is held against it to the pixel. So wherever a shape of yours becomes a tick
or the knob, take the numbers from the kit, not from the mock: `K.tick(big).line` and `.width` for the mock's 9 and
2; `K.tickEnds`; `K.KNOB.r` (16), `K.KNOB.ring` (the radius of its ring's middle), `K.KNOB.width` (3.5), `K.KNOB.dot`
(4.5). In `MrNow.swift` the rim lies inside the disc, as the mock has it, and moves out to `K.KNOB.ring` as the knob
comes down to its size: with the mock's layout the move is nothing, and the port is still equal to the mock.
The start's mark, the knob and the flag are drawn by the app's own views (`K.startMark`, `K.knob`, `K.flag`, and
inside `K.dial`), and so are the four numerals.

## Every day on the dial

`K.layout` is the day as the app's dial will show it; a scene sees it through `K.DIAL` and `K.dial`:

- `DIAL.start`: where the arc starts, degrees clockwise from 12. The rest are counted from it:
- `DIAL.now`: where the knob stands. Every day has a knob, in `K.knobColor`: the accent on a shift, orange on a
  break, gold past the goal, gray with no shift running, a day off's color.
- `DIAL.goal`: nil with no shift running, and then there is no start mark and no flag at all.
- `DIAL.flag`: where the flag stands: the goal, or with a plan the time to leave (then a small dot stays at the goal:
  `K.planDot`).
- `DIAL.worked`: where the pieces behind now end: `now` on a shift; less with no shift running (the day's finished
  shifts); 0 with nothing behind.
- `DIAL.end`: where the last piece ends.
- `K.layout.reached`: the goal is reached and there is no plan: the app's flag is then a white check on a disc in
  the accent (not a flag on a white disc). `K.flag` draws whichever it is; it only matters to a shape of yours that
  becomes the flag's disc.
- Any of these may be 0, and `DIAL.goal` and `DIAL.flag` nil: `idle` and `dayOff` have `now` 0 and `worked` 0. Never
  divide by one of them unguarded (the mock's `ridden / DIAL.now`): a frame with a number that is not one draws
  nothing where it should, without a word.
- The pieces behind now (`span` shows them from the start on; `tint` mixes them toward a color): work, breaks in
  orange, overtime in gold, the day's finished shifts pale. The pieces ahead of now (`ahead` is their alpha,
  `aheadTo` how far they are drawn): the pale time to the goal, a plan's pieces, a day off's whole round.

The layouts to try (`--layout`): `mock` (the designed shift, drawn as the mock draws), `running` (the same, drawn as
the app draws), `idle` (nothing today: no pieces, a gray knob at the clock's time, no start, no flag), `idleToday`
(two finished shifts, pale; the knob further on), `break` (work, an orange break, work, the time ahead), `overtime`
(past the goal in gold, and a plan: the flag further on, a dot at the goal), `dayOff` (the whole round in a color,
the knob at its start), `justStarted` (now is 2 degrees), `nearlyFull` (now is 330 degrees, the goal behind it).

Go through every place the mock uses `DIAL.now`, `DIAL.goal`, `C.teal` or a pale teal, and ask what it stands for:

- The knob's angle is `DIAL.start + DIAL.now`, always.
- The flag's angle is `DIAL.start + DIAL.flag`, if there is a flag: `if let flag = DIAL.flag`. `K.flag`,
  `K.startMark` and `K.mark` draw nothing when there is none, so a pop of theirs needs no `if`.
- "The worked arc" is the pieces behind now. Let `K.dial(span:)` draw it wherever the mock does; where the mock
  draws a piece of the ring itself (mrnow's road, at its own zoom), `K.worked(ctx, from: to: cx: cy: k:)` draws the
  real pieces there.
- "The pale arc ahead" is `K.dial(ahead:)`, or `K.ahead(ctx, from: to: …)`: from the knob to `DIAL.end`, not to the
  goal. With nothing ahead it draws nothing.
- A shape of the scene's own in `C.teal` that becomes the worked arc (a ribbon, a ring) hands over to
  `K.dial(span: …, tint: (itsColor, 1))` and the tint then eases to 0: a break's orange and the overtime's gold come
  up through it, nothing pops.
- A shape of the scene's own that becomes the knob takes `K.knobColor`, or, drawn on the knob's white disc,
  `K.onWhite(K.knobColor)` easing to `K.knobColor` at the end (a gray knob in the dark look is all but white).
- A hand-over that needs what the day does not have (an arc to stretch along when nothing is worked; a flag to
  become; a start to hop onto) ends in a short cross-fade or a retreat into what is there, the knob at least. Never
  a jump, never a leftover.

What mrnow needed, as an example: the ring behind the giant knob is `K.worked` over the bare track where
`K.covered` says the pieces do not hide it; what runs out ahead of him is `K.ahead` to `max(DIAL.end, DIAL.now)`;
the flag and the plan's dot pop only `if let` they are there; the rim and the dot are in the knob's color. Nothing
else changed, and with the mock's layout every frame is still the mock's, pixel for pixel.

## The commands

From `ios/Tests/OpeningCheck`, on Windows (Python with numpy and Pillow, Chrome, and Swift in WSL). Each prints a
picture's path (look at it with the Read tool) or a short report. The tools build by themselves when a source has
changed (yours or the kit's), each scene into its own folder in WSL (`/tmp/opening-check/<id>/`, which WSL empties
now and then: it is simply built again, in a few seconds); pictures go to the temp folder, each under its own name.
Tools may be run side by side, by you and by whoever ports the other scenes: a build is locked while it runs, and
no more than a few Chromes take pictures at once on the machine, so a tool may wait a little for its turn.

```
python tools/build.py <id>                      # builds the kit + your scene + main.swift in WSL; shows warnings
python tools/film.py <id> --n 12                # twelve moments of the Swift scene, the mock's layout, light
python tools/film.py <id> --layout idle --theme dark --at 0.3,0.4,0.5 --view 101,337,200,200 --s 1.5 --cols 3
python tools/film.py <id> --both --at 0.5,1.2   # each moment of the mock's scene and of the Swift one, side by side
python tools/film.py <id> --mock --n 12         # the mock's scene alone
python tools/film.py done --with <id> --layout overtime --at 0    # the finished Now screen of a day (also: launch)
python tools/compare.py <id>                    # against the mock, frame by frame, 0 to rest + 0.2 at 30 a second
python tools/check.py <id> --layout break --theme dark            # the two ends and no jumps, one day, one theme
python tools/check.py <id> all                  # every layout in both themes: 18 checks, about a minute
python tools/build.py --app                     # the kit and ALL scenes type-checked together, as the app compiles them
```

`<id>` is your file's name in small letters (`Scenes/Monocle.swift`: `monocle`), which must be the scene's `id`.

`compare.py` holds the Swift scene (the mock's layout, light) against the mock's scene of the same id. Both are
drawn by the same browser canvas, each moment at the same place of two sheets: a frame passes when no pixel is more
than 2 levels (of 255) from the mock's. A faithful port is equal to the pixel: mrnow's 76 frames differ by 0 (a
level or two on a few pixels is rounding: an arc drawn the other way round reaches the canvas with its end angle
written differently). It names the worst frames and makes a picture of them: the mock's, yours, and the difference
in red. `--s 1` holds them at full size (402 x 874 a frame) rather than half, for a last look.

`check.py` holds the first frame against the built-in `launch`, the frames from `rest` on against the built-in
`done` (both to the pixel), and looks for jumps as the mock's `tools/check.py` does. A jump comes with its moment and
place: film it closely there. The detector weighs the whole screen, so it sees large changes only: a small thing that
appears at once (a pale arc, a mark, a tick, a plan's dot) passes it. On the mock's layout `compare.py` holds every
frame; on the other layouts nothing but your eyes holds what you changed for them: film each hand-over there closely,
a frame every 0.03 to 0.05 s (`--at`, `--view`).

## Done means

1. `python tools/compare.py <id>` says PASSED.
2. `python tools/check.py <id> all` says PASSED: all 18.
3. You have looked at film strips in the dark theme and in the layouts that are least like the mock's (`idle`,
   `dayOff`, `justStarted`, `nearlyFull`, `break`), close up where the logo's element becomes the dial's, and it makes
   sense there: every hand-over ends on what `K.dial()` really draws, by a real hand-over where the day allows one and
   a short cross-fade where it does not; never a jump, never a leftover; and in the dark everything of yours reads.
4. No literal color that only reads on a light ground; nothing that counts on the screen ending at 402 x 874.
5. `python tools/build.py <id>` shows no warnings, and `python tools/build.py --app` passes (if it fails in
   another scene's file, one still being written, that is not yours: say so).

## Met on the way

- `K.ticks` draws every tick at its own alpha, whatever the canvas's was (the mock sets `globalAlpha`, it does not
  multiply): inside `K.icon`, `content` fades the man and not the ticks. The kit keeps that, as the pictures have it.
- `K.man` with eyes more than 0.35 open draws them as shapes at the eyes' places: an eye's own `dx`, `dy` and
  `alpha` then do nothing (only `eyes:` moves them). As the mock.
- `span` beyond now, on a running shift, goes on in the last piece's color: mrnow's knob overshoots its place by a
  hair and the arc follows it there. With no shift running `span` draws the day's pieces and no more.
- A move given to `K.man` moves its part even when it moves it by nothing, as in the mock: give the moves the mock
  gives, no more and no fewer (`all:` only where the mock has `all`), or his picture differs in a pixel here and
  there.
- The mock's `ctx.arc(x, y, r, 0, 7)` is a whole circle: `.circle(x, y, r)`.
- A scene's own `band`, `arc` or `mark` helper in the mock usually has a call of the kit's that says the same:
  look for one before porting the helper.
- If a picture has `ERROR` on it in red, the replay could not find a frame or an operation: run `build.py` and read
  what it prints.
- "The compiler is unable to type-check this expression in reasonable time": a long line of arithmetic, as the mock
  is fond of. Cut it into two or three `let`s, and write whole numbers that are meant as fractions with their point
  (`216.0 / 32`), or as `Double(i)`.
- A number that is not one (a division by a `DIAL.now` of 0, a `K.seg` over no time) is written to the list as 0:
  the shape lands at the screen's corner or is not drawn. If something vanishes on `idle` or `dayOff` only, look
  for that.
- "Chrome's picture was not whole": the page did not finish (a scene id it does not know, a script that failed).
  Film the same moments with `film.py` and read what the picture says.
