#!/bin/bash
# Capture the README's window images from the direct-download build:
#   docs/assets/window-effects.png, window-motion.png, window-look.png,
#   window-about.png — the settings window on each page, dark appearance,
#   at 2x, with no background or caption (the store screenshots come from
#   scripts/appstore-screenshots.sh instead).
#
#   scripts/make-window-shots.sh [app]
#
# Defaults to build/Macbook Duo.app (run ./build.sh first). Needs Screen
# Recording access for the terminal; without it the captures come out blank.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:-build/Macbook Duo.app}"
OUT_DIR="docs/assets"
PROCESS_NAME="MacbookDuo"
APP_PATTERN="/Contents/MacOS/$PROCESS_NAME\$"
LAUNCH_WAIT="${MACBOOKDUO_SCREENSHOT_WAIT:-5}"
LAUNCH_DEFAULTS=(-effect duo -effectIntensity 0.5 -appearance dark)
PAGES=(effects motion look about)

fail() { printf 'make-window-shots: %s\n' "$*" >&2; exit 1; }
[[ -d "$APP" ]] || fail "no app at $APP; run ./build.sh first"
OWNER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleDisplayName' "$APP/Contents/Info.plist" 2>/dev/null || true)"
[[ -n "$OWNER" ]] || fail "$APP has no CFBundleDisplayName"

TMP="$(mktemp -d)"
stop_app() {
  pkill -f "$APP_PATTERN" 2>/dev/null || true
  local tries=0
  while pgrep -f "$APP_PATTERN" >/dev/null && (( tries < 20 )); do sleep 0.25; tries=$((tries + 1)); done
}
trap 'stop_app; rm -rf "$TMP"' EXIT

cat > "$TMP/window-id.swift" <<'SWIFT'
import CoreGraphics
import Foundation
let prefix = CommandLine.arguments.dropFirst().first ?? "Macbook"
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    guard let owner = window[kCGWindowOwnerName as String] as? String, owner.hasPrefix(prefix),
          let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
          let number = window[kCGWindowNumber as String] as? Int else { continue }
    print(number); break
}
SWIFT

window_id() {
  local tries=0 id=""
  while (( tries < 20 )); do
    id="$(swift "$TMP/window-id.swift" "$OWNER" 2>/dev/null || true)"
    [[ -n "$id" ]] && { printf '%s\n' "$id"; return 0; }
    sleep 0.5; tries=$((tries + 1))
  done
  return 1
}

for page in "${PAGES[@]}"; do
  stop_app
  open -n "$APP" --args --tab "$page" "${LAUNCH_DEFAULTS[@]}"
  sleep "$LAUNCH_WAIT"
  id="$(window_id)" || fail "could not find the $OWNER window for the $page page"
  screencapture -l "$id" -o -x -t png "$OUT_DIR/window-$page.png"
  stop_app
  [[ -s "$OUT_DIR/window-$page.png" ]] || fail "screencapture produced no image for $page"
  printf 'Wrote %s/window-%s.png\n' "$OUT_DIR" "$page"
done
