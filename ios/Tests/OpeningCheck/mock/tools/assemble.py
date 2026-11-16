"""Puts the openings' page together as one file for publishing: the styles and the scripts inline, in order, the
chosen scenes only; the man's layers stay beside it as pictures (assets/*.png).

    python tools/assemble.py out/openings.html today cheshire mrnow ...
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PAGE = os.path.join(HERE, "..", "page")
out, scenes = sys.argv[1], sys.argv[2:]


def read(*parts):
    with open(os.path.join(PAGE, *parts), encoding="utf-8") as f:
        return f.read()


html = read("index.html")
body = re.search(r"<main.*</main>", html, re.S).group(0)
scripts = [read("rig.js"), read("engine.js")] + [read("scenes", s + ".js") for s in scenes] + [read("page.js")]
for s in scripts:
    assert "</script" not in s
page = "\n".join([
    "<title>פתיחות חיות למר משמרת</title>",
    '<meta name="claude:viewport-fit-sides" content="cover">',
    '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Heebo:wght@400;500;600;700;800&display=swap">',
    "<style>\n" + read("page.css") + "</style>",
    body,
] + ["<script>\n" + s + "</script>" for s in scripts]) + "\n"
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write(page)
print(out, len(page) // 1024, "KB;", len(scenes), "scenes:", " ".join(scenes))
