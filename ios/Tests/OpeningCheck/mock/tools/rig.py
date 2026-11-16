"""Cuts the man of the logo into layers that move on their own: body, head (its features taken out and the skin
painted under them), eyebrows, eyes, the mustache and its halves, the bow tie's wings and its knot. Each layer is
saved cropped, at 1024 to the logo's side, with its place on the icon's 512 grid in rig.json."""
import json, os, sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.interpolate import griddata
sys.path.insert(0, r"C:\Users\ari\Documents\GitHub\Shifty\ios\scripts")
import icons

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
man, ticks = icons.cut(icons.SOURCE)
A = np.asarray(man).astype(float)
H, W = A.shape[:2]
rgb, al = A[..., :3].copy(), A[..., 3] / 255
lum = rgb @ np.array([0.299, 0.587, 0.114])
LINE = np.array([2.0, 19.0, 50.0])
yy, xx = np.mgrid[0:H, 0:W]

dark = (rgb.max(axis=2) < 100) & (al > 0.8)
lab, n = ndimage.label(dark)


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


FEATURES = {
    "stache": comp_in(570, 600, 960, 780), "browL": comp_in(520, 480, 672, 575), "browR": comp_in(745, 440, 866, 505),
    "eyeL": comp_in(570, 565, 700, 640), "eyeR": comp_in(772, 525, 886, 594),
}
for k, m in FEATURES.items():
    assert m is not None, k
    FEATURES[k] = ndimage.binary_fill_holes(m)


def soft_feature(mask, pad=6):
    """A dark feature on light skin as a layer: its own colors inside, and round its edge the line's color with the
    alpha the picture's blend there gives."""
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
fills = {name: blab == blab[y, x] for name, (x, y) in {"wingL": (520, 990), "knot": (645, 990), "wingR": (800, 1000)}.items()}
for name, (x, y) in {"wingL": (520, 990), "knot": (645, 990), "wingR": (800, 1000)}.items():
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
bl, bn = ndimage.label(bow_hard)
bow_hard = bl == bl[990, 645]

# ---- head and body: what is left, split where they barely touch (beside the bow): each pixel to the nearer core
solid = (al > 0.5) & ~bow_hard
for k in range(2, 60):
    cores = ndimage.binary_erosion(solid, iterations=k)
    cl, _ = ndimage.label(cores)
    if cl[770, 800] and cl[1150, 300] and cl[770, 800] != cl[1150, 300]:
        break
print("head and body apart at erosion", k)
core_head, core_body = cl == cl[770, 800], cl == cl[1150, 300]
dh = ndimage.distance_transform_edt(~core_head)
db = ndimage.distance_transform_edt(~core_body)
rest = (al > 0.02) & ~bow_hard
head_m, body_m = rest & (dh <= db), rest & (dh > db)

SKIN_NECK = np.array([243.0, 172.0, 121.0])
SHIRT = np.array([253.0, 253.0, 255.0])


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
    """The pixels of `mask` beside the bow are blends with its outline: each takes the color of the nearest pixel of
    the mask farther from the bow, unless it is itself a dark line."""
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
for m in FEATURES.values():
    holes |= ndimage.binary_dilation(m, iterations=8)
head_rgb = inpaint(head_rgb, holes & head_m, skinlike & head_m & ~holes)
head_rgb = clean_fringe(head_rgb, head_m)
head_rgb, grown = extended(head_rgb, head_m, bow_hard)
head_alpha = np.where(head_m, al, 0.0)
head_alpha[grown] = 1

# the body: under the bow the shirt goes on, shaded as round it, up to a round collar from one shoulder's line to the
# other's, and above the collar the neck
shoulders = stub(body_m)
print("shoulder lines meet the bow at", shoulders)
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

LAYERS = {"body": (body_rgb, body_alpha), "head": (head_rgb, head_alpha), "wings": (wings_rgb, wings_alpha), "knot": (knot_rgb, knot_alpha)}
for k, m in FEATURES.items():
    LAYERS[k] = soft_feature(m)
# the mustache's halves, each a little past the middle: the column where its top edge dips between its two bumps
sc, sa = LAYERS["stache"]
ys, xs = np.where(FEATURES["stache"])
cols = np.arange(730, 860)
tops = np.array([np.where(FEATURES["stache"][:, x])[0].min() for x in cols])
mid_x = int(cols[np.argmax(tops)])
mid_y = int(tops.max() + 22)
print("mustache middle", mid_x, mid_y, "bbox", xs.min(), ys.min(), xs.max(), ys.max())
# each half goes past the middle as a round hinge about the pivot, so that the two can turn without a gap
col = np.where(FEATURES["stache"][:, mid_x])[0]
mid_y = int((col.min() + col.max()) / 2)
hinge_r = (col.max() - col.min()) / 2 - 1
hinge = np.clip(hinge_r - np.hypot(xx - mid_x, yy - mid_y) + 0.5, 0, 1)
print("mustache hinge", mid_x, mid_y, round(float(hinge_r), 1))
LAYERS["stacheL"] = (sc, sa * np.maximum(np.clip((mid_x + 1 - xx) / 2.0, 0, 1), hinge))
LAYERS["stacheR"] = (sc, sa * np.maximum(np.clip((xx - (mid_x - 1)) / 2.0, 0, 1), hinge))

G = 512 / W
manifest = {"grid": 512, "layers": {}, "points": {}}
for name, (c, a) in LAYERS.items():
    img = Image.fromarray(np.dstack([c, a * 255]).clip(0, 255).astype(np.uint8), "RGBA")
    big = img.convert("RGBa").resize((1024, 1024), Image.LANCZOS).convert("RGBA")
    box = big.getbbox()
    box = (max(0, box[0] - 2), max(0, box[1] - 2), min(1024, box[2] + 2), min(1024, box[3] + 2))
    big.crop(box).save(os.path.join(OUT, name + ".png"), optimize=True)
    manifest["layers"][name] = {"file": name + ".png", "x": box[0] / 2, "y": box[1] / 2, "w": (box[2] - box[0]) / 2, "h": (box[3] - box[1]) / 2}


def centroid(m):
    cy, cx = np.where(m)
    return [round(float(cx.mean()) * G, 1), round(float(cy.mean()) * G, 1)]


P = manifest["points"]
P["neck"] = [round(650 * G, 1), round(928 * G, 1)]
P["stache"] = [round(mid_x * G, 1), round(mid_y * G, 1)]
P["stacheBox"] = [round(float(v) * G, 1) for v in (xs.min(), ys.min(), xs.max(), ys.max())]
P["knot"] = [round(KNOT[0] * G, 1), round(KNOT[1] * G, 1), round(KNOT[2] * G, 1)]
for k in ("browL", "browR", "eyeL", "eyeR"):
    P[k] = centroid(FEATURES[k])
hy, hx = np.where(head_m)
P["headTop"] = [round(float(hx[hy.argmin()]) * G, 1), round(float(hy.min()) * G, 1)]
P["headBox"] = [round(float(v) * G, 1) for v in (hx.min(), hy.min(), hx.max(), hy.max())]
P["button"] = centroid(button)
# the mustache's outline as a ribbon: at 65 places along its length, how far its top and its bottom are from the
# level line through its middle (grid units), for drawing it as a shape that can bend and stretch
prof = []
for x in np.linspace(xs.min(), xs.max(), 65):
    cc = np.where(FEATURES["stache"][:, int(round(x))])[0]
    prof.append([round(float(mid_y - cc.min()) * G, 2), round(float(cc.max() - mid_y) * G, 2)])
P["stacheProfile"] = {"x0": round(float(xs.min()) * G, 1), "x1": round(float(xs.max()) * G, 1), "y": round(mid_y * G, 1), "samples": prof}
manifest["ticks"] = [[round(float(v), 1) for v in t] for t in ticks]
with open(os.path.join(OUT, "rig.json"), "w") as f:
    json.dump(manifest, f, indent=1)
print(json.dumps(manifest["points"]))

# the whole man too, as before
man.convert("RGBa").resize((1024, 1024), Image.LANCZOS).convert("RGBA").save(os.path.join(OUT, "man.png"), optimize=True)


# ---- checks: the layers at rest against the man, and a few poses
def layer(name):
    L = manifest["layers"][name]
    im = Image.open(os.path.join(OUT, L["file"]))
    full = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    full.paste(im, (round(L["x"] * 2), round(L["y"] * 2)))
    return full


def moved(im, pivot, rot=0, dx=0, dy=0):
    px, py = pivot[0] * 2, pivot[1] * 2
    out = im.rotate(-rot, resample=Image.BICUBIC, center=(px, py)) if rot else im
    if dx or dy:
        o2 = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
        o2.paste(out, (round(dx * 2), round(dy * 2)))
        out = o2
    return out


def pose(head=0, bow=0, stache_dy=0, stache_rot=0, brow_dy=0, no_bow=False, no_stache=False, no_knot=False, ground=(255, 255, 255, 255)):
    im = Image.new("RGBA", (1024, 1024), ground)
    im.alpha_composite(layer("body"))
    grp = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    grp.alpha_composite(layer("head"))
    for b in ("browL", "browR"):
        grp.alpha_composite(moved(layer(b), P[b], dy=brow_dy))
    grp.alpha_composite(layer("eyeL"))
    grp.alpha_composite(layer("eyeR"))
    if not no_stache:
        grp.alpha_composite(moved(layer("stache"), P["stache"], rot=stache_rot, dy=stache_dy))
    im.alpha_composite(moved(grp, P["neck"], rot=head))
    if not no_bow:
        im.alpha_composite(moved(layer("wings"), P["knot"], rot=bow))
        if not no_knot:
            im.alpha_composite(moved(layer("knot"), P["knot"], rot=bow))
    return im


rest_img = pose()
ref = Image.new("RGBA", (1024, 1024), (255, 255, 255, 255))
ref.alpha_composite(man.convert("RGBa").resize((1024, 1024), Image.LANCZOS).convert("RGBA"))
diff = np.abs(np.asarray(rest_img).astype(int) - np.asarray(ref).astype(int))[..., :3].max(axis=2)
print("rest vs man: max diff", int(diff.max()), "| px over 24:", int((diff > 24).sum()), "| px over 60:", int((diff > 60).sum()))
Image.fromarray((np.clip(diff * 4, 0, 255)).astype(np.uint8)).save(os.path.join(OUT, "_diff.png"))
sheet = Image.new("RGB", (2048, 1024), (255, 255, 255))
poses = [pose(), pose(head=-9), pose(head=9, brow_dy=-9), pose(bow=50),
         pose(bow=90, stache_dy=-16), pose(no_bow=True), pose(no_stache=True, head=4), pose(no_knot=True, stache_rot=14)]
for i, p in enumerate(poses):
    sheet.paste(p.convert("RGB").resize((512, 512), Image.LANCZOS), ((i % 4) * 512, (i // 4) * 512))
sheet.save(os.path.join(OUT, "_poses.png"))
zoom = Image.new("RGB", (1500, 500), (255, 255, 255))
for i, pz in enumerate([pose(no_bow=True), pose(bow=50, head=-8), pose(head=9, ground=(244, 245, 247, 255))]):
    zoom.paste(pz.convert("RGB").crop((262, 600, 762, 1024 - 0)).resize((500, 424), Image.LANCZOS), (i * 500, 0))
zoom.save(os.path.join(OUT, "_zoom.png"))

