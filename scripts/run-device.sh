#!/usr/bin/env bash
#
# Build, sign, install and launch volunteerly on a connected iPhone — without
# relying on an Xcode account session (CLI automatic signing is blocked here).
#
# Why this script exists: a one-off "build unsigned then re-sign by hand" flow
# is fragile — Debug builds embed `volunteerly.debug.dylib` / `__preview.dylib`,
# and if those nested binaries aren't signed the app dyld-crashes the instant it
# launches. This script removes BOTH failure modes, every run:
#   1. ENABLE_DEBUG_DYLIB=NO  -> no debug dylib is produced in the first place.
#   2. it still signs every nested Mach-O defensively before signing the app.
#
# It auto-discovers the connected device, a valid signing identity, and a
# provisioning profile that covers both — so it keeps working when the profile
# rotates (personal-team profiles expire every 7 days).
#
# Usage:  ./scripts/run-device.sh
set -euo pipefail

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR
PROJECT="volunteerly.xcodeproj"
SCHEME="volunteerly"
DD="${DD:-/tmp/voldd}"
PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

# --- 1. connected device UDID (xcodebuild-style id) -------------------------
# devicectl reliably reports connection state; xctrace supplies the UDID format
# that xcodebuild accepts (00008140-... vs devicectl's UUID form).
if [ -z "${DEVICE_ID:-}" ]; then
  # Match any state that is not "unavailable" (covers "connected", "available", etc.)
  AVAIL_NAME="$(xcrun devicectl list devices 2>/dev/null \
    | awk '!/unavailable/ && /coredevice\.local/ {
        match($0, /[[:alnum:]-]+\.coredevice\.local/)
        name = substr($0, 1, RSTART-1)
        gsub(/[[:space:]]+$/, "", name)
        print name; exit
      }')"
  [ -n "$AVAIL_NAME" ] || { echo "✗ No connected iPhone found (devicectl)"; exit 1; }
  # Try xctrace first, fall back to xcodebuild destinations
  DEVICE_ID="$(xcrun xctrace list devices 2>/dev/null \
    | grep -F "$AVAIL_NAME" \
    | sed -E 's/.*\(([0-9A-Fa-f-]{25,})\)$/\1/' | head -1)"
  if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID="$(DEVELOPER_DIR="$DEVELOPER_DIR" xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
      -showdestinations 2>/dev/null \
      | grep -F "$AVAIL_NAME" \
      | sed -E 's/.*id:([0-9A-Fa-f-]{25,}).*/\1/' | head -1)"
  fi
fi
[ -n "$DEVICE_ID" ] || { echo "✗ No connected iPhone found"; exit 1; }
echo "• device      : $DEVICE_ID"

# --- 2. a valid codesigning identity (sha1 + name) --------------------------
IDENTITY_LINE="$(security find-identity -v -p codesigning | grep -i 'Apple Development' | grep -v 'CSSMERR' | head -1)"
IDENTITY_SHA="$(echo "$IDENTITY_LINE" | awk '{print $2}')"
[ -n "$IDENTITY_SHA" ] || { echo "✗ No valid Apple Development identity in keychain"; exit 1; }
echo "• identity    : $IDENTITY_SHA"

# --- 3. a profile that matches this identity AND this device, not expired ----
pick_profile() {
  local p plist sha devs appid exp now
  now="$(date +%s)"
  for p in "$PROFILE_DIR"/*.mobileprovision; do
    [ -e "$p" ] || continue
    plist="$(security cms -D -i "$p" 2>/dev/null)" || continue
    # cert sha1 must equal our identity
    /usr/libexec/PlistBuddy -c "Print :DeveloperCertificates:0" /dev/stdin <<<"$plist" >/tmp/_pc.der 2>/dev/null || continue
    sha="$(openssl x509 -inform DER -in /tmp/_pc.der -noout -fingerprint -sha1 2>/dev/null | sed 's/.*=//; s/://g')"
    [ "$sha" = "$IDENTITY_SHA" ] || continue
    # device must be covered
    echo "$plist" | grep -q "$DEVICE_ID" || continue
    # not expired
    exp="$(/usr/libexec/PlistBuddy -c "Print :ExpirationDate" /dev/stdin <<<"$plist" 2>/dev/null)"
    [ "$(date -j -f '%a %b %d %T %Z %Y' "$exp" +%s 2>/dev/null || echo 0)" -gt "$now" ] || continue
    appid="$(/usr/libexec/PlistBuddy -c "Print :Entitlements:application-identifier" /dev/stdin <<<"$plist" 2>/dev/null)"
    echo "$p|${appid#*.}|$plist"   # path | bundle-id | plist
    return 0
  done
  return 1
}
PICK="$(pick_profile || true)"
[ -n "$PICK" ] || { echo "✗ No provisioning profile covers this device+identity. Run once from Xcode (Product > Run) to mint one."; exit 1; }
PROFILE_PATH="${PICK%%|*}"; rest="${PICK#*|}"; BUNDLE_ID="${rest%%|*}"; PROFILE_PLIST="${rest#*|}"
TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' /dev/stdin <<<"$PROFILE_PLIST" 2>/dev/null)"
echo "• profile     : $(basename "$PROFILE_PATH") -> $BUNDLE_ID (team $TEAM_ID)"

# entitlements for signing
/usr/libexec/PlistBuddy -x -c "Print :Entitlements" /dev/stdin <<<"$PROFILE_PLIST" > /tmp/_ent.plist

# --- 4. unsigned build, NO debug dylib --------------------------------------
echo "• building (ENABLE_DEBUG_DYLIB=NO)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "platform=iOS,id=$DEVICE_ID" -derivedDataPath "$DD" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  ENABLE_DEBUG_DYLIB=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build >/tmp/_build.log 2>&1 || { tail -20 /tmp/_build.log; echo "✗ build failed"; exit 1; }
APP="$(find "$DD/Build/Products/Debug-iphoneos" -maxdepth 1 -name '*.app' | head -1)"
[ -n "$APP" ] || { echo "✗ no .app produced"; exit 1; }

# --- 5. sign nested Mach-O (defensive), embed profile, sign app --------------
cp "$PROFILE_PATH" "$APP/embedded.mobileprovision"
# sign every nested signable first (frameworks, loose dylibs) — leaf to root
find "$APP" \( -name '*.dylib' -o -name '*.framework' -o -name '*.appex' \) -print0 2>/dev/null \
  | while IFS= read -r -d '' n; do
      codesign --force --timestamp=none --sign "$IDENTITY_SHA" "$n" >/dev/null 2>&1 || true
    done
codesign --force --timestamp=none --sign "$IDENTITY_SHA" --entitlements /tmp/_ent.plist "$APP"
codesign --verify --verbose=2 "$APP" >/dev/null 2>&1 && echo "• signature   : valid"

# --- 6. install + launch -----------------------------------------------------
xcrun devicectl device install app --device "$DEVICE_ID" "$APP" >/dev/null
xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" >/dev/null
echo "✓ installed & launched $BUNDLE_ID on $DEVICE_ID"
