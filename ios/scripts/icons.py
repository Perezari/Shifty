#!/usr/bin/env python3
"""The app's icons, and the pictures made from them, all from the logo (ios/brand/MrShift.webp: the man on flat
yellow inside nine clock ticks, his shirt running off the bottom and both sides, as iOS's own rounded corners are to
cut it). The man is cut out of the yellow and set again on each icon's ground, with the ticks redrawn in its color.

    python ios/scripts/icons.py        # writes into ios/Shifty/Assets.xcassets; needs numpy, scipy and Pillow

The icons, picked in Settings › אייקון (Views/IconPicker.swift):
    AppIcon          white, navy ticks: the app's own      AppIcon-Yellow   the logo as drawn
    AppIcon-Navy     navy, yellow ticks and edge           AppIcon-Purple   purple, yellow ticks, a white edge
    AppIcon-Teal     teal, white ticks                     AppIcon-Plain    yellow, without the ticks
each light, dark (a dark ground, the ticks and an edge round the man in its color) and tinted (grey on black).
Besides them: IconChoice-… (the picker's pictures), Icon (the app's own, inside the app), LaunchMister (the launch
screen's picture and Views/Opening.swift's first frame), OpeningMark (the ticks and the man, for the opening) and
BannerMark (the man's lines and dark parts in one color, for the reports' stamp, which draws it in navy,
Views/ReportSheet.swift).
"""
import json
import os
import shutil

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

IOS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SOURCE = os.path.join(IOS, "brand", "MrShift.webp")
ASSETS = os.path.join(IOS, "Shifty", "Assets.xcassets")
SIZE = 1024
NAVY, YELLOW, WHITE = "#0A1435", "#FEC802", "#FFFFFF"

# Each icon: its light look (ground's top, its bottom, the ticks, the edge round the man) and its dark one
ICONS = {
    "Standard": ((WHITE, "#ECEFF6", NAVY, None), ("#22252E", "#0B0C10", WHITE, WHITE)),
    "Yellow": ((YELLOW, YELLOW, NAVY, None), ("#1C2448", "#0A0E22", YELLOW, YELLOW)),
    "Navy": (("#2A3470", "#141B47", YELLOW, YELLOW), ("#141932", "#05070F", YELLOW, YELLOW)),
    "Purple": (("#6C51E3", "#3B26A2", YELLOW, WHITE), ("#221A4C", "#0A0716", "#B9A6FF", "#B9A6FF")),
    "Teal": (("#19B9A8", "#0B7D72", WHITE, None), ("#1E2427", "#0A0C0D", "#3FDCC8", "#3FDCC8")),
    "Plain": ((YELLOW, YELLOW, None, None), ("#1C2448", "#0A0E22", None, YELLOW)),
}
TINTED = ("#000000", "#000000", "#E8E8E8", "#E8E8E8")
# The shekel's sets of before 1.6, taken out
OLD = ["AppIcon-Dark.appiconset", "AppIcon-Mono.appiconset", "AppIcon-White.appiconset", "IconChoice-Dark.imageset",
       "IconChoice-Mono.imageset", "LaunchShekel.imageset"]


def rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) for i in (1, 3, 5))


def cut(path):
    """The man (RGBA, at the logo's size) and the ticks (x1, y1, x2, y2, width on a 512 grid), from the logo."""
    src = np.asarray(Image.open(path).convert("RGB")).astype(float)
    h, w, _ = src.shape
    R, G, B = src[..., 0], src[..., 1], src[..., 2]
    # The yellow ground and its blends into the navy lines, joined to the top edge (the shirt touches the others)
    yellowish = (R > 120) & (G > 90) & (B < 70)
    labels, _ = ndimage.label(yellowish)
    ground = np.isin(labels, list(set(np.unique(labels[0])) - {0}))
    fg = ~ground
    band = ndimage.binary_dilation(fg, iterations=2) & ~ndimage.binary_erosion(fg, iterations=2, border_value=1)
    alpha = np.where(band, np.clip((254 - R) / 244, 0, 1), fg.astype(float))
    line = np.median(src[fg & (src.max(axis=2) < 70)], axis=0)
    color = np.where(band[..., None], line[None, None, :], src)
    parts, n = ndimage.label(alpha > 0.5)
    man_id = parts[h - 10, w // 2]
    man = parts == man_id
    man = man | (ndimage.binary_dilation(man, iterations=3) & band)
    rgba = np.dstack([color, np.where(man, alpha, 0) * 255]).clip(0, 255).astype(np.uint8)
    ticks = []
    for i in range(1, n + 1):
        yx = np.argwhere(parts == i).astype(float)
        if i == man_id or len(yx) < 200:
            continue
        pts = yx[:, ::-1]
        mean = pts.mean(axis=0)
        _, _, vt = np.linalg.svd(pts - mean, full_matrices=False)
        along, across = (pts - mean) @ vt[0], (pts - mean) @ vt[1]
        width = across.max() - across.min()
        a, b = along.min() + width / 2, along.max() - width / 2
        p, q = mean + vt[0] * a, mean + vt[0] * b
        k = 512 / w
        ticks.append((p[0] * k, p[1] * k, q[0] * k, q[1] * k, width * k))
    return Image.fromarray(rgba, "RGBA"), ticks


def resized(image, size):
    """An RGBA picture at another size, its colors weighed by their alpha (no dark fringes)."""
    return image.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")


def ground(top, bottom, size):
    t = np.linspace(0, 1, size)[:, None, None]
    column = np.array(rgb(top))[None, None, :] * (1 - t) + np.array(rgb(bottom))[None, None, :] * t
    return Image.fromarray(np.repeat(column, size, axis=1).round().astype(np.uint8), "RGB").convert("RGBA")


def tick_layer(ticks, color, size):
    """The ticks, round at their ends, drawn four times larger and brought down for smooth edges."""
    big = size * 4
    layer = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    k = big / 512
    for x1, y1, x2, y2, w in ticks:
        draw.line([(x1 * k, y1 * k), (x2 * k, y2 * k)], fill=rgb(color) + (255,), width=round(w * k))
        for x, y in ((x1, y1), (x2, y2)):
            r = w * k / 2
            draw.ellipse([x * k - r, y * k - r, x * k + r, y * k + r], fill=rgb(color) + (255,))
    return resized(layer, size)


def edge_layer(man, color, size):
    """The man's silhouette widened by 1.8% of the icon, smooth: the edge some grounds put round him."""
    inside = np.asarray(man)[..., 3] > 127
    dist = ndimage.distance_transform_edt(~inside)
    a = np.clip(0.018 * size - dist + 0.5, 0, 1)
    layer = np.zeros((size, size, 4), np.uint8)
    layer[..., :3] = rgb(color)
    layer[..., 3] = (a * 255).astype(np.uint8)
    return Image.fromarray(layer, "RGBA")


def grey(man):
    a = np.asarray(man).astype(float)
    lum = a[..., :3] @ np.array([0.299, 0.587, 0.114])
    return Image.fromarray(np.dstack([lum, lum, lum, a[..., 3]]).clip(0, 255).astype(np.uint8), "RGBA")


def compose(look, man, ticks, size, with_ticks=True, tinted=False):
    top, bottom, tick, edge = look
    image = ground(top, bottom, size)
    if tick and with_ticks:
        image.alpha_composite(tick_layer(ticks, tick, size))
    if edge:
        image.alpha_composite(edge_layer(man, edge, size))
    image.alpha_composite(grey(man) if tinted else man)
    return image


def rounded(image, radius_share, hairline=None):
    """The picture in a rounded square (circular corners, as Opening.swift draws its box), outside clear; with a
    hairline inside its edge: (inset, width) in pixels, black at 7%."""
    size = image.width
    big = size * 4
    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=radius_share * big, fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(image, (0, 0), mask.resize((size, size), Image.LANCZOS))
    if hairline:
        inset, width = hairline
        ring = Image.new("RGBA", (big, big), (0, 0, 0, 0))
        i, wd = inset * 4, width * 4
        ImageDraw.Draw(ring).rounded_rectangle([i, i, big - 1 - i, big - 1 - i], radius=radius_share * big - i,
                                               outline=(0, 0, 0, 18), width=max(1, round(wd)))
        out.alpha_composite(resized(ring, size))
    return out


def save(image, folder, name, mode="RGB"):
    os.makedirs(folder, exist_ok=True)
    (image.convert(mode) if mode else image).save(os.path.join(folder, name), optimize=True)


def contents(folder, images):
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, f, indent=2)
        f.write("\n")


DARK = [{"appearance": "luminosity", "value": "dark"}]
TINT = [{"appearance": "luminosity", "value": "tinted"}]


def main():
    man_full, ticks = cut(SOURCE)
    man = resized(man_full, SIZE)
    for old in OLD:
        shutil.rmtree(os.path.join(ASSETS, old), ignore_errors=True)

    for name, (light, dark) in ICONS.items():
        with_ticks = name != "Plain"
        icon = "AppIcon" if name == "Standard" else "AppIcon-" + name
        folder = os.path.join(ASSETS, icon + ".appiconset")
        shown = compose(light, man, ticks, SIZE, with_ticks)
        shown_dark = compose(dark, man, ticks, SIZE, with_ticks)
        save(shown, folder, icon + ".png")
        save(shown_dark, folder, icon + "-dark.png")
        save(compose(TINTED, man, ticks, SIZE, with_ticks, tinted=True), folder, icon + "-tinted.png")
        size = {"idiom": "universal", "platform": "ios", "size": "1024x1024"}
        contents(folder, [{"filename": icon + ".png", **size},
                          {"appearances": DARK, "filename": icon + "-dark.png", **size},
                          {"appearances": TINT, "filename": icon + "-tinted.png", **size}])
        # The picker's picture, light and dark as the icon is on the Home Screen
        choice = os.path.join(ASSETS, "IconChoice-" + name + ".imageset")
        save(shown.resize((192, 192), Image.LANCZOS), choice, "IconChoice-" + name + ".png")
        save(shown_dark.resize((192, 192), Image.LANCZOS), choice, "IconChoice-" + name + "-dark.png")
        contents(choice, [{"filename": "IconChoice-" + name + ".png", "idiom": "universal"},
                          {"appearances": DARK, "filename": "IconChoice-" + name + "-dark.png", "idiom": "universal"}])

    light, dark = ICONS["Standard"]
    # The app's own icon inside the app (AppIconImage), light and dark
    folder = os.path.join(ASSETS, "Icon.imageset")
    save(compose(light, man, ticks, SIZE).resize((216, 216), Image.LANCZOS), folder, "Icon.png")
    save(compose(dark, man, ticks, SIZE).resize((216, 216), Image.LANCZOS), folder, "Icon-dark.png")
    contents(folder, [{"filename": "Icon.png", "idiom": "universal"},
                      {"appearances": DARK, "filename": "Icon-dark.png", "idiom": "universal"}])

    # The launch screen's picture: the icon in a 120-point rounded square, its corner 27 points, as the opening's box
    folder = os.path.join(ASSETS, "LaunchMister.imageset")
    images = [{"idiom": "universal", "scale": "1x"}, {"appearances": DARK, "idiom": "universal", "scale": "1x"}]
    for scale in (2, 3):
        px = 120 * scale
        hair = (1.1 * 60 / 256 * scale, 2.2 * 60 / 256 * scale)
        save(rounded(compose(light, man, ticks, SIZE).resize((px, px), Image.LANCZOS), 27 / 120, hair), folder,
             f"LaunchMister@{scale}x.png", mode=None)
        save(rounded(compose(dark, man, ticks, SIZE).resize((px, px), Image.LANCZOS), 27 / 120), folder,
             f"LaunchMister-dark@{scale}x.png", mode=None)
        images += [{"filename": f"LaunchMister@{scale}x.png", "idiom": "universal", "scale": f"{scale}x"},
                   {"appearances": DARK, "filename": f"LaunchMister-dark@{scale}x.png", "idiom": "universal",
                    "scale": f"{scale}x"}]
    contents(folder, images)

    # The opening's mark: the ticks and the man on nothing, light and dark (with the dark look's edge)
    folder = os.path.join(ASSETS, "OpeningMark.imageset")
    for look, file in ((light, "OpeningMark.png"), (dark, "OpeningMark-dark.png")):
        mark = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        mark.alpha_composite(tick_layer(ticks, look[2], SIZE))
        if look[3]:
            mark.alpha_composite(edge_layer(man, look[3], SIZE))
        mark.alpha_composite(man)
        save(resized(mark, 512), folder, file, mode=None)
    contents(folder, [{"filename": "OpeningMark.png", "idiom": "universal"},
                      {"appearances": DARK, "filename": "OpeningMark-dark.png", "idiom": "universal"}])

    # The banner's mark: the man's lines and dark parts in white, his light parts clear, and the ticks
    a = np.asarray(man).astype(float)
    lum = a[..., :3] @ np.array([0.299, 0.587, 0.114])
    white = np.clip((150 - lum) / 70, 0, 1) * a[..., 3]
    lines = np.zeros((SIZE, SIZE, 4), np.uint8)
    lines[..., :3] = 255
    lines[..., 3] = white.astype(np.uint8)
    mark = tick_layer(ticks, WHITE, SIZE)
    mark.alpha_composite(Image.fromarray(lines, "RGBA"))
    folder = os.path.join(ASSETS, "BannerMark.imageset")
    save(resized(mark, 300), folder, "BannerMark.png", mode=None)
    contents(folder, [{"filename": "BannerMark.png", "idiom": "universal"}])
    print("ticks", [tuple(round(v, 1) for v in t) for t in ticks])


if __name__ == "__main__":
    main()
