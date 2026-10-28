#!/usr/bin/env bash
# Archives the app for the App Store, signs it in Apple's cloud with the App Store Connect key and
# uploads it to App Store Connect, where it appears in TestFlight. Runs on Codemagic's Macs
# (codemagic.yaml). Needs APPLE_API_ISSUER, APPLE_API_KEY (Key ID), APPLE_API_KEY_P8 and
# APPLE_DEVELOPMENT_TEAM.
set -euo pipefail
cd "$(dirname "$0")/.."

# A space, a line break or quotes pasted around a value are dropped. Then how each value looks is
# printed, never the value: a field pasted into another's place is the usual reason App Store
# Connect turns the key down.
clean() { printf '%s' "$1" | tr -d "[:space:]\"'"; }
APPLE_API_KEY=$(clean "$APPLE_API_KEY")
APPLE_API_ISSUER=$(clean "$APPLE_API_ISSUER")
APPLE_DEVELOPMENT_TEAM=$(clean "$APPLE_DEVELOPMENT_TEAM")
shape() {
  if [[ "$2" =~ $3 ]]; then echo "$1: looks right"; else echo "$1: does NOT look right (${#2} characters)"; fi
}
shape "APPLE_API_KEY, the Key ID (10 capital letters and digits)" "$APPLE_API_KEY" '^[A-Z0-9]{10}$'
shape "APPLE_API_ISSUER, the Issuer ID (8-4-4-4-12 hexadecimal)" "$APPLE_API_ISSUER" '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
shape "APPLE_DEVELOPMENT_TEAM, the Team ID (10 capital letters and digits)" "$APPLE_DEVELOPMENT_TEAM" '^[A-Z0-9]{10}$'

key="${RUNNER_TEMP:-/tmp}/AuthKey_$APPLE_API_KEY.p8"
trap 'rm -f "$key"' EXIT
# The key as a PEM file whatever way the variable holds it: pasted into a one-line field (Codemagic's)
# its line breaks become spaces, a copy may leave out the BEGIN and END lines, and a base64 copy of the
# file has none. The body is taken out and put back in lines of 64. Nothing of the key is printed.
printf '%s' "$APPLE_API_KEY_P8" | python3 -c '
import base64, re, sys
text = sys.stdin.read().strip()
if "BEGIN" not in text:
    # A base64 copy of the whole file holds its PEM text; the body of the key alone holds DER (0x30...).
    data = base64.b64decode(re.sub(r"\\n|\s", "", text))
    if data.startswith(b"-----"):
        text = data.decode()
body = re.sub(r"-----[^-]+-----|\\n|\s", "", text)
print("-----BEGIN PRIVATE KEY-----")
print("\n".join(body[i:i + 64] for i in range(0, len(body), 64)))
print("-----END PRIVATE KEY-----")
' > "$key"
echo "The key: $(wc -l < "$key" | tr -d ' ') lines"
auth=(-allowProvisioningUpdates -authenticationKeyPath "$key" -authenticationKeyID "$APPLE_API_KEY" -authenticationKeyIssuerID "$APPLE_API_ISSUER")

# The archive is not signed here: the team has no devices for a development profile, and the export
# below signs it for the App Store. The build number is the time of the build in UTC (year, day of
# the year, hour and minute: 263011530), so it rises from one upload to the next.
xcodebuild -project Shifty.xcodeproj -scheme Shifty -configuration Release \
  -destination generic/platform=iOS -archivePath build/Shifty.xcarchive \
  DEVELOPMENT_TEAM="$APPLE_DEVELOPMENT_TEAM" CURRENT_PROJECT_VERSION="$(date -u +%y%j%H%M)" \
  CODE_SIGNING_ALLOWED=NO -quiet archive

# An unsigned archive carries no entitlements, and the export signs the app with those it finds in its
# signature: sign it here for no one ("-") with them, the extensions first. They all share the App
# Group; the app alone has iCloud's key-value store (ICloud.swift). The export then signs it again for
# the App Store.
app=build/Shifty.xcarchive/Products/Applications/Shifty.app
entitlements() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array><string>group.com.perezari.shifty</string></array>
$1
</dict>
</plist>
EOF
}
entitlements "" > build/Extension.entitlements
entitlements "  <key>com.apple.developer.ubiquity-kvstore-identifier</key><string>$APPLE_DEVELOPMENT_TEAM.com.perezari.shifty</string>" > build/Shifty.entitlements
for extension in "$app"/PlugIns/*.appex; do
  [ -e "$extension" ] || continue
  codesign --force --sign - --entitlements build/Extension.entitlements "$extension"
done
codesign --force --sign - --entitlements build/Shifty.entitlements "$app"

cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$APPLE_DEVELOPMENT_TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
EOF

# Reaching Apple's provisioning service from the build Mac once timed out; try up to three times.
for attempt in 1 2 3; do
  if xcodebuild -exportArchive -archivePath build/Shifty.xcarchive -exportPath build/export \
       -exportOptionsPlist build/ExportOptions.plist "${auth[@]}"; then
    exit 0
  fi
  echo "Export and upload failed (attempt $attempt)"
  sleep 20
done
exit 1
