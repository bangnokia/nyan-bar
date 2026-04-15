#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="NyanBar"
APP_SOURCE="$ROOT_DIR/dist/${APP_NAME}.app"
APP_DEST_DIR="$HOME/Applications"
APP_DEST="$APP_DEST_DIR/${APP_NAME}.app"

"$ROOT_DIR/scripts/build_app.sh"

mkdir -p "$APP_DEST_DIR"
rm -rf "$APP_DEST"
cp -R "$APP_SOURCE" "$APP_DEST"

open "$APP_DEST"

echo "Installed and launched: $APP_DEST"
