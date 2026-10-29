#!/bin/bash
# Builds NotchHub.app from the command line (no Xcode project needed) and launches it.
#
#   ./build.sh            build + launch
#   ./build.sh --no-run   build only
#   ./build.sh --debug    debug configuration
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="NotchHub"
CONFIG="release"
RUN=1
for arg in "$@"; do
  case "$arg" in
    --no-run) RUN=0 ;;
    --debug)  CONFIG="debug" ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

echo "==> Compiling ($CONFIG)"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

echo "==> Assembling build/$APP_NAME.app"
APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signing gives the app a stable identity so macOS remembers the
# Automation / Calendar permissions between launches.
xattr -cr "$APP" 2>/dev/null || true
codesign --force --sign - --identifier com.notchhub.app "$APP"

echo "==> Built $APP"
if [ "$RUN" = "1" ]; then
  pkill -x "$APP_NAME" 2>/dev/null || true
  open "$APP"
  echo "==> Launched. Look at the top of your screen (and the menu bar icon)."
fi
