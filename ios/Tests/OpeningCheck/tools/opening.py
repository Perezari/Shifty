"""What the openings' tools share: building the dumper in WSL (the kit, ONE scene and main.swift), asking it for
frames, and taking pictures of them with headless Chrome through the replay page.

The kit is ios/Shifty/Opening/*.swift, a scene ios/Shifty/Opening/Scenes/<Name>.swift (its file's name, in small
letters, is its id; ios/Tests/OpeningCheck/scenes holds two more, which only check the kit). Each scene's dumper is
built on its own, into /tmp/opening-check/<id>/ inside WSL, so a scene half written never breaks another's build.
Pictures and job files go to the temp folder, each under a name of its own, never into the repository.

Several people port scenes at the same time on one machine: a scene's build is locked while it is built, and no more
than a few Chromes take pictures at once, whoever started them (SLOTS).
"""
import contextlib
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)                                   # ios/Tests/OpeningCheck
IOS = os.path.dirname(os.path.dirname(ROOT))                   # ios
KIT = os.path.join(IOS, "Shifty", "Opening")
SCENES = os.path.join(KIT, "Scenes")
CHECKS = os.path.join(ROOT, "scenes")                          # scenes that only check the kit: not the app's
MOCK = os.path.join(ROOT, "mock")
PAGE = os.path.join(ROOT, "replay.html")
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
WORK = os.path.join(tempfile.gettempdir(), "opening-check")
THEMES = ("light", "dark")
BUILTIN = ("launch", "done")
# How many Chromes take pictures at once on this machine, over all the tools running: each draws on several cores
SLOTS = max(2, min(8, (os.cpu_count() or 4) // 3))
# The marks the replay page puts in the four corners of each bare picture once it is drawn: 2 x 2 pixels of this
MARK = (255, 0, 255)


def wsl_path(path):
    path = os.path.abspath(path)
    return "/mnt/" + path[0].lower() + path[2:].replace("\\", "/")


def wsl(command):
    """Runs a command in WSL's login shell; returns (exit code, stdout, stderr) as text."""
    r = subprocess.run(["wsl", "-e", "bash", "-lc", command], capture_output=True)
    return r.returncode, r.stdout.decode("utf-8", "replace"), r.stderr.decode("utf-8", "replace")


def scene_file(scene):
    """The Swift file of the scene with this id: <Name>.swift, whatever its capitals, among the app's scenes
    (ios/Shifty/Opening/Scenes) or the kit's own checks (ios/Tests/OpeningCheck/scenes)."""
    for folder in (SCENES, CHECKS):
        for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
            if name.lower() == scene.lower() + ".swift":
                return os.path.join(folder, name)
    sys.exit(f"no scene file for '{scene}': expected {SCENES}{os.sep}<Name>.swift whose name in small letters is {scene}.swift")


def sources(scene):
    kit = sorted(os.path.join(KIT, f) for f in os.listdir(KIT) if f.endswith(".swift"))
    return kit + [scene_file(scene), os.path.join(ROOT, "main.swift")]


def folder_of(scene):
    """Where a scene's dumper is built, inside WSL: a folder of its own, by its id in small letters."""
    return f"/tmp/opening-check/{scene.lower()}"


def building(scene, force=False):
    """The shell's words that build the scene's dumper in WSL if it is not there, or not of these sources.

    The stamp of the sources it was built of lies beside it, in WSL, whose /tmp is emptied whenever WSL starts again
    (it stops after a minute with nothing to do). The folder is locked meanwhile and the dumper comes into its place
    whole: tools started side by side for one scene (film.py for several layouts, say) wait for one build and never
    write into each other's. The compiler's words go to build.log there, where they stay until the next build
    (build.py shows them, whichever tool built), and to stderr if it fails (exit code 97)."""
    files = sources(scene)
    text = open(scene_file(scene), encoding="utf-8").read()
    kind = re.search(r"\b(?:struct|final\s+class|class)\s+(\w+)\s*:\s*[^{]*\bOpeningScene\b", text)
    if not kind:
        sys.exit(f"{scene_file(scene)} declares no type that is an OpeningScene")
    stamp = hashlib.sha1("|".join(f"{f}:{os.path.getmtime(f)}:{os.path.getsize(f)}" for f in files).encode()).hexdigest()
    folder = folder_of(scene)
    listed = " ".join("'" + wsl_path(f) + "'" for f in files)
    again = f"rm -f {folder}/stamp; " if force else ""
    return (f"mkdir -p {folder} && exec 9>{folder}/lock && flock 9 && {again}"
            f"if [ x$(cat {folder}/stamp 2>/dev/null) != x{stamp} ] || [ ! -x {folder}/dump ]; then "
            f"echo 'func openingCheckScene() -> OpeningScene {{ {kind.group(1)}() }}' > {folder}/Registered.swift; "
            f"if swiftc -swift-version 5 {listed} {folder}/Registered.swift -o {folder}/dump.$$ > {folder}/build.log 2>&1; "
            f"then mv -f {folder}/dump.$$ {folder}/dump; echo {stamp} > {folder}/stamp; "
            f"else cat {folder}/build.log >&2; rm -f {folder}/dump.$$ {folder}/stamp; exit 97; fi; "
            f"fi; flock -u 9")


def build(scene, force=False, quiet=True):
    """Builds the scene's dumper in WSL, unless it is there and its sources are as they were when it was built.
    Returns its path there."""
    folder = folder_of(scene)
    code, out, err = wsl(building(scene, force) + f"; cat {folder}/build.log")
    if code != 0:
        sys.exit("the build failed:\n" + (out + err).strip())
    if out.strip() and not quiet:
        print(out.strip())                                      # warnings
    return f"{folder}/dump"


def run_dump(scene, arguments):
    """Runs the scene's dumper, built first in the same call if need be, and returns what it prints, read."""
    code, out, err = wsl(building(scene) + f"; {folder_of(scene)}/dump {arguments}")
    if code == 97:
        sys.exit("the build failed:\n" + err.strip())
    if code != 0:
        sys.exit(f"the dumper failed ({code}): {err.strip() or out.strip()}")
    return json.loads(out)


def info(scene):
    """The scene's own numbers (rest, end, arrive, poster, haptics...) and the layouts' names."""
    meta = run_dump(scene, "info")
    if meta["scene"] != scene:
        sys.exit(f"the scene in {scene_file(scene)} says its id is '{meta['scene']}': the tools take the file's name "
                 f"in small letters for the id ({os.path.basename(scene_file(scene)).lower()[:-6]}), and are given that")
    return meta


def app_check():
    """Type-checks the kit and every scene of the app's together, as the app compiles them, warnings as errors.
    Returns (passed, the compiler's words, how many scenes)."""
    kit = sorted(os.path.join(KIT, f) for f in os.listdir(KIT) if f.endswith(".swift"))
    scenes = sorted(os.path.join(SCENES, f) for f in os.listdir(SCENES) if f.endswith(".swift"))
    listed = " ".join("'" + wsl_path(f) + "'" for f in kit + scenes)
    code, out, err = wsl(f"swiftc -typecheck -swift-version 5 -warnings-as-errors {listed} 2>&1")
    return code == 0, (out + err).strip(), len(scenes)


def dump(scene, layout, theme, sets, screen=None, facts=None):
    """Frames: `sets` is [(scene id | 'launch' | 'done', [moments]), ...]. Returns what `dump frames` prints.
    `screen` and `facts` are the real screen and its card of facts in the design's points (x, y, w, h), where they
    are not the design's own."""
    parts = [layout, theme]
    if screen:
        parts.append("screen=" + ",".join(str(v) for v in screen))
    if facts:
        parts.append("facts=" + ",".join(str(v) for v in facts))
    parts += [name + "@" + ",".join(f"{t:.6f}".rstrip("0").rstrip(".") or "0" for t in times) for name, times in sets]
    return run_dump(scene, "frames " + " ".join(parts))


def mock_rest(scene):
    """The `rest` the mock's scene of this id declares."""
    text = open(os.path.join(MOCK, "scenes", scene + ".js"), encoding="utf-8").read()
    return float(re.search(r"\brest:\s*([\d.]+)", text).group(1))


def moment(t):
    """A moment as the dumper is given it and gives it back: to a millionth of a second."""
    return float(f"{t:.6f}")


@contextlib.contextmanager
def chrome_slot():
    """A place among the few Chromes that may run at once on this machine (SLOTS), held while a picture is taken:
    one of a few files in the temp folder, locked. With five people checking scenes at once, each tool waits its
    turn rather than all of them starving one another's Chrome."""
    try:
        import msvcrt
    except ImportError:                                         # not Windows: no queue
        yield
        return
    os.makedirs(WORK, exist_ok=True)
    while True:
        for i in range(SLOTS):
            f = open(os.path.join(WORK, f"chrome-{i}.slot"), "a+b")
            try:
                f.seek(0)
                msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
            except OSError:
                f.close()
                continue
            try:
                yield
            finally:
                f.seek(0)
                msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
                f.close()
            return
        time.sleep(0.2)


def shoot(job, width, height, out=None, budget=8000):
    """Opens the replay page on a job (see replay.js) in headless Chrome and takes its picture. Returns its path."""
    os.makedirs(WORK, exist_ok=True)
    tag = f"{os.getpid()}-{uuid.uuid4().hex[:8]}"
    job_file = os.path.join(WORK, f"job-{tag}.js")
    with open(job_file, "w", encoding="utf-8") as f:
        f.write("window.OPENING_JOB = " + json.dumps(job, ensure_ascii=False, separators=(",", ":")) + ";\n")
    out = os.path.abspath(out) if out else os.path.join(WORK, f"shot-{tag}.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if os.path.exists(out):
        os.remove(out)
    url = "file:///" + PAGE.replace("\\", "/") + "#job=file:///" + job_file.replace("\\", "/")
    profile = tempfile.mkdtemp(prefix="opening-chrome-")
    command = [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
               "--no-first-run", "--allow-file-access-from-files", "--run-all-compositor-stages-before-draw",
               f"--user-data-dir={profile}",
               f"--window-size={width},{height}", f"--virtual-time-budget={budget}", f"--screenshot={out}", url]
    try:
        with chrome_slot():
            r = subprocess.run(command, capture_output=True, text=True, timeout=300)
    finally:
        shutil.rmtree(profile, ignore_errors=True)
        os.remove(job_file)
    if not os.path.exists(out):
        sys.exit("no picture from Chrome: " + (r.stderr or r.stdout)[-600:])
    return out


def grid(dumps, cells, s=0.5, cols=15, mock=()):
    """Bare pictures of the cells ({dump, scene, t} or {mock, t}), each as an array of whole numbers (h, w, 3).

    The page marks the four corners of each picture once it is drawn (MARK, 2 x 2 pixels): a sheet Chrome took
    before all of it was drawn lacks some, and is taken again, so that two sheets are never found equal for being
    equally unfinished. The marks are then blacked out: they are no part of what is compared."""
    w, h = round(402 * s), round(874 * s)
    corners = [(slice(0, 2), slice(0, 2)), (slice(0, 2), slice(w - 2, w)), (slice(h - 2, h), slice(0, 2)), (slice(h - 2, h), slice(w - 2, w))]
    shots = []
    step = cols * 12                                            # a dozen rows to a picture: Chrome's are not endless
    for at in range(0, len(cells), step):
        part = cells[at:at + step]
        rows = math.ceil(len(part) / cols)
        job = {"dumps": dumps, "mock": list(mock), "mode": "grid", "s": s, "cols": cols, "cells": part}
        for attempt in range(3):
            out = shoot(job, max(520, cols * w), rows * h)
            sheet = np.asarray(Image.open(out).convert("RGB")).astype(np.int16)
            os.remove(out)
            tiles = [sheet[(i // cols) * h:(i // cols) * h + h, (i % cols) * w:(i % cols) * w + w].copy() for i in range(len(part))]
            whole = all((tile[ys, xs] == MARK).all() for tile in tiles for ys, xs in corners)
            if whole:
                break
        else:
            sys.exit("Chrome's picture was not whole, three times over: some pictures of the sheet were not drawn "
                     "when it was taken (or the page failed: look at a film strip of the same moments)")
        for tile in tiles:
            for ys, xs in corners:
                tile[ys, xs] = 0
        shots += tiles
    return shots


def sheet(dumps, cells, s=0.5, cols=6, view=None, mock=(), out=None):
    """Labelled pictures of the cells side by side, to look at. Returns the picture's path."""
    w, h = (402, 874) if not view else view[2:]
    tile_w, tile_h = w * s, h * s + 15
    cols = min(cols, len(cells))
    rows = math.ceil(len(cells) / cols)
    job = {"dumps": dumps, "mock": list(mock), "mode": "sheet", "s": s, "cells": cells}
    if view:
        job["view"] = dict(zip("xywh", view))
    return shoot(job, max(520, math.ceil(cols * (tile_w + 8) + 8)), math.ceil(rows * (tile_h + 8) + 8), out)


def jumps(shots, times, s=0.5):
    """The mock's own detector (mock/tools/check.py): frames far more different from the one before than their
    neighbours are. Returns (the jumps, the change of each step)."""
    steps = [float(np.abs(shots[i + 1] - shots[i]).mean()) for i in range(len(shots) - 1)]
    found = []
    for i, d in enumerate(steps):
        before = steps[i - 1] if i > 0 else 0.0
        after = steps[i + 1] if i + 1 < len(steps) else 0.0
        near = max(before, after)
        if d > 0.9 and d > 2.4 * max(near, 0.12):
            ys, xs = np.where(np.abs(shots[i + 1] - shots[i]).max(axis=2) > 40)
            box = f"x {int(xs.min() / s)}-{int(xs.max() / s)}, y {int(ys.min() / s)}-{int(ys.max() / s)}" if len(xs) else "all over"
            found.append((times[i], times[i + 1], d, near, box))
    return found, steps
