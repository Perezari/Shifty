"""Still pictures of a Swift scene, taken by headless Chrome through the replay page: its moments side by side, to
see the motion without playing it. For any day on the dial (--layout) in either theme; and, to compare, of the mock's
scene of the same id.

    python tools/film.py <scene id> [--layout mock] [--theme light] [--n 12] [--from 0] [--to <seconds>]
                         [--at 0.2,0.35,0.5] [--s 0.5] [--view x,y,w,h] [--cols 6] [--out <file.png>]
                         [--mock | --both]

--layout  mock (the designed shift, drawn as the mock draws it), running, idle, idleToday, break, overtime, dayOff,
          justStarted, nearlyFull (main.swift)
--theme   light or dark
--n       how many moments, evenly from --from to --to (the scene's `rest` by default); --at: these moments instead
--s       the size of each picture against the real screen (402 x 874 points); with --view, of that part
--view    only this part of the screen, in points: for a close look, e.g. --view 101,337,200,200 --s 2
--mock    the mock's scene (mock/scenes/<id>.js) instead of the Swift one; --both: each moment of both, the mock's first
<scene id> may also be `launch` or `done`, the two fixed ends: then --with <id> names the scene whose dumper draws them.
Prints the picture's path. Look at it with the Read tool.
"""
import argparse
import sys

sys.dont_write_bytecode = True                                  # no __pycache__ in the repository
import opening  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("scene")
ap.add_argument("--layout", default="mock")
ap.add_argument("--theme", default="light", choices=opening.THEMES)
ap.add_argument("--n", type=int, default=12)
ap.add_argument("--from", dest="start", type=float, default=0)
ap.add_argument("--to", type=float, default=None)
ap.add_argument("--at", default=None)
ap.add_argument("--s", type=float, default=0.5)
ap.add_argument("--view", default=None)
ap.add_argument("--cols", type=int, default=6)
ap.add_argument("--out", default=None)
ap.add_argument("--mock", action="store_true")
ap.add_argument("--both", action="store_true")
ap.add_argument("--with", dest="built", default=None, help="the scene whose dumper draws `launch` or `done`")
a = ap.parse_args()

built = a.built or a.scene
if built in opening.BUILTIN and not a.mock:
    ap.error("launch and done are drawn by a real scene's dumper: add --with <scene id>")
view = [float(v) for v in a.view.split(",")] if a.view else None
if a.at:
    times = [float(t) for t in a.at.split(",")]
else:
    to = a.to
    if to is None and a.mock:
        to = opening.mock_rest(a.scene)
    elif to is None:
        to = 0 if a.scene in opening.BUILTIN else opening.info(built)["rest"]
    times = [a.start + (to - a.start) * i / max(1, a.n - 1) for i in range(a.n)]
times = [opening.moment(t) for t in times]

dumps, cells = [], []
if not a.mock:
    dumps = [opening.dump(built, a.layout, a.theme, [(a.scene, times)])]
for t in times:
    if a.mock or a.both:
        cells.append({"mock": a.scene, "t": t, "label": f"t={t:.2f}  mock {a.scene}"})
    if not a.mock:
        cells.append({"dump": 0, "scene": a.scene, "t": t, "label": f"t={t:.2f}  {a.scene} {a.layout} {a.theme}"})
print(opening.sheet(dumps, cells, s=a.s, cols=a.cols, view=view, mock=[a.scene] if a.mock or a.both else [], out=a.out))
