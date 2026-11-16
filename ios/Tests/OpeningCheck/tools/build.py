"""Builds a scene's dumper in WSL: the kit (ios/Shifty/Opening/*.swift), ONE scene (Scenes/<Name>.swift, whose
file name in small letters is the id) and main.swift, into /tmp/opening-check/<id>/dump there. The other tools build
by themselves when a source has changed; this one shows the compiler's words, warnings too.

    python tools/build.py <scene id> [--force]
    python tools/build.py --app          the kit and ALL the scenes type-checked together, as the app compiles them

--app is for when a scene is done: in the app every scene is compiled with every other, so two that name a helper
alike at the top of their files, or one still half written, fail here and nowhere else.
"""
import argparse
import sys

sys.dont_write_bytecode = True                                  # no __pycache__ in the repository
import opening  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("scene", nargs="?")
ap.add_argument("--force", action="store_true", help="build even if nothing changed")
ap.add_argument("--app", action="store_true", help="type-check the kit and every scene together")
a = ap.parse_args()

if a.app:
    ok, words, count = opening.app_check()
    if words:
        print(words)
    print(f"the kit and the {count} scene(s) in Scenes/ type-check together, with no warnings" if ok
          else "NOT PASSED: the kit and the scenes do not compile together")
    sys.exit(0 if ok else 1)
if not a.scene:
    ap.error("a scene's id, or --app")

binary = opening.build(a.scene, force=a.force, quiet=False)
meta = opening.info(a.scene)
print(f"built {binary} (in WSL): scene {meta['scene']}, rest {meta['rest']}, end {meta['end']}, "
      f"arrive {meta['arrive']}, poster {meta['poster']}")
print("layouts: " + ", ".join(meta["layouts"]))
