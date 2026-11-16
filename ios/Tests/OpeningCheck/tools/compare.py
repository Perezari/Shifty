"""Holds a Swift scene against the mock's scene of the same id, frame by frame: the Swift frames (the mock's layout,
the light theme, the dial's ticks as the mock draws them) replayed on the mock's page beside the mock's own, both by
the same browser canvas, so they are expected equal but for rounding.

    python tools/compare.py <scene id> [--fps 30] [--to <seconds>] [--tol 2] [--s 0.5] [--out <file.png>]

The tolerance: a frame passes when no pixel of it differs from the mock's by more than --tol levels (of 255) in any
color (2 by default: the last digit of a rounding), at half size (201 x 437 pixels a frame). Prints a report of the
worst frames, and the path of a picture of them: the mock's, the Swift one, and where they differ (in red).
From 0 to the scene's rest + 0.2 by default.
"""
import argparse
import sys
import os

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True                                  # no __pycache__ in the repository
import opening  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("scene")
ap.add_argument("--fps", type=float, default=30)
ap.add_argument("--to", type=float, default=None)
ap.add_argument("--tol", type=int, default=2)
ap.add_argument("--s", type=float, default=0.5)
ap.add_argument("--out", default=None)
a = ap.parse_args()

meta = opening.info(a.scene)
upto = a.to if a.to is not None else meta["rest"] + 0.2
times = [opening.moment(i / a.fps) for i in range(int(round(upto * a.fps)) + 1)]
dumped = opening.dump(a.scene, "mock", "light", [(a.scene, times)])
# two sheets, each moment at the same place in both: Chrome lays letters a hair differently from place to place
mocks = opening.grid([], [{"mock": a.scene, "t": t} for t in times], s=a.s, mock=[a.scene])
swifts = opening.grid([dumped], [{"dump": 0, "scene": a.scene, "t": t} for t in times], s=a.s)

rows = []
for i, t in enumerate(times):
    mock, swift = mocks[i], swifts[i]
    d = np.abs(mock - swift).max(axis=2)
    rows.append((int(d.max()), int((d > a.tol).sum()), t, i, d))
bad = [r for r in rows if r[0] > a.tol]
worst = sorted(rows, key=lambda r: (-r[0], -r[1]))[:6]
print(f"scene {a.scene}: {len(times)} frames from 0 to {times[-1]:.2f} at {a.fps:g} a second, the mock's layout, light; "
      f"each {mocks[0].shape[1]} x {mocks[0].shape[0]} pixels")
print(f"  tolerance: no pixel more than {a.tol} levels (of 255) from the mock's in any color")
print(f"  frames equal to the pixel: {sum(1 for r in rows if r[0] == 0)}; within the tolerance: {len(rows) - len(bad)}; "
      f"beyond it: {len(bad)}")
print(f"  the largest difference anywhere: {max(r[0] for r in rows)} levels")
if bad:
    print("  the worst frames:")
    for largest, count, t, i, d in worst:
        if largest <= a.tol:
            continue
        ys, xs = np.where(d > a.tol)
        print(f"    t = {t:.3f}: largest difference {largest}, pixels beyond the tolerance {count}, "
              f"within x {int(xs.min() / a.s)}-{int(xs.max() / a.s)}, y {int(ys.min() / a.s)}-{int(ys.max() / a.s)} (screen points)")

# a picture of the worst frames: the mock's, the Swift one, and the difference in red over a pale copy
shown = [r for r in worst if r[0] > 0] or worst[:1]
h, w = mocks[0].shape[:2]
picture = Image.new("RGB", (len(shown) * (3 * w + 16), h + 16), (217, 220, 228))
for n, (largest, count, t, i, d) in enumerate(shown):
    mock, swift = mocks[i].astype(np.uint8), swifts[i].astype(np.uint8)
    pale = (255 - (255 - swift.astype(np.int16)) // 4).astype(np.uint8)
    pale[d > 0] = (255, 170, 170)
    pale[d > a.tol] = (220, 0, 0)
    for j, tile in enumerate((mock, swift, pale)):
        picture.paste(Image.fromarray(tile), (8 + n * (3 * w + 16) + j * w, 8))
out = os.path.abspath(a.out) if a.out else os.path.join(opening.WORK, f"compare-{a.scene}.png")
picture.save(out)
print(f"  the worst frames side by side (each: mock, Swift, difference): {out}")
print("  they are: " + ", ".join(f"t={t:.3f}" for _, _, t, _, _ in shown))
print("PASSED" if not bad else "NOT PASSED")
