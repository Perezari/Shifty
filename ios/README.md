# Shifty for iPhone

A native SwiftUI app of Shifty (iOS 26 or later, iPhone, Hebrew, right to left): the hours of each
shift and the wage they earn, kept on the device. It is built only on a Mac, which this project does
not have: `codemagic.yaml`, at the root of the repository, builds it on Codemagic's Macs.

## Layout

- `project.yml`: the XcodeGen spec. The Xcode project, the Info.plists and the entitlements are generated
  on the build Mac and not kept in git.
- `Shifty/`: the app. `ShiftyApp.swift` holds the store and the tabs, `Theme.swift` the glass card and
  the screens' colors, `Lock.swift` the lock (Face ID, or the iPhone's passcode, on launch and after a
  minute away: the web app's four digits the iPhone's way, this device's alone), and `Demo.swift` the
  made-up shifts the screenshots show (debug builds only).
- `Shifty/Views/`: the screens. `NowView` (the running shift on a twelve-hour dial, `Core/Dial.swift`: its
  goal's flag dragged to see the wage of leaving later; then the week, the pay period and a holiday coming), `ShiftsView`
  (a pay period's shifts, its hours, hours missing and income), `CalendarView` (the period as a heat map
  of the work, and a day's sheet, `DayDetail`, to add a shift or a day off), `SettingsView` (every setting
  of the web app, the look, the lock, and the backup to a file and back) and `ShiftEditor` (a shift by
  hand). `Components` holds what they share: the period's bar and picker, the summary card, a shift's
  row, the settings' cards and the wheel of hours and minutes.
- `Shifty/Live/`: the shift outside the app. `ShiftIntents` holds what its buttons do (start, end, a
  break, as App Intents that the system performs in the app, woken in the background if need be),
  `Shortcuts` the sentences Siri knows ("התחל משמרת בShifty"), `ShiftActivity` the Live Activity's data,
  and `LiveShift` keeps the Live Activity, the notifications (the goal reached, the overtime's 150%, a
  shift open twelve hours) and the widgets in step with the store after each change. `Place` watches the
  workplace (set in the settings, this iPhone's alone) and asks on arriving whether to start a shift and
  on leaving whether to end it, in notifications whose buttons do it, also with the app closed.
- `Widget/`: the widget extension (`com.perezari.shifty.widget`), with the app's engine and store to read
  the shifts from the App Group: the shift's widget for the home screen and the lock screen, the Live
  Activity on the Lock Screen and in the Dynamic Island, and the shift's switch for the Control Center
  and the Action button.
- `Shifty/ICloud.swift`: the shifts and the settings in iCloud's key-value store, on the user's other
  devices and back after a reinstall. The merging is `Core/CloudMirror.swift`: each shift by its
  `updatedAt`, the settings as the web app's cloud.js merges them. (The web app and the desktop widget
  sync through Supabase instead, and do not see the iPhone's shifts.)
- `Shifty/Core/`: everything without SwiftUI, ported line by line from the web app's `assets/js`:
  `Calc` (the wage engine, calc.js), `Holidays` (holidays.js, on Foundation's Hebrew calendar),
  `Format` (format.js), `Models` (a shift and the settings, in the web app's JSON), `Period` (a pay
  period as the Shifts and Calendar screens add it up) and `ShiftStore` (store.js: two JSON files in the
  App Group's container; restoring a backup replaces the shifts in iCloud too). `LocalTime` makes dates
  the way JavaScript's `Date` does, so the engine gives the web app's results to the last bit.
- `Tests/`: the proof that the engine equals the web app's (`calc-cases.mjs`, `CalcCheck`,
  `compare.mjs`), and the checks of the store (`StoreCheck`), the cloud mirror (`SyncCheck`) and the pay
  period (`PeriodCheck`).
- `Shifty/Assets.xcassets`: the icon (`AppIcon.svg` at 1024 px, and `AppIcon-dark.svg` and
  `AppIcon-tinted.svg` for the iPhone's dark and tinted home screen), the accent color and the
  background, in light and dark.
- `scripts/`: the builds (`testflight.sh`, `screenshots.sh`) and the check of the Swift without a Mac
  (`check-swift.sh`).
- `preview/`: the screens in the browser, to see a design before a build (`preview/README.md`).

## Checking the Swift without a Mac

WSL's Ubuntu has Swift: `check-swift.sh` parses every file, type-checks those that do not use
SwiftUI and runs the checks of the store, the cloud mirror (two devices on a cloud in memory) and the
pay period. From PowerShell, at the root of the repository:

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
- "Shifty · screenshots" builds for the simulator and photographs the App Store's screens with made-up
  shifts (`Shifty/Demo.swift`), 1206 × 2622, numbered in the store's order: the running shift, the
  shifts, the calendar, a shift's menu on a long press, a day, a new shift, the settings, and three of
  them in dark. The app runs on Israel's clock, and the status bar shows the same minute.

`scripts/testflight.sh` archives without signing (the team has no registered devices, so there is no
development profile), signs the archive for no one with the app's entitlements (an unsigned archive
carries none), then `xcodebuild -exportArchive` signs it for the App Store with the App Store Connect
key and uploads it. The build number is the time of the build.

The bundle ID is `com.perezari.shifty`. Its App ID, and the widget's (`com.perezari.shifty.widget`),
have the App Groups capability with `group.com.perezari.shifty`; the app's has iCloud too, for the
key-value store (no CloudKit container).
