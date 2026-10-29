#!/usr/bin/env bash
# Checks the app's Swift where there is no Xcode (WSL Ubuntu with Swift, from the repository's root):
# parses every file, type-checks the ones that do not use SwiftUI (Shifty/Core) and runs the store's, the
# cloud mirror's and the pay period's checks on them (Tests/StoreCheck, Tests/SyncCheck, Tests/PeriodCheck).
# The app itself compiles only on a Mac (codemagic.yaml); the wage engine's equality with the web app's is
# check-calc.sh's.
set -uo pipefail
cd ios || exit 1
mapfile -t files < <(find Shifty -name '*.swift')
swiftc -parse "${files[@]}" && echo "Parsed: ${#files[@]} files"
if compgen -G "Shifty/Core/*.swift" > /dev/null; then
  swiftc -typecheck Shifty/Core/*.swift && echo "Type-checked: Core"
  for check in StoreCheck SyncCheck PeriodCheck; do
    swiftc Shifty/Core/*.swift "Tests/$check/main.swift" -o "/tmp/shifty-$check" &&
      TZ=Asia/Jerusalem "/tmp/shifty-$check"
  done
fi
