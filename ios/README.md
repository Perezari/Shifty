# Shifty for iPhone

A native SwiftUI app of Shifty (iOS 26 or later, iPhone, Hebrew, right to left): the hours of each
shift and the wage they earn, kept on the device. It is built only on a Mac, which this project does
not have: `codemagic.yaml`, at the root of the repository, builds it on Codemagic's Macs.

## Layout

- `project.yml`: the XcodeGen spec. The Xcode project and `Shifty/Info.plist` are generated on the
  build Mac and not kept in git.
- `Shifty/`: the app. `ShiftyApp.swift` holds the store and the tabs, `Theme.swift` the glass card and
  the screens' colors, and `Demo.swift` the made-up shifts the screenshots show (debug builds only).
- `Shifty/Views/`: the screens. `NowView` (the running shift on the ring, the day's goal),
  `ShiftEditor` (a shift by hand).
- `Shifty/ICloud.swift`: the shifts and the settings in iCloud's key-value store, on the user's other
  devices and back after a reinstall. The merging is `Core/CloudMirror.swift`: each shift by its
  `updatedAt`, the settings as the web app's cloud.js merges them. (The web app and the desktop widget
  sync through Supabase instead, and do not see the iPhone's shifts.)
- `Shifty/Core/`: everything without SwiftUI, ported line by line from the web app's `assets/js`:
  `Calc` (the wage engine, calc.js), `Holidays` (holidays.js, on Foundation's Hebrew calendar),
  `Format` (format.js), `Models` (a shift and the settings, in the web app's JSON) and `ShiftStore`
  (store.js: two JSON files in the App Group's container). `LocalTime` makes dates the way
  JavaScript's `Date` does, so the engine gives the web app's results to the last bit.
- `Tests/`: the proof that the engine equals the web app's (`calc-cases.mjs`, `CalcCheck`,
  `compare.mjs`) and the store's checks (`StoreCheck`).
- `Shifty/Assets.xcassets`: the icon (`AppIcon.svg` at 1024 px), the accent color and the background,
  in light and dark.
- `scripts/`: the builds (`testflight.sh`, `screenshots.sh`) and the check of the Swift without a Mac
  (`check-swift.sh`).

## Checking the Swift without a Mac

WSL's Ubuntu has Swift: `check-swift.sh` parses every file, type-checks those that do not use
SwiftUI and runs the store's checks and the cloud mirror's (two devices on a cloud in memory). From
PowerShell, at the root of the repository:

```powershell
wsl -d Ubuntu-24.04 -- bash -lc "cd /mnt/c/Users/ari/Documents/GitHub/Shifty && tr -d '\r' < ios/scripts/check-swift.sh | bash"
```

`check-calc.sh` proves the wage engine equal to the web app's: Node runs `calc.js`, `holidays.js` and
`format.js` on some 31,000 generated cases (two years of random shifts, the edges, sick runs, the nights
the clocks change, every day's holidays from 2019 to 2032, pay periods, night windows, formatting),
WSL's Swift runs `Shifty/Core` on the same cases, both in Jerusalem time, and every result must be the
same. Run it after any change to the engine, here or in `assets/js`. From Git Bash, at the root:

```bash
bash ios/scripts/check-calc.sh
```

## Building

Builds run on Codemagic, only when started there by hand (Start new build); a personal account has
500 free Mac minutes a month.

- "Shifty · TestFlight" signs the app and uploads it to TestFlight. It reads the variable group
  `app_store`: `APPLE_API_ISSUER`, `APPLE_API_KEY` (the Key ID), `APPLE_API_KEY_P8` (the text of the
  .p8 file) and `APPLE_DEVELOPMENT_TEAM`.
- "Shifty · screenshots" builds for the simulator and photographs the screens, light and dark.

`scripts/testflight.sh` archives without signing (the team has no registered devices, so there is no
development profile), signs the archive for no one with the app's entitlements (an unsigned archive
carries none), then `xcodebuild -exportArchive` signs it for the App Store with the App Store Connect
key and uploads it. The build number is the time of the build.

The bundle ID is `com.perezari.shifty`. Its App ID, and the widget's (`com.perezari.shifty.widget`),
have the App Groups capability with `group.com.perezari.shifty`; the app's has iCloud too, for the
key-value store (no CloudKit container).
