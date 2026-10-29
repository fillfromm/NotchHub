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
# Assemble and sign in a temp dir: folders synced by iCloud/Finder (Desktop, Documents)
# add metadata that makes codesign fail with "detritus not allowed".
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
STAGED="$STAGE/$APP_NAME.app"
mkdir -p "$STAGED/Contents/MacOS" "$STAGED/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$STAGED/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$STAGED/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$STAGED/Contents/Resources/AppIcon.icns"

# Ad-hoc signing gives the app a stable identity so macOS remembers the
# Automation / Calendar permissions between launches.
codesign --force --sign - --identifier com.notchhub.app "$STAGED"

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p build
ditto --norsrc --noextattr --noqtn "$STAGED" "$APP"

echo "==> Built $APP"
if [ "$RUN" = "1" ]; then
  pkill -x "$APP_NAME" 2>/dev/null || true
  open "$APP"
  echo "==> Launched. Look at the top of your screen (and the menu bar icon)."
fi
