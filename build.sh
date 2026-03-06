#!/bin/bash
set -e

APP_NAME="FlowVoice"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
ARCH=$(uname -m)

echo "Building $APP_NAME for $ARCH..."

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -parse-as-library \
    -target "${ARCH}-apple-macosx14.0" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework AVFoundation \
    -framework Carbon \
    -framework ApplicationServices \
    FlowVoice/*.swift

cp Resources/Info.plist "$CONTENTS/"

codesign \
    --entitlements Resources/FlowVoice.entitlements \
    --force \
    --sign - \
    "$APP_BUNDLE"

echo ""
echo "Built: $APP_BUNDLE"
echo "Run:  open $APP_BUNDLE"
