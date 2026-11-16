#!/usr/bin/env python3
"""The man of the logo cut into layers that move on their own, for the openings (ios/Shifty/Opening: OpeningRig.swift
has each layer's place, OpeningKit.swift puts him together of them): his shirt, his head (its features taken out and
the skin painted under them), the eyebrows, the eyes, the mustache and its two halves, the bow tie's wings and its
knot, and all of him in one. Each is cut out of the logo (ios/brand/MrShift.webp) with icons.cut, as the icons are,
brought to 1024 pixels to the logo's side (two pixels to a unit of the icon's grid of 512), cropped to what it holds
and written as an image set of one picture, OpeningRig-<name>.

    python ios/scripts/rig.py                  # writes into ios/Shifty/Assets.xcassets; needs numpy, scipy and Pillow
    python ios/scripts/rig.py --check FOLDER   # and holds each picture against FOLDER/<name>.png, pixel for pixel

The openings were designed and checked with these very pictures (ios/Tests/OpeningCheck/mock/assets, cut by
mock/tools/rig.py, of which this is the same code): `--check ios/Tests/OpeningCheck/mock/assets` says so. It prints
the layers' places and the man's points, which are OpeningRig.swift's numbers.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.interpolate import griddata

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icons  # noqa: E402

PREFIX = "OpeningRig-"
LINE = np.array([2.0, 19.0, 50.0])
SKIN_NECK = np.array([243.0, 172.0, 121.0])


def layers():
    """Each layer's colors and alpha at the logo's size (name: (rgb, alpha)), the whole man, and his points on the
    icon's grid."""
    man, _ = icons.cut(icons.SOURCE)
    A = np.asarray(man).astype(float)
    H, W = A.shape[:2]
    rgb, al = A[..., :3].copy(), A[..., 3] / 255
    lum = rgb @ np.array([0.299, 0.587, 0.114])
    yy, xx = np.mgrid[0:H, 0:W]

    dark = (rgb.max(axis=2) < 100) & (al > 0.8)
    lab, _ = ndimage.label(dark)

    def comp_in(x0, y0, x1, y1):
        best, size = None, 0
        for i in np.unique(lab[y0:y1, x0:x1]):
            if i == 0:
                continue
            m = lab == i
            ys, xs = np.where(m)
            if xs.min() >= x0 - 2 and xs.max() <= x1 + 2 and ys.min() >= y0 - 2 and ys.max() <= y1 + 2 and m.sum() > size:
                best, size = m, m.sum()
        return best

    features = {
        "stache": comp_in(570, 600, 960, 780), "browL": comp_in(520, 480, 672, 575), "browR": comp_in(745, 440, 866, 505),
        "eyeL": comp_in(570, 565, 700, 640), "eyeR": comp_in(772, 525, 886, 594),
    }
    for k, m in features.items():
        assert m is not None, k
        features[k] = ndimage.binary_fill_holes(m)

    def soft_feature(mask, pad=6):
        """A dark feature on light skin as a layer: its own colors inside, and round its edge the line's color with
        the alpha the picture's blend there gives."""
        region = ndimage.binary_dilation(mask, iterations=pad)
        inner = ndimage.binary_erosion(mask, iterations=2)
        skin = 228.0
        feat = float(np.median(lum[mask]))
        a = np.clip((skin - lum) / (skin - min(feat, 60)), 0, 1)
        alpha = np.where(inner, 1.0, np.where(region, a, 0.0))
        color = np.where(inner[..., None], rgb, LINE[None, None, :])
        return color, alpha

    def inpaint(img, hole, ok, reach=5):
        """The hole filled from the pixels round it that are `ok`, each color by linear interpolation."""
        ring = ndimage.binary_dilation(hole, iterations=reach) & ~hole & ok
        src = np.argwhere(ring)[::3]
        dst = np.argwhere(hole)
        out = img.copy()
        for c in range(3):
            vals = img[..., c][ring][::3]
            v = griddata(src, vals, dst, method="linear")
            near = griddata(src, vals, dst, method="nearest")
            out[..., c][hole] = np.where(np.isnan(v), near, v)
        return out

    # ---- the bow tie: its three blue fills, widened to take their outline
    blue = (rgb[..., 2] > rgb[..., 0] + 45) & (rgb[..., 2] > 60) & (al > 0.8)
    blab, _ = ndimage.label(blue)
    spots = {"wingL": (520, 990), "knot": (645, 990), "wingR": (800, 1000)}
    fills = {name: blab == blab[y, x] for name, (x, y) in spots.items()}
    for name, (x, y) in spots.items():
        assert blab[y, x] != 0, name
    fill_all = fills["wingL"] | fills["knot"] | fills["wingR"]
    darkish = (lum < 120) & (al > 0.5)
    bow_hard = (ndimage.binary_dilation(fill_all, iterations=25) & darkish) | fill_all
    bow_hard |= ndimage.binary_dilation(fill_all, iterations=42) & (lum < 90) & (al > 0.5) & (yy > 1010)
    bow_hard = ndimage.binary_fill_holes(ndimage.binary_closing(bow_hard, iterations=3))
    bow_hard &= (yy > 870) & (yy < 1135) & (xx > 400) & (xx < 925)
    # the button below the knot is not the bow's
    button = comp_in(610, 1110, 678, 1176)
    bow_hard &= ~ndimage.binary_dilation(button, iterations=8)
    bl, _ = ndimage.label(bow_hard)
    bow_hard = bl == bl[990, 645]

    # ---- head and body: what is left, split where they barely touch (beside the bow): each pixel to the nearer core
    solid = (al > 0.5) & ~bow_hard
    for k in range(2, 60):
        cores = ndimage.binary_erosion(solid, iterations=k)
        cl, _ = ndimage.label(cores)
        if cl[770, 800] and cl[1150, 300] and cl[770, 800] != cl[1150, 300]:
            break
    core_head, core_body = cl == cl[770, 800], cl == cl[1150, 300]
    dh = ndimage.distance_transform_edt(~core_head)
    db = ndimage.distance_transform_edt(~core_body)
    rest = (al > 0.02) & ~bow_hard
    head_m, body_m = rest & (dh <= db), rest & (dh > db)

    def extended(color, mask, into, by=6):
        """`mask` grown by `by` pixels into `into`, each new pixel in the color of the nearest one of the mask."""
        dist, idx = ndimage.distance_transform_edt(~(mask & (al > 0.9)), return_indices=True)
        grow = into & ~mask & (dist <= by)
        out = color.copy()
        out[grow] = color[idx[0][grow], idx[1][grow]]
        return out, grow

    def stub(side_mask):
        """Where a line of `side_mask` runs into the bow: its middle there."""
        near = side_mask & (lum < 90) & ndimage.binary_dilation(bow_hard, iterations=4)
        ll, ln = ndimage.label(near)
        out = []
        for i in range(1, ln + 1):
            m = ll == i
            if m.sum() > 40:
                cy, cx = np.where(m)
                out.append((float(cx.mean()), float(cy.mean()), int(m.sum())))
        return sorted(out)

    def clean_fringe(color, mask, by=5):
        """The pixels of `mask` beside the bow are blends with its outline: each takes the color of the nearest pixel
        of the mask farther from the bow, unless it is itself a dark line."""
        near_bow = ndimage.distance_transform_edt(~bow_hard) <= by
        fringe = mask & near_bow & ((lum > 60) | ((xx > 532) & (xx < 812)))
        good = mask & ~near_bow & (al > 0.9) & ((lum > 60) | ~((xx > 532) & (xx < 812)))
        _, idx = ndimage.distance_transform_edt(~good, return_indices=True)
        out = color.copy()
        out[fringe] = color[idx[0][fringe], idx[1][fringe]]
        return out

    # the head: the features out, the skin painted in their place; a little of it goes on under the bow
    head_rgb = rgb.copy()
    skinlike = (rgb[..., 0] > 200) & (rgb[..., 1] > 150) & (al > 0.9)
    holes = np.zeros((H, W), bool)
    for m in features.values():
        holes |= ndimage.binary_dilation(m, iterations=8)
    head_rgb = inpaint(head_rgb, holes & head_m, skinlike & head_m & ~holes)
    head_rgb = clean_fringe(head_rgb, head_m)
    head_rgb, grown = extended(head_rgb, head_m, bow_hard)
    head_alpha = np.where(head_m, al, 0.0)
    head_alpha[grown] = 1

    # the body: under the bow the shirt goes on, shaded as round it, up to a round collar from one shoulder's line to
    # the other's, and above the collar the neck
    shoulders = stub(body_m)
    upper = [p for p in shoulders if p[1] < 1000]
    sl, sr = min(upper, key=lambda p: p[0]), max(upper, key=lambda p: p[0])
    P0, P2 = np.array(sl[:2]), np.array(sr[:2])
    C = np.array([(P0[0] + P2[0]) / 2 + 8, max(P0[1], P2[1]) + 150])
    ts = np.linspace(0, 1, 400)
    curve = ((1 - ts) ** 2)[:, None] * P0 + (2 * (1 - ts) * ts)[:, None] * C + (ts ** 2)[:, None] * P2
    collar_y = np.interp(xx[0], curve[:, 0], curve[:, 1], left=curve[0, 1], right=curve[-1, 1])
    body_rgb = clean_fringe(rgb.copy(), body_m)
    shirtlike = body_m & (al > 0.9) & (lum > 150) & (ndimage.distance_transform_edt(~bow_hard) > 5)
    shirt = bow_hard & (yy >= collar_y[None, :])
    body_rgb = inpaint(body_rgb, shirt, shirtlike, reach=16)
    body_rgb, grown = extended(body_rgb, body_m, head_m & (lum < 90))
    body_alpha = np.where(body_m, al, 0.0)
    body_alpha[grown] = 1
    body_alpha[shirt] = 1
    under = bow_hard | (ndimage.binary_dilation(bow_hard, iterations=6) & head_m)
    neck = under & (yy < collar_y[None, :]) & (xx > P0[0]) & (xx < P2[0])
    body_rgb[neck] = SKIN_NECK
    body_alpha[neck] = 1
    strokes = Image.new("L", (W, H), 0)
    ImageDraw.Draw(strokes).line([tuple(pt) for pt in curve], fill=255, width=21, joint="curve")
    strokes = (np.asarray(strokes) > 127) & bow_hard
    body_rgb[strokes] = LINE
    body_alpha[strokes] = 1

    # ---- the bow's layers
    bow_rgb = rgb.copy()
    edge = ndimage.binary_dilation(bow_hard, iterations=3) & ~bow_hard
    bow_alpha = np.where(bow_hard, 1.0, 0.0)
    bow_alpha = np.where(edge, np.clip((235 - lum) / (235 - 40), 0, 1) * (al > 0.02), bow_alpha)
    bow_rgb[edge] = LINE
    KNOT = (645.0, 990.0, 61.0)
    knot_d = np.hypot(xx - KNOT[0], yy - KNOT[1])
    knot_alpha = np.clip(KNOT[2] - knot_d + 0.5, 0, 1) * (bow_alpha > 0)
    knot_rgb = rgb.copy()
    # the knot's rim: the line's color outside its own fill, so that the wings' blue does not ride on it
    kfill = ndimage.binary_dilation(fills["knot"], iterations=3)
    knot_rgb[~kfill] = LINE
    wings_rgb = bow_rgb.copy()
    wings_rgb[knot_d < KNOT[2] + 2] = LINE
    wings_alpha = bow_alpha

    out = {"body": (body_rgb, body_alpha), "head": (head_rgb, head_alpha), "wings": (wings_rgb, wings_alpha),
           "knot": (knot_rgb, knot_alpha)}
    for k, m in features.items():
        out[k] = soft_feature(m)
    # the mustache's halves, each a little past the middle (the column where its top edge dips between its two bumps)
    # as a round hinge about the pivot, so that the two can turn without a gap
    sc, sa = out["stache"]
    ys, xs = np.where(features["stache"])
    cols = np.arange(730, 860)
    tops = np.array([np.where(features["stache"][:, x])[0].min() for x in cols])
    mid_x = int(cols[np.argmax(tops)])
    col = np.where(features["stache"][:, mid_x])[0]
    mid_y = int((col.min() + col.max()) / 2)
    hinge_r = (col.max() - col.min()) / 2 - 1
    hinge = np.clip(hinge_r - np.hypot(xx - mid_x, yy - mid_y) + 0.5, 0, 1)
    out["stacheL"] = (sc, sa * np.maximum(np.clip((mid_x + 1 - xx) / 2.0, 0, 1), hinge))
    out["stacheR"] = (sc, sa * np.maximum(np.clip((xx - (mid_x - 1)) / 2.0, 0, 1), hinge))

    G = 512 / W

    def centroid(m):
        cy, cx = np.where(m)
        return [round(float(cx.mean()) * G, 1), round(float(cy.mean()) * G, 1)]

    points = {"neck": [round(650 * G, 1), round(928 * G, 1)], "stache": [round(mid_x * G, 1), round(mid_y * G, 1)],
              "stacheBox": [round(float(v) * G, 1) for v in (xs.min(), ys.min(), xs.max(), ys.max())],
              "knot": [round(KNOT[0] * G, 1), round(KNOT[1] * G, 1), round(KNOT[2] * G, 1)]}
    for k in ("browL", "browR", "eyeL", "eyeR"):
        points[k] = centroid(features[k])
    hy, hx = np.where(head_m)
    points["headTop"] = [round(float(hx[hy.argmin()]) * G, 1), round(float(hy.min()) * G, 1)]
    points["headBox"] = [round(float(v) * G, 1) for v in (hx.min(), hy.min(), hx.max(), hy.max())]
    points["button"] = centroid(button)
    return out, man, points


def pictures():
    """The pictures as they are written (name: RGBA picture), and each one's place on the icon's grid of 512."""
    cut, man, points = layers()
    out, places = {}, {}
    for name, (c, a) in cut.items():
        img = Image.fromarray(np.dstack([c, a * 255]).clip(0, 255).astype(np.uint8), "RGBA")
        big = img.convert("RGBa").resize((1024, 1024), Image.LANCZOS).convert("RGBA")
        box = big.getbbox()
        box = (max(0, box[0] - 2), max(0, box[1] - 2), min(1024, box[2] + 2), min(1024, box[3] + 2))
        out[name] = big.crop(box)
        places[name] = {"x": box[0] / 2, "y": box[1] / 2, "w": (box[2] - box[0]) / 2, "h": (box[3] - box[1]) / 2}
    out["man"] = man.convert("RGBa").resize((1024, 1024), Image.LANCZOS).convert("RGBA")
    places["man"] = {"x": 0.0, "y": 0.0, "w": 512.0, "h": 512.0}
    return out, places, points


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", metavar="FOLDER", help="pictures to hold these against: FOLDER/<name>.png")
    a = ap.parse_args()
    made, places, points = pictures()
    for name in sorted(made):
        folder = os.path.join(icons.ASSETS, PREFIX + name + ".imageset")
        icons.save(made[name], folder, PREFIX + name + ".png", mode=None)
        icons.contents(folder, [{"filename": PREFIX + name + ".png", "idiom": "universal"}])
        p = places[name]
        print(f"{PREFIX + name:22} {made[name].width:4} x {made[name].height:<4}  at {p['x']}, {p['y']}  {p['w']} x {p['h']}")
    print("points", points)
    if a.check:
        same = True
        for name in sorted(made):
            path = os.path.join(a.check, name + ".png")
            if not os.path.exists(path):
                print("no", path)
                same = False
                continue
            other = Image.open(path).convert("RGBA")
            written = Image.open(os.path.join(icons.ASSETS, PREFIX + name + ".imageset", PREFIX + name + ".png")).convert("RGBA")
            if other.size != written.size:
                print(f"{name}: {written.size} here, {other.size} there")
                same = False
                continue
            diff = np.abs(np.asarray(written).astype(int) - np.asarray(other).astype(int))
            if diff.any():
                print(f"{name}: {int((diff.max(axis=2) > 0).sum())} pixels differ, by up to {int(diff.max())}")
                same = False
        print("equal to the pictures in " + a.check + ", pixel for pixel" if same else "NOT equal to the pictures in " + a.check)
        sys.exit(0 if same else 1)


if __name__ == "__main__":
    main()
