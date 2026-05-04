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

# Create DMG
echo "Creating DMG..."
rm -f "$PROJECT_ROOT/$DMG_NAME"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO \
    "$PROJECT_ROOT/$DMG_NAME"

echo "=== DMG created: $PROJECT_ROOT/$DMG_NAME ==="

# Cleanup
rm -rf "$STAGING_DIR"
