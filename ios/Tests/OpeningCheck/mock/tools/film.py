"""Still pictures of a scene of the openings' page, taken by headless Chrome: its moments side by side, to see the
motion without playing it.

    python tools/film.py <scene id> [--n 12] [--from 0] [--to <seconds>] [--at 0.2,0.35,0.5] [--s 0.5]
                         [--view x,y,w,h] [--cols 6] [--out <file.png>] [--page <index.html>]

--n       how many moments, evenly from --from to --to (the scene's `rest` by default)
--at      these moments instead
--s       the size of each picture against the real screen (402 x 874 points); with --view, of that part
--view    only this part of the screen, in points: for a close look at the icon, e.g. --view 101,337,200,200 --s 2
Prints the picture's path. Look at it with the Read tool.
"""
import argparse
import math
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

ap = argparse.ArgumentParser()
ap.add_argument("scene")
ap.add_argument("--n", type=int, default=12)
ap.add_argument("--from", dest="start", type=float, default=0)
ap.add_argument("--to", type=float, default=None)
ap.add_argument("--at", default=None)
ap.add_argument("--s", type=float, default=0.5)
ap.add_argument("--view", default=None)
ap.add_argument("--cols", type=int, default=6)
ap.add_argument("--out", default=None)
ap.add_argument("--page", default=os.path.join(HERE, "..", "page", "index.html"))
a = ap.parse_args()

page = os.path.abspath(a.page)
count = len(a.at.split(",")) if a.at else a.n
w, h = (402, 874)
if a.view:
    w, h = [float(v) for v in a.view.split(",")][2:]
tile_w, tile_h = w * a.s, h * a.s + 15
cols = min(a.cols, count)
rows = math.ceil(count / cols)
width = max(520, math.ceil(cols * (tile_w + 8) + 8))
height = math.ceil(rows * (tile_h + 8) + 8)

parts = [f"film={a.scene}", f"s={a.s}"]
if a.at:
    parts.append(f"at={a.at}")
else:
    parts += [f"n={a.n}", f"from={a.start}"]
    if a.to is not None:
        parts.append(f"to={a.to}")
if a.view:
    parts.append(f"view={a.view}")
url = "file:///" + page.replace("\\", "/") + "#" + "&".join(parts)
out = os.path.abspath(a.out) if a.out else os.path.join(tempfile.gettempdir(), f"film-{a.scene}-{os.getpid()}.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
profile = tempfile.mkdtemp(prefix="film-chrome-")
cmd = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1", "--no-first-run",
       "--allow-file-access-from-files", f"--user-data-dir={profile}", f"--window-size={width},{height}",
       "--virtual-time-budget=6000", f"--screenshot={out}", url]
r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
if not os.path.exists(out):
    sys.exit("no picture: " + (r.stderr or r.stdout)[-600:])
print(out)
