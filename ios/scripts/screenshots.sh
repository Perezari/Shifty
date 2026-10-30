#!/usr/bin/env bash
# Builds the app for the iPhone simulator and photographs the App Store's screens with made-up shifts
# (Shifty/Demo.swift) into ios/build/screenshots, kept by codemagic.yaml as the build's artifacts. They are
# numbered in the store's order: the running shift, the shifts, the calendar, a shift's menu, a day, a new
# shift, the settings, and three of them in dark.
set -euo pipefail
cd "$(dirname "$0")/.."

# An available iPhone Pro (not Max) on the newest iOS runtime: the medium display with the Dynamic
# Island, 1206 by 2622, the size App Store Connect takes for its first iPhone slot.
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
# Full signal and a full battery, not charging: the simulator's own shows no carrier and a green battery.
xcrun simctl status_bar "$udid" override --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --operatorName "" --batteryState discharging --batteryLevel 100 || true

mkdir -p build/screenshots
# shoot <screen> <file> [seconds to wait]. The app runs on Israel's clock and the status bar shows the same
# minute, so the running shift's start agrees with the time at the top.
shoot() {
  SIMCTL_CHILD_TZ=Asia/Jerusalem xcrun simctl launch "$udid" com.perezari.shifty -screenshot "$1" >/dev/null
  sleep "${3:-6}"
  xcrun simctl status_bar "$udid" override --time "$(TZ=Asia/Jerusalem date +%H:%M)" || true
  sleep 1
  xcrun simctl io "$udid" screenshot "build/screenshots/$2.png" >/dev/null
  xcrun simctl terminate "$udid" com.perezari.shifty || true
}
shoot now 01-now
shoot shifts 02-shifts
shoot calendar 03-calendar
# the menu and the sheets over their screens, once they are up
shoot menu 04-menu 9
shoot day 05-day 9
shoot editor 06-editor 9
shoot settings 07-settings
xcrun simctl ui "$udid" appearance dark
shoot now 08-now-dark
shoot shifts 09-shifts-dark
shoot calendar 10-calendar-dark
ls -la build/screenshots
