#!/usr/bin/env bash
# Checks the app's Swift where there is no Xcode (WSL Ubuntu with Swift, from the repository's root):
# parses every file, and type-checks the ones that do not use SwiftUI (Shifty/Core). The app itself
# compiles only on a Mac (codemagic.yaml).
set -uo pipefail
cd ios || exit 1
mapfile -t files < <(find Shifty -name '*.swift')
swiftc -parse "${files[@]}" && echo "Parsed: ${#files[@]} files"
if compgen -G "Shifty/Core/*.swift" > /dev/null; then
  swiftc -typecheck Shifty/Core/*.swift && echo "Type-checked: Core"
fi
