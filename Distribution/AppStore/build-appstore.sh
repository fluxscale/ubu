#!/usr/bin/env bash
# Builds, signs and packages the Mac App Store edition of ubu (sandboxed, StoreKit
# subscription, no self-updater, no automatic login item).
#
#   Distribution/AppStore/build-appstore.sh 1.1.0             # build, sign, package
#   UPLOAD=1 Distribution/AppStore/build-appstore.sh 1.1.0    # ...then validate and upload
#
# One-time setup (certificates, provisioning profile, API key): Distribution/AppStore/README.md
#
# Local dry run with no App Store certificates (sandboxed, Developer ID signed, unsigned pkg):
#   APP_IDENTITY="Developer ID Application: FLUXSCALE LIMITED (Z36JCF24WU)" PROFILE= INSTALLER_IDENTITY= \
#     Distribution/AppStore/build-appstore.sh 1.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

VERSION="${1:?usage: build-appstore.sh <version> [build-number]}"
BUILD_NUMBER="${2:-$(date +%Y%m%d%H%M)}" # App Store Connect needs a higher one on every upload
TEAM_ID="${TEAM_ID:-Z36JCF24WU}"
BUNDLE_ID="${BUNDLE_ID:-com.fluxscale.ubu}"
APP_IDENTITY="${APP_IDENTITY-3rd Party Mac Developer Application: FLUXSCALE LIMITED ($TEAM_ID)}"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY-3rd Party Mac Developer Installer: FLUXSCALE LIMITED ($TEAM_ID)}"
PROFILE="${PROFILE-$SCRIPT_DIR/ubu.provisionprofile}"

OUT="$PROJECT_ROOT/.build/appstore-package"
APP="$OUT/ubu.app"
PKG="$PROJECT_ROOT/ubu-appstore.pkg"
PLIST="$APP/Contents/Info.plist"
ENTITLEMENTS="$OUT/ubu.entitlements"
BUDDY=/usr/libexec/PlistBuddy

fail() { echo "error: $*" >&2; exit 1; }

echo "=== ubu App Store edition v$VERSION ($BUILD_NUMBER) ==="

# Separate scratch path: the App Store binary must never end up in the DMG, or vice versa.
BINARY="$("$PROJECT_ROOT/Distribution/build-universal.sh" \
    --scratch-path "$PROJECT_ROOT/.build/appstore" -Xswiftc -DAPP_STORE)"

echo "Assembling app bundle..."
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/ubu"
cp "$PROJECT_ROOT/Resources/Info.plist" "$PLIST"
cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$PROJECT_ROOT/Resources/PrivacyInfo.xcprivacy" "$APP/Contents/Resources/"
$BUDDY -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST"
$BUDDY -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
$BUDDY -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"

cp "$SCRIPT_DIR/ubu.entitlements" "$ENTITLEMENTS"
if [[ -n "$PROFILE" ]]; then
    [[ -f "$PROFILE" ]] || fail "provisioning profile not found: $PROFILE (see Distribution/AppStore/README.md)"
    PROFILE_APP_ID="$(security cms -D -i "$PROFILE" | plutil -extract Entitlements.com\\.apple\\.application-identifier raw -)"
    [[ "$PROFILE_APP_ID" == "$TEAM_ID.$BUNDLE_ID" ]] \
        || fail "profile is for $PROFILE_APP_ID, expected $TEAM_ID.$BUNDLE_ID"
    cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
    # The profile authorizes these; the signature has to carry them too.
    $BUDDY -c "Add :com.apple.application-identifier string $TEAM_ID.$BUNDLE_ID" "$ENTITLEMENTS"
    $BUDDY -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$ENTITLEMENTS"
else
    echo "warning: no provisioning profile; fine for a local test, rejected by App Store Connect" >&2
fi

echo "Signing app..."
codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS" --sign "$APP_IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
codesign -d --entitlements - --xml "$APP" 2>/dev/null | grep -q "com.apple.security.app-sandbox" \
    || fail "signed app is not sandboxed"

echo "Packaging..."
rm -f "$PKG"
if [[ -n "$INSTALLER_IDENTITY" ]]; then
    productbuild --component "$APP" /Applications --sign "$INSTALLER_IDENTITY" "$PKG"
else
    productbuild --component "$APP" /Applications "$PKG"
    echo "warning: package is unsigned; App Store Connect will reject it" >&2
fi

if [[ "${UPLOAD:-0}" == 1 ]]; then
    : "${ASC_KEY_ID:?set ASC_KEY_ID (App Store Connect API key ID)}"
    : "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (App Store Connect API issuer ID)}"
    AUTH=(--apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID")
    echo "Validating with App Store Connect..."
    xcrun altool --validate-app -f "$PKG" -t macos "${AUTH[@]}"
    echo "Uploading..."
    xcrun altool --upload-app -f "$PKG" -t macos "${AUTH[@]}"
    echo "=== Uploaded build $BUILD_NUMBER. It shows up in App Store Connect after processing. ==="
else
    echo "=== Package ready: $PKG ==="
    echo "Upload with UPLOAD=1 (API key) or drag it into Transporter."
fi
