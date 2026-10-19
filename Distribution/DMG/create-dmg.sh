#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_NAME="ubu"
DMG_NAME="ubu.dmg"
STAGING_DIR="$PROJECT_ROOT/.build/dmg-staging"
VERSION="${1:-1.0.0}"

# Signing config. Set SIGN_IDENTITY="" to skip signing/notarization.
SIGN_IDENTITY="${SIGN_IDENTITY-Developer ID Application: FLUXSCALE LIMITED (Z36JCF24WU)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-ubu-notary}"

echo "=== Building ubu v${VERSION} ==="

echo "Building universal binary..."
cd "$PROJECT_ROOT"
BINARY="$("$PROJECT_ROOT/Distribution/build-universal.sh")"

# Create .app bundle
echo "Creating app bundle..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$STAGING_DIR/$APP_NAME.app/Contents/Resources"

cp "$BINARY" "$STAGING_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
cp "$PROJECT_ROOT/Resources/Info.plist" "$STAGING_DIR/$APP_NAME.app/Contents/Info.plist"

# Stamp version into the bundle so it matches the release tag
PLIST="$STAGING_DIR/$APP_NAME.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$PLIST"

cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$PROJECT_ROOT/Resources/PrivacyInfo.xcprivacy" "$STAGING_DIR/$APP_NAME.app/Contents/Resources/"

# Sign the app with hardened runtime (required for notarization)
if [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing app..."
    codesign --force --deep --options runtime --timestamp \
        --sign "$SIGN_IDENTITY" \
        "$STAGING_DIR/$APP_NAME.app"
    codesign --verify --strict --verbose=2 "$STAGING_DIR/$APP_NAME.app"
fi

# Add Applications symlink for drag-to-install
ln -s /Applications "$STAGING_DIR/Applications"

# Create temporary read-write DMG
echo "Creating DMG..."
rm -f "$PROJECT_ROOT/$DMG_NAME"
TEMP_DMG="$PROJECT_ROOT/.build/ubu-temp.dmg"
rm -f "$TEMP_DMG"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDRW \
    -fs HFS+ \
    "$TEMP_DMG"

# Mount and apply window layout
MOUNT_DIR=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify | grep "/Volumes/$APP_NAME" | awk '{print $3}')
echo "Mounted at: $MOUNT_DIR"

# Set DMG window appearance via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 640, 400}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 128
        set position of item "$APP_NAME.app" of container window to {140, 150}
        set position of item "Applications" of container window to {400, 150}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Set custom background color (optional - makes it look polished)
SetFile -a V "$MOUNT_DIR" 2>/dev/null || true

sync
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$PROJECT_ROOT/$DMG_NAME"
rm -f "$TEMP_DMG"

# Sign, notarize, and staple the DMG
if [ -n "$SIGN_IDENTITY" ]; then
    echo "Signing DMG..."
    codesign --force --sign "$SIGN_IDENTITY" --timestamp "$PROJECT_ROOT/$DMG_NAME"

    echo "Notarizing (this takes a few minutes)..."
    xcrun notarytool submit "$PROJECT_ROOT/$DMG_NAME" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "Stapling ticket..."
    xcrun stapler staple "$PROJECT_ROOT/$DMG_NAME"
    xcrun stapler validate "$PROJECT_ROOT/$DMG_NAME"
fi

echo "=== DMG created: $PROJECT_ROOT/$DMG_NAME ==="

# Cleanup
rm -rf "$STAGING_DIR"
