#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
APP_DIR="$BUILD_DIR/Fractal.app"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BUILD_DIR/Fractal" "$APP_DIR/Contents/MacOS/Fractal"
cp "$ROOT_DIR/Support/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Support/FractalLogo.svg" "$APP_DIR/Contents/Resources/FractalLogo.svg"

echo "Created $APP_DIR"
