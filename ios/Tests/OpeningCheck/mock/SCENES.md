# Writing an opening scene

The page shows an iPhone with the app's Now screen and plays "openings": the two or three seconds from the launch
picture (the app's icon in the screen's middle) to the Now screen. Each opening is ONE file, `scenes/<id>.js`, which
registers one scene. You write only your own scene file. Do not edit `engine.js`, `page.js`, `page.css`,
`index.html`, `rig.js` or another scene: if the kit lacks something, draw it yourself on the canvas inside your scene.

## The file

```js
Opening.scene({
  id: 'wink',                       // the file's name, Latin, short
  chip: 'קריצה',                    // the picker's word, Hebrew, one or two words
  title: 'הקריצה.',                 // the name, Hebrew, with a full stop
  about: '…',                       // two or three plain Hebrew sentences: what one sees, in order. No English words.
  end: 4.2,                         // seconds: when the loop starts again = the last motion's end + about 1.6
  rest: 2.7,                        // seconds: a moment when everything has settled on the Now screen
  haptics: [[1.1, 'light']],        // the iPhone's taps: [seconds, 'light' | 'medium' | 'rigid' | 'success']
  draw(t, K) { … },                 // draws the WHOLE frame of the moment t, from nothing
});
```

`draw(t, K)` is called for each frame with `t` in real seconds since the opening began (0 or more). It must be a pure
function of `t`: no state kept between frames, no timers, no randomness (use fixed numbers), because frames are also
drawn out of order, as still pictures. Every frame starts clean: both canvases are cleared and every part of the Now
screen is hidden; whatever is to be seen at `t` must be drawn at `t`.

## The two fixed ends

- **t = 0 is the launch picture, exactly:** `K.launch()` and nothing else (the app's background is already there).
  Keep it still for the first 0.10 to 0.15 s, then move. No jump between the still picture and your first moving
  frame: begin every move from the launch picture's own values (the icon's middle 201, 437; its side 120; corner 27).
- **The last frame is the Now screen, exactly:** `K.dial()` with no options (all its defaults), and all six parts
  fully shown at their places (`K.part(id, 1, 0)` for each, or `K.parts(t, T)` long enough before `rest`). Nothing of
  the logo may remain on the screen then, and nothing may pop at the end: whatever you drew must have become a part
  of the dial or have left smoothly. From `rest` on, every frame must be identical to that.

## The screen

402 x 874 points; x to the right, y down. Two canvases, both in these points:
- `K.g` is UNDER the Now screen's parts (its words and cards): the dial belongs here.
- `K.o` is OVER them: the icon, the man, effects.

The Now screen's parts are HTML over `K.g`: `'cap'` (the capsule on top, y 66 to 102), `'center'` (the date, the big
timer and the wage, in the dial's middle), `'facts'` (the card of three, y 482 to 558), `'buttons'` (y 570 to 622),
`'week'` (the week's card, y 634 to about 770), `'tabs'` (the tab bar, y 782 to 844). The Dynamic Island is at the
top (x 138 to 264, y 11 to 48): keep the action clear of it.

Fixed places (in `K`):
- `K.LAUNCH = { x: 201, y: 437, size: 120, r: 27 }`: the launch icon.
- `K.DIAL = { x: 201, y: 293, r: 160, w: 22, start: 255, now: 171, goal: 252 }`: the dial's middle, the ring's
  radius and width; the made-up shift began at 255 degrees (clockwise from 12), "now" is 171 degrees on (at 66
  degrees: 2 o'clock and a bit), the goal 252 degrees on (at 147 degrees). `K.markAt('start' | 'now' | 'goal')` gives
  each mark's place on the screen.
- `K.C`: colors: `teal` (the app's accent, #0F9D8F), `navy` (the logo's lines, #0A1435), `yellow` (the brand's,
  #FEC802), `bg` (the app's background, #F4F5F7), `card`, `ink`, `gray`, `orange`, `red`, `groundTop`, `groundBottom`
  (the icon's white ground), `skin`, `hair`.

## The kit

Numbers:
- `K.seg(t, a, b, ease)`: how far a move from the moment `a` to the moment `b` has come at `t`: 0 before, 1 after,
  on the curve `ease`: `K.E.lin, in2, in3, out2, out3, out4, out5, io2, io3` (in-out), `back` (overshoots a little
  and returns), `backIn` (pulls back first).
- `K.spring(t, a, period = .45, damping = .45)`: a spring let go at `a`: 0 to 1, overshooting and settling;
  `period` is one swing in seconds, `damping` 0 (rings long) to 1 (no overshoot).
- `K.wobble(t, a, period = .3, decay = 6)`: from the moment `a`, a swing round 0 that dies away (follow-through:
  multiply by a few degrees or points).
- `K.lerp(a, b, k)`, `K.clamp(x, lo, hi)`, `K.mix('#rrggbb', '#rrggbb', k)` (a color between two),
  `K.rgba('#rrggbb', alpha)`, `K.rad(deg)` (degrees clockwise from 12 as canvas radians),
  `K.at(x, y, deg, r)` (the point `r` away from x, y toward `deg`).

The dial (on `K.g` unless `ctx` is given):
- `K.dial(op)`: the Now screen's dial as the app draws it. With no options it is the finished dial. Options:
  `cx, cy` (its middle), `k` (its size, 1), `alpha`, `track` (the pale track, 0 to 1), `reveal` (degrees of the track
  and ticks drawn so far, clockwise from 12; 360), `tick: i => ({ k, a })` (each of the 60 ticks, i * 6 degrees: its
  length's share and alpha), `numerals` (the 12, 3, 6, 9; 0 to 1), `span` (the teal arc's length in degrees from the
  start mark; the day's 171 by default; 0 draws none), `from` (where the arc starts; 255), `color` (the arc's),
  `ahead` (the pale arc from now to the goal, 0 to 1), `marks: [start, knob, flag]` (each mark's size, 0 to 1),
  `knobAt` (the knob's angle, if it travels), `ctx`.
- `K.settle(t, T, op)`: the app's own finish from the moment `T`, about 0.9 s: the whole ring in teal unwinds to
  the day, the 60 ticks come in as a wave from 12, the three marks pop. Use it if your idea ends in a full teal ring;
  otherwise build your own finish with `K.dial`.
- `K.tickEnds(deg, big, k)`: the two ends on the screen of the dial's tick at `deg` (`big`: an hour's tick, 9
  points long and 2 wide; the others 4 long and 1.5 wide).
- `K.startMark(ctx)`, `K.knob(ctx)`, `K.flag(ctx)`: each mark drawn round 0, 0 (translate and scale the canvas
  first): the teal disc with the play triangle (radius 11), the white knob with a teal rim (radius 16), the goal flag
  (radius 21 with its halo).
- `K.center({ time, pay })`: the words in the dial's middle for this frame, e.g. a count-up: `K.center({ time:
  K.clock(seconds), pay: '₪ ' + Math.round(shekels) })`. Left alone they are the made-up shift's own: `K.SHIFT =
  { seconds: 20538, pay: 308 }` (5:42:18, running on). By `rest` they must be left alone again.
- `K.parts(t, T, { gap = .08, dur = .45, rise = 46, order })`: the Now screen's parts rising one after another
  from `T`. `K.part(id, shown, dy, { dx, scale })`: one part: how much of it is there (0 to 1) and how far moved.

The icon and the man (usually on `K.o`):
- `K.box(cx, cy, size, r)`: the icon's square: its middle on the screen, its side, its corner (27/120 of the side
  if left out). The box has `.k` (points to one unit of the icon's 512 grid) and `.pt(gx, gy)` (a grid point on the
  screen). All of the icon's parts are placed on a 512 x 512 grid: `K.P` holds points on it: `neck` [265, 379],
  `stache` (the mustache's middle) [322, 278], `stacheBox` [left, top, right, bottom], `knot` [263, 404, radius 25],
  `browL`, `browR`, `eyeL`, `eyeR`, `headTop`, `headBox`, `button`. The ticks' circle: `K.TC = { x: 256, y: 243.6,
  r: 203 }`.
- `K.icon(ctx, box, { ground, ticks, tickColor, pose, content, clip })`: the whole icon: the white ground, and, cut
  to its rounded square, the nine ticks and the man. `ground: false`, `ticks: false`, `pose: false` leave one out;
  `content` is the alpha of ticks and man together; `clip: false` lets them out of the square.
- `K.launch(ctx = K.o, op)`: `K.icon` at the launch picture's place and size.
- `K.ground(ctx, box, { toward: [color, share], alpha, hairline, shadow: [blur, dy, alpha] })`: the ground alone.
  `K.path(ctx, box, inset)`: the rounded square as a path. `K.clip(ctx, box, fn)`: draws `fn` cut to it.
- `K.ticks(ctx, box, fn, color)`: the logo's nine ticks. `fn(i, tick)` may return for each
  `{ a, len, w, color, out, dx, dy, rot }` (alpha, length's share, width's share, moved outward along its ray, moved,
  turned; grid units and degrees) or `null` to hide it. `K.TICKS[i]` has `x1, y1, x2, y2, w, cx, cy, deg` (its angle
  clockwise from 12) and `hour` (the hour it stands at, in degrees: 0, 30, 60, 90, 120, 240, 270, 300, 330).
  `K.tickOnScreen(box, i)` gives `{ a, b, w, mid }` in screen points, to draw a tick yourself as it flies.
- `K.man(ctx, box, pose)`: the man, each part moved on its own. A move is
  `{ dx, dy, rot, s, sx, sy, alpha, pivot }` (grid units; degrees clockwise; scale) about the part's own pivot:
  - `all`: the whole man (about the neck); `body`: the shirt (about its bottom middle); 
  - `head`: the head with its whole face, about the neck. A nod is `rot` of 4 to 8 with `dy` of 2 to 5; more than 10
    degrees shows the cut at the neck.
  - `brows` (both; or `browL`, `browR`): raise with `dy: -6`.
  - `eyes` (both; or `eyeL`, `eyeR`): `eyes.open` from 0 (the logo's smiling arcs) to 1 (two round friendly eyes):
    the arc flattens to a line and the eye grows from it. `sy` squints the arcs. `eyeL.open` / `eyeR.open` open one eye alone (a
    wink is one eye open and the other left an arc, or both open and one closing). `eyes.dx, dy` of a unit or two
    make the open eyes look somewhere. `eyeL` is the eye on our left.
  - `stache`: the mustache, about its middle; `stache.split` turns its two halves about the middle (degrees; the
    tips go up when positive; up to about 20).
  - `bow`: the bow tie with its knot, about the knot (a full spin is fine: under it the shirt goes on to a round
    collar); `wings`, `knot`: each alone.
  - `hide: ['knot', …]`: parts not drawn: `'body'`, `'head'`, `'brows'`, `'eyes'`, `'stache'`, `'bow'`, `'wings'`,
    `'knot'`. Under the mustache, the brows and the eyes the skin goes on; where the knot sat it is dark.
  With nothing moved it is the launch picture's man to the pixel.
- `K.sprite(ctx, name, x, y, { k, rot, sx, sy, alpha, anchor })`: one part alone, anywhere on the screen, its middle
  (or the grid point `anchor`) at x, y; `k` is points to a grid unit (use `box.k` to match an icon). Names: `'man'`,
  `'body'`, `'head'` (with no face), `'browL'`, `'browR'`, `'eyeL'`, `'eyeR'`, `'stache'`, `'stacheL'`, `'stacheR'`,
  `'wings'`, `'knot'`. To let a part leave the man: hide it in the pose and draw it with `K.sprite` from the same
  place (`box.pt(...)` of its middle: `K.partBox(name)` gives its `{ x, y, w, h }` on the grid).
- `K.backdrop(ctx, alpha, color)`: the app's background over everything under it on that canvas.
- `K.ribbon(ctx, { x, y, dir, length, bend, top, bottom, fill, alpha, n })`: a band along a line that may bend, its
  thickness changing along it: for a shape that stretches along the dial's ring. `x, y` its middle; `dir` its line's
  direction there (degrees: 0 to the right, clockwise); `bend` its curvature, 1 / radius: with `1 / K.DIAL.r`, and its
  middle on the ring at the clock angle `a` with `dir: a`, it lies exactly along the ring; `top(u)`, `bottom(u)`: how
  far its outer and inner edges are from the line at `u` from 0 (its start) to 1 (its end): `K.DIAL.w / 2` both for
  the ring's own band.
- `K.stache`: the mustache's outline for `K.ribbon`: `.length` (grid units), `.middle` (its middle on the grid),
  `.top(u)`, `.bottom(u)` (grid units; multiply by `box.k`), `.color`. A ribbon of this outline, level and unbent at
  the mustache's place, covers the mustache's picture: so the picture can give way to a shape that then bends,
  stretches and changes color (see `scenes/cheshire.js`).

Everything else is the plain canvas: paths, `arc`, gradients, `clip`, `globalAlpha`, `globalCompositeOperation`,
`filter = 'blur(4px)'`, `shadowBlur`, transforms. Whatever you draw must be something SwiftUI's Canvas can draw too:
pictures, paths, gradients, clipping, blur, shadows, blend modes. No DOM tricks, no CSS animation.

## Seeing it

You cannot watch it play; you look at still pictures of chosen moments:

```
python tools/film.py <id> --n 12 --to 2.8 --s 0.42           # twelve moments of the whole screen, side by side
python tools/film.py <id> --at 0.3,0.4,0.5,0.6 --view 101,337,200,200 --s 1.5 --cols 4   # a close look
```

(run from the folder that holds `tools` and `page`). It prints a PNG's path: look at it with the Read tool. `--view
x,y,w,h` shows only that part of the screen, `--s` times larger. A drawing error is written in red on the picture.
Look at many moments, close together where things move fast (every 0.04 to 0.06 s there), and at the close view of
the man whenever he acts: what reads as a wink at full size may be mush at the icon's size.

And the checks, which must pass before you are done:

```
python tools/check.py <id>
```

It compares pictures: that t = 0 is the launch picture; that from `rest` on the screen is the finished Now screen and
stands still; and that there are no jumps (a frame far more different from the one before than its neighbors are:
something appearing, vanishing or moving at once). A reported jump comes with its moment and place: look at it closely
with `film.py --at` and a `--view`, and make that change continuous. It takes about 15 seconds.

`scenes/cheshire.js` is a finished scene to read first: how a scene is laid out, how the icon becomes the dial's round
face, how the man acts, how a part of him (the mustache) leaves him and becomes a part of the dial. `scenes/today.js`
is what the app plays today.

## What makes it good

- One idea, one line of action the eye can follow, and the logo's own element BECOMES the dial's (a real hand-over
  in shape, place and color over several frames, not a cross-fade).
- Animation's principles, in small: anticipation before a move (a little the other way), ease in and out, overshoot
  and settle (`spring`, `back`), follow-through (the hair and the bow tie arrive a beat after the head: `wobble`),
  arcs rather than straight lines, squash and stretch within 10%. Stagger things by 20 to 60 ms rather than moving
  them together.
- The man is small at 120 points: bring the icon up to 200 to 280 points while he acts, and keep his acting to one or
  two clear gestures.
- Nothing may flash, jump or pop: every value continuous in `t` from the first frame to the last.
- 1.9 to 2.9 seconds until the Now screen is whole; the dial should be readable well before the end.
- Taste: minimal, clean, precise, Apple-like. White and the app's own colors; no tinted backgrounds, no confetti.
