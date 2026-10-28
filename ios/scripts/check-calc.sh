#!/usr/bin/env bash
# Proves the Swift engine (ios/Shifty/Core) equal to the web app's (assets/js): Node runs calc.js,
# holidays.js and format.js on generated cases, WSL's Swift runs the port on the same cases, and
# compare.mjs holds the results against each other, both in Jerusalem time. From the repository's
# root, in Git Bash on Windows (Node is Windows', Swift is WSL's).
set -euo pipefail
out=ios/build/calc
mkdir -p "$out"
TZ=Asia/Jerusalem node ios/Tests/calc-cases.mjs "$out"

root=$(pwd -W)
wslroot="/mnt/$(printf '%s' "${root:0:1}" | tr 'A-Z' 'a-z')${root:2}"
MSYS_NO_PATHCONV=1 wsl -d Ubuntu-24.04 -- bash -lc "set -e; cd '$wslroot/ios'; \
  swiftc -O Shifty/Core/*.swift Tests/CalcCheck/main.swift -o /tmp/shifty-calc-check; \
  TZ=Asia/Jerusalem /tmp/shifty-calc-check build/calc/cases.json build/calc/actual.json"

node ios/Tests/compare.mjs "$out"
