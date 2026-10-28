#!/usr/bin/env bash
# Builds the app for the iPhone simulator and photographs its screens, in light and dark, into
# ios/build/screenshots (kept by codemagic.yaml as the build's artifacts).
set -euo pipefail
cd "$(dirname "$0")/.."

# An available iPhone Pro (not Max) on the newest iOS runtime: the medium display with the Dynamic
# Island, 1206 by 2622.
read -r udid name < <(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
version = lambda key: [int(part) for part in key.rsplit("iOS-", 1)[1].split("-")]
for runtime in sorted((key for key in devices if "iOS-" in key), key=version, reverse=True):
    phones = [d for d in devices[runtime] if d.get("isAvailable") and d["name"].startswith("iPhone")]
    pros = [d for d in phones if "Pro" in d["name"] and "Max" not in d["name"]]
    if phones:
        pick = (pros or phones)[-1]
        print(pick["udid"], pick["name"].replace(" ", "_"))
        break
')
echo "Simulator: $name ($udid)"
xcrun simctl boot "$udid" || true

xcodebuild -project Shifty.xcodeproj -scheme Shifty -configuration Debug \
  -destination "platform=iOS Simulator,id=$udid" -derivedDataPath build/derived \
  CODE_SIGNING_ALLOWED=NO -quiet build

xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" build/derived/Build/Products/Debug-iphonesimulator/Shifty.app
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 || true

mkdir -p build/screenshots
# shoot <screen> <file> [seconds to wait]
shoot() {
  xcrun simctl launch "$udid" com.perezari.shifty -screenshot "$1" >/dev/null
  sleep "${3:-6}"
  xcrun simctl io "$udid" screenshot "build/screenshots/$2.png" >/dev/null
  xcrun simctl terminate "$udid" com.perezari.shifty || true
}
for screen in now idle shifts calendar settings; do shoot "$screen" "$screen"; done
# the sheet over the screen, once it is up
shoot editor editor 9
xcrun simctl ui "$udid" appearance dark
for screen in now idle; do shoot "$screen" "$screen-dark"; done
shoot editor editor-dark 9
ls -la build/screenshots
