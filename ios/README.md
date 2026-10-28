# Shifty for iPhone

A native SwiftUI app of Shifty (iOS 26 or later, iPhone, Hebrew, right to left): the hours of each
shift and the wage they earn, kept on the device. It is built only on a Mac, which this project does
not have: `codemagic.yaml`, at the root of the repository, builds it on Codemagic's Macs.

## Layout

- `project.yml`: the XcodeGen spec. The Xcode project and `Shifty/Info.plist` are generated on the
  build Mac and not kept in git.
- `Shifty/`: the app. `ShiftyApp.swift` holds the tabs, and `Theme.swift` the glass card and the
  screens' colors.
- `Shifty/Assets.xcassets`: the icon (`AppIcon.svg` at 1024 px), the accent color and the background,
  in light and dark.
- `scripts/`: the builds (`testflight.sh`, `screenshots.sh`) and the check of the Swift without a Mac
  (`check-swift.sh`).

## Checking the Swift without a Mac

WSL's Ubuntu has Swift: `check-swift.sh` parses every file and type-checks those that do not use
SwiftUI. From PowerShell, at the root of the repository:

```powershell
wsl -d Ubuntu-24.04 -- bash -lc "cd /mnt/c/Users/ari/Documents/GitHub/Shifty && tr -d '\r' < ios/scripts/check-swift.sh | bash"
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
have the App Groups capability with `group.com.perezari.shifty`.
