#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/.build/release"
APP_NAME="ubu"
DMG_NAME="ubu.dmg"
STAGING_DIR="$PROJECT_ROOT/.build/dmg-staging"
VERSION="${1:-1.0.0}"

echo "=== Building ubu v${VERSION} ==="

# Build universal binary
echo "Building universal binary..."
cd "$PROJECT_ROOT"
swift build -c release --arch arm64 --arch x86_64

# Create .app bundle
echo "Creating app bundle..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$STAGING_DIR/$APP_NAME.app/Contents/Resources"

cp "$BUILD_DIR/ubu" "$STAGING_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
cp "$PROJECT_ROOT/Resources/Info.plist" "$STAGING_DIR/$APP_NAME.app/Contents/Info.plist"
cp "$PROJECT_ROOT/Resources/AppIcon.icns" "$STAGING_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"

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

echo "=== DMG created: $PROJECT_ROOT/$DMG_NAME ==="

# Cleanup
rm -rf "$STAGING_DIR"
