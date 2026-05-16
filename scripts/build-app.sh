#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="StatBar"
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
EXECUTABLE_PATH="$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"
VERSION_FILE="$ROOT_DIR/version.txt"

cd "$ROOT_DIR"

# Auto-increment build version
BUILD_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "1")
NEW_VERSION=$((BUILD_VERSION + 1))
echo "$NEW_VERSION" > "$VERSION_FILE"
echo "Build version: $BUILD_VERSION → $NEW_VERSION"

swift build -c "$CONFIGURATION"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"

install -m 755 "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

# Copy resources
RESOURCES_DIR="$CONTENTS_DIR/Resources"
mkdir -p "$RESOURCES_DIR"

AVATAR_SRC="$ROOT_DIR/Resources/avatar.jpeg"
if [ -f "$AVATAR_SRC" ]; then
    cp "$AVATAR_SRC" "$RESOURCES_DIR/"
fi

ICON_SRC="$ROOT_DIR/Resources/AppIcon.icns"
if [ -f "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$RESOURCES_DIR/"
fi

sed \
  -e "s/\$(DEVELOPMENT_LANGUAGE)/en/g" \
  -e "s/\$(EXECUTABLE_NAME)/$APP_NAME/g" \
  -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/com.chenpeng.StatBar/g" \
  -e "s/\$(PRODUCT_NAME)/$APP_NAME/g" \
  -e "s/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g" \
  -e "s/\$(BUILD_VERSION)/$BUILD_VERSION/g" \
  "$ROOT_DIR/StatBar/Info.plist" > "$CONTENTS_DIR/Info.plist"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"
