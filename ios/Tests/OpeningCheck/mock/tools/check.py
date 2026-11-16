"""Checks a scene of the openings' page by its pictures:
  1. its first frame is the launch picture (the same as the scene 'today' at t = 0);
  2. from its `rest` on it is the finished Now screen (the same as 'today' long after its end), and stands still;
  3. no jumps: no frame differs from the one before far more than its neighbors do (a pop: something appearing,
     vanishing or moving at once).

    python tools/check.py <scene id> [--fps 30] [--to <seconds>]

Prints a report. A jump is given with its moment: look at it closely with
    python tools/film.py <id> --at <a little before>,<the moment>,<a little after> ...
"""
import argparse
import math
import os
import re
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
PAGE = os.path.abspath(os.path.join(HERE, "..", "page", "index.html"))
S, W, H = 0.5, 201, 437


def frames(scene, times, cols=15):
    rows = math.ceil(len(times) / cols)
    width, height = max(520, cols * W), rows * H
    url = "file:///" + PAGE.replace("\\", "/") + f"#frames={scene}&s={S}&cols={cols}&at=" + ",".join(f"{t:.4f}" for t in times)
    out = os.path.join(tempfile.gettempdir(), f"check-{scene}-{os.getpid()}-{len(times)}.png")
    profile = tempfile.mkdtemp(prefix="check-chrome-")
    cmd = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1", "--no-first-run",
           "--allow-file-access-from-files", f"--user-data-dir={profile}", f"--window-size={width},{height}",
           "--virtual-time-budget=8000", f"--screenshot={out}", url]
    subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if not os.path.exists(out):
        sys.exit("no picture from Chrome")
    sheet = np.asarray(Image.open(out).convert("RGB")).astype(np.int16)
    os.remove(out)
    return [sheet[(i // cols) * H:(i // cols) * H + H, (i % cols) * W:(i % cols) * W + W] for i in range(len(times))]


def scene_numbers(scene):
    text = open(os.path.join(os.path.dirname(PAGE), "scenes", scene + ".js"), encoding="utf-8").read()
    end = float(re.search(r"\bend:\s*([\d.]+)", text).group(1))
    rest = float(re.search(r"\brest:\s*([\d.]+)", text).group(1))
    return rest, end


def differ(a, b):
    d = np.abs(a - b).max(axis=2)
    return int(d.max()), int((d > 24).sum())


ap = argparse.ArgumentParser()
ap.add_argument("scene")
ap.add_argument("--fps", type=float, default=30)
ap.add_argument("--to", type=float, default=None)
a = ap.parse_args()

rest, end = scene_numbers(a.scene)
ok = True
print(f"scene {a.scene}: rest {rest}, end {end}")
if not (1.7 <= rest <= 3.3):
    print(f"  NOTE rest is {rest} s: the Now screen should be whole between about 1.9 and 2.9 s")

# 1 and 2: the two fixed ends, against the scene 'today'
late = [rest, (rest + end) / 2, end - 0.05]
mine = frames(a.scene, [0.0] + late, cols=4)
ref = frames("today", [0.0] + [t + 5 for t in late], cols=4)   # 'today' long after its end: the finished Now screen
worst, count = differ(mine[0], ref[0])
good = count <= 8
ok &= good
print(f"  {'ok  ' if good else 'FAIL'} t = 0 is the launch picture (largest difference {worst}, pixels off {count})")
# the timer's text ticks on by the scene's own clock: leave its line out of the comparison
mask = np.ones((H, W), bool)
mask[int(250 * S):int(312 * S), int(60 * S):int(342 * S)] = False
for t, m, r in zip(late, mine[1:], ref[1:]):
    d = np.abs(m - r).max(axis=2) * mask
    worst, count = int(d.max()), int((d > 24).sum())
    good = count <= 8
    ok &= good
    where = ""
    if not good:
        ys, xs = np.where(d > 24)
        where = f"; off within x {int(xs.min() / S)}-{int(xs.max() / S)}, y {int(ys.min() / S)}-{int(ys.max() / S)} (screen points)"
    print(f"  {'ok  ' if good else 'FAIL'} t = {t:.2f} is the finished Now screen (largest difference {worst}, pixels off {count}{where})")

# 3: jumps
upto = a.to if a.to is not None else rest + 0.3
n = int(round(upto * a.fps)) + 1
times = [i / a.fps for i in range(n)]
shots = frames(a.scene, times)
steps = [float(np.abs(shots[i + 1] - shots[i]).mean()) for i in range(n - 1)]
jumps = []
for i, d in enumerate(steps):
    before = steps[i - 1] if i > 0 else 0.0
    after = steps[i + 1] if i + 1 < len(steps) else 0.0
    near = max(before, after)
    if d > 0.9 and d > 2.4 * max(near, 0.12):
        ys, xs = np.where(np.abs(shots[i + 1] - shots[i]).max(axis=2) > 40)
        box = f"x {int(xs.min() / S)}-{int(xs.max() / S)}, y {int(ys.min() / S)}-{int(ys.max() / S)}" if len(xs) else "all over"
        jumps.append((times[i], times[i + 1], d, near, box))
if jumps:
    ok = False
    print(f"  FAIL {len(jumps)} jump(s): a frame far more different from the one before than its neighbors are")
    for t0, t1, d, near, box in jumps:
        print(f"       between t = {t0:.3f} and {t1:.3f}: change {d:.2f} against {near:.2f} beside it; in {box} (screen points)")
else:
    print(f"  ok   no jumps at {a.fps:g} frames a second up to t = {upto:.2f}")
busy = sorted(range(len(steps)), key=lambda i: -steps[i])[:5]
print("  the busiest moments (most change from one frame to the next): " + ", ".join(f"t={times[i]:.2f} ({steps[i]:.1f})" for i in sorted(busy)))
still = [i for i, d in enumerate(steps) if times[i] >= 0.2 and d < 0.004 and times[i] < rest - 0.5]
if still:
    runs = []
    for i in still:
        if runs and i == runs[-1][1] + 1:
            runs[-1][1] = i
        else:
            runs.append([i, i])
    long = [(times[r0], times[r1 + 1]) for r0, r1 in runs if r1 - r0 + 1 >= max(3, int(0.12 * a.fps))]
    if long:
        print("  NOTE nothing moves at all during: " + ", ".join(f"{x:.2f}-{y:.2f}" for x, y in long) + " (a held breath is fine; a dead spot is not)")
print("PASSED" if ok else "NOT PASSED")
