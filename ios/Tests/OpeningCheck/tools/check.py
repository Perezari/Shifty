"""Checks a Swift scene by its pictures, for a day on the dial and a theme:
  1. its first frame is the launch picture: the built-in scene `launch`;
  2. from its `rest` on it is the finished Now screen, and stands still: the built-in scene `done`;
  3. no jumps: no frame differs from the one before far more than its neighbors do (a pop: something appearing,
     vanishing or moving at once). The same detector as mock/tools/check.py;
  4. every number of every frame is one: none is NaN or infinite (a division by an angle of the day's that is 0).
     The dumper writes such a number as 0, so the shape lands at the screen's corner or is not drawn, and counts
     them in each frame ("bad" in its JSON, main.swift): a day with any fails, and its moments are named.

    python tools/check.py <scene id> [--layout mock] [--theme light] [--fps 30] [--to <seconds>]
    python tools/check.py <scene id> all [--jobs 4]          every layout in both themes, and a table of them

The two ends are drawn by the same canvas from the same lists, so they are held to the pixel: no pixel may be more
than 2 levels (of 255) off. A jump is given with its moment and place: look at it closely with
    python tools/film.py <id> --layout <layout> --theme <theme> --at <a little before>,<the moment>,<a little after> --view ...
"""
import argparse
import sys
from concurrent.futures import ThreadPoolExecutor

import numpy as np

sys.dont_write_bytecode = True                                  # no __pycache__ in the repository
import opening  # noqa: E402

S = 0.5
TOL = 2


def unfinished(dumped):
    """The report's lines on the numbers that are not numbers (NaN, infinite) in what was dumped: nothing if there
    are none, else each scene's moments that have some, a run of frames one after another as one stretch."""
    lines = []
    for one in dumped["sets"]:
        runs = []                                               # [first moment, last moment, frames, most in a frame]
        last = None
        for i, frame in enumerate(one["frames"]):
            n = frame.get("bad", 0)
            if not n:
                continue
            if runs and last == i - 1:
                runs[-1][1:] = [frame["t"], runs[-1][2] + 1, max(runs[-1][3], n)]
            else:
                runs.append([frame["t"], frame["t"], 1, n])
            last = i
        if runs:
            lines.append(f"       {one['scene']}: " + ", ".join(
                f"t = {a:.3f} ({most})" if count == 1 else f"t = {a:.3f} to {b:.3f} ({count} frames, {most} at most in one)"
                for a, b, count, most in runs))
    return lines


def check(scene, meta, layout, theme, fps=30, upto=None):
    """Returns (passed, the report's lines)."""
    rest, end = meta["rest"], meta["end"]
    lines = [f"scene {scene}, layout {layout}, {theme}: rest {rest}, end {end}"]
    ok = True
    if not (1.7 <= rest <= 3.3):
        lines.append(f"  NOTE rest is {rest} s: the Now screen should be whole between about 1.9 and 2.9 s")
    late = [opening.moment(t) for t in (rest, rest + 0.1, (rest + end) / 2, end - 0.05)]
    upto = upto if upto is not None else rest + 0.3
    n = int(round(upto * fps)) + 1
    times = [opening.moment(i / fps) for i in range(n)]
    dumped = opening.dump(scene, layout, theme, [(scene, sorted(set([0.0] + late + times))), ("launch", [0.0]), ("done", late)])
    # 4: numbers that are not numbers, first: they explain a picture that is wrong below
    bad = unfinished(dumped)
    ok &= not bad
    lines.append("  FAIL numbers that are not numbers (NaN or infinite, written as 0: the shape lands at the screen's corner "
                 "or is not drawn); the moments, and how many in a frame:" if bad
                 else "  ok   every number of every frame is one (none NaN or infinite)")
    lines += bad
    # two sheets: the scene's frames, and the two ends they are held against, each at the place of the frame it is
    # held against (Chrome lays letters a hair differently from place to place)
    shots = opening.grid([dumped], [{"dump": 0, "scene": scene, "t": t} for t in [0.0] + late + times], s=S)
    ends = opening.grid([dumped], [{"dump": 0, "scene": "launch", "t": 0.0}] + [{"dump": 0, "scene": "done", "t": t} for t in late], s=S)

    def differ(a, b):
        d = np.abs(a - b).max(axis=2)
        where = ""
        if (d > TOL).any():
            ys, xs = np.where(d > TOL)
            where = f"; off within x {int(xs.min() / S)}-{int(xs.max() / S)}, y {int(ys.min() / S)}-{int(ys.max() / S)} (screen points)"
        return int(d.max()), int((d > TOL).sum()), where

    # 1 and 2: the two fixed ends
    worst, count, where = differ(shots[0], ends[0])
    good = count == 0
    ok &= good
    lines.append(f"  {'ok  ' if good else 'FAIL'} t = 0 is the launch picture (largest difference {worst}, pixels off {count}{where})")
    for i, t in enumerate(late):
        worst, count, where = differ(shots[1 + i], ends[1 + i])
        good = count == 0
        ok &= good
        lines.append(f"  {'ok  ' if good else 'FAIL'} t = {t:.2f} is the finished Now screen (largest difference {worst}, pixels off {count}{where})")

    # 3: jumps
    moving = shots[1 + len(late):]
    found, steps = opening.jumps(moving, times, S)
    if found:
        ok = False
        lines.append(f"  FAIL {len(found)} jump(s): a frame far more different from the one before than its neighbors are")
        for t0, t1, d, near, box in found:
            lines.append(f"       between t = {t0:.3f} and {t1:.3f}: change {d:.2f} against {near:.2f} beside it; in {box} (screen points)")
    else:
        lines.append(f"  ok   no jumps at {fps:g} frames a second up to t = {upto:.2f}")
    busy = sorted(range(len(steps)), key=lambda i: -steps[i])[:5]
    lines.append("  the busiest moments (most change from one frame to the next): "
                 + ", ".join(f"t={times[i]:.2f} ({steps[i]:.1f})" for i in sorted(busy)))
    still = [i for i, d in enumerate(steps) if times[i] >= 0.2 and d < 0.004 and times[i] < rest - 0.5]
    if still:
        runs = []
        for i in still:
            if runs and i == runs[-1][1] + 1:
                runs[-1][1] = i
            else:
                runs.append([i, i])
        long = [(times[r0], times[r1 + 1]) for r0, r1 in runs if r1 - r0 + 1 >= max(3, int(0.12 * fps))]
        if long:
            lines.append("  NOTE nothing moves at all during: " + ", ".join(f"{x:.2f}-{y:.2f}" for x, y in long)
                         + " (a held breath is fine; a dead spot is not)")
    lines.append("PASSED" if ok else "NOT PASSED")
    return ok, lines


ap = argparse.ArgumentParser()
ap.add_argument("scene")
ap.add_argument("all", nargs="?", choices=["all"], default=None)
ap.add_argument("--layout", default="mock")
ap.add_argument("--theme", default="light", choices=opening.THEMES)
ap.add_argument("--fps", type=float, default=30)
ap.add_argument("--to", type=float, default=None)
ap.add_argument("--jobs", type=int, default=4)
a = ap.parse_args()

meta = opening.info(a.scene)                                    # builds it too, once, before any thread asks
if not a.all:
    ok, lines = check(a.scene, meta, a.layout, a.theme, a.fps, a.to)
    print("\n".join(lines))
    sys.exit(0 if ok else 1)

combos = [(layout, theme) for layout in meta["layouts"] for theme in opening.THEMES]
with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
    results = list(pool.map(lambda c: check(a.scene, meta, c[0], c[1], a.fps, a.to), combos))
failed = []
for (layout, theme), (ok, lines) in zip(combos, results):
    if not ok:
        failed.append(f"{layout} {theme}")
        print("\n".join(lines))
        print()
print(f"scene {a.scene}: every layout in both themes")
for (layout, theme), (ok, lines) in zip(combos, results):
    notes = sum(1 for line in lines if "NOTE" in line)
    print(f"  {'ok  ' if ok else 'FAIL'} {layout:<12} {theme:<5}" + (f"  ({notes} note(s): run it alone to read them)" if notes and ok else ""))
print(f"PASSED: all {len(combos)}" if not failed else f"NOT PASSED: {len(failed)} of {len(combos)} ({', '.join(failed)})")
sys.exit(0 if not failed else 1)
