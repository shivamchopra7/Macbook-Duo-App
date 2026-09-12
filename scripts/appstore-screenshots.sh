#!/bin/bash
# Build the Mac App Store screenshots from the packaged app:
#
#   docs/appstore/screenshots/01-effects.png        Effects page, dark appearance
#   docs/appstore/screenshots/02-motion.png         Motion page, dark appearance
#   docs/appstore/screenshots/03-look.png           Look page, dark appearance
#   docs/appstore/screenshots/04-about.png          About page, dark appearance
#   docs/appstore/screenshots/05-effects-light.png  Effects page, light appearance
#
# Every shot launches the app on one settings page, captures its window with
# screencapture, quits the app, then composites the capture onto a 2880×1800
# brand-blue gradient with a one-line caption at the top. The app comes from
# MACBOOKDUO_APP when that variable is set, otherwise from any "Lid Fold.app"
# (the store build's name) under build-appstore/, and as a last resort from
# build/Macbook Duo.app. The window is found by the name in the app's
# Info.plist, so either build works.
#
# Requires ffmpeg (brew install ffmpeg) and Screen Recording access for the
# terminal that runs the script; without it the captures come out blank. The
# caption uses ffmpeg's drawtext filter with the system font when the installed
# ffmpeg has it, and falls back to an AppKit-rendered overlay otherwise.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="docs/appstore/screenshots"
CANVAS_WIDTH=2880
CANVAS_HEIGHT=1800
WINDOW_WIDTH=2400
WINDOW_SHIFT=70            # Moves the window down so the caption has room above it.
CAPTION_TOP=70
CAPTION_HEIGHT=180
CAPTION_SIZE=68
GRADIENT_START=0x2F6BFF    # Brand blue, top left.
GRADIENT_END=0x0B1020      # Brand navy, bottom right.
LAUNCH_WAIT="${MACBOOKDUO_SCREENSHOT_WAIT:-5}"
PROCESS_NAME="MacbookDuo"
STORE_APP_NAME="Lid Fold"
WINDOW_OWNER_PREFIX=""     # Set from the app's CFBundleDisplayName in main.
# Per-launch defaults overrides (NSArgumentDomain), so the shots show the default
# effect and tuning whatever this Mac's saved preferences are. Nothing is written back.
LAUNCH_DEFAULTS=(-effect duo -effectIntensity 0.5)

# One entry per screenshot: file stem | settings page | appearance | caption.
SHOTS=(
  "01-effects|effects|dark|Twelve effects that follow your lid"
  "02-motion|motion|dark|Tune how the desktop follows your hand"
  "03-look|look|dark|Perspective, softness, shadow and appearance"
  "04-about|about|dark|Open source. No accounts, no analytics, no tracking."
  "05-effects-light|effects|light|Light, dark or system appearance"
)

fail() { printf 'appstore-screenshots: %s\n' "$*" >&2; exit 1; }

find_app() {
  if [[ -n "${MACBOOKDUO_APP:-}" ]]; then
    [[ -d "$MACBOOKDUO_APP" ]] || fail "MACBOOKDUO_APP is not a directory: $MACBOOKDUO_APP"
    printf '%s\n' "$MACBOOKDUO_APP"
    return 0
  fi
  local candidate=""
  if [[ -d build-appstore ]]; then
    candidate="$(find build-appstore -type d -name "$STORE_APP_NAME.app" -print -quit)"
  fi
  if [[ -z "$candidate" && -d "build/Macbook Duo.app" ]]; then candidate="build/Macbook Duo.app"; fi
  [[ -n "$candidate" ]] || fail "no packaged app found; run scripts/appstore.sh export or ./build.sh first"
  printf '%s\n' "$candidate"
}

find_font() {
  local candidate
  for candidate in /System/Library/Fonts/SFNS.ttf /System/Library/Fonts/Helvetica.ttc; do
    if [[ -f "$candidate" ]]; then printf '%s\n' "$candidate"; return 0; fi
  done
  printf '\n'
}

# The bundle of an already running Macbook Duo, so it can be reopened afterwards.
running_bundle() {
  local pid="" exe=""
  pid="$(pgrep -x "$PROCESS_NAME" | head -n 1 || true)"
  if [[ -n "$pid" ]]; then exe="$(ps -o comm= -p "$pid" 2>/dev/null || true)"; fi
  if [[ "$exe" == *"/Contents/MacOS/$PROCESS_NAME" ]]; then printf '%s\n' "${exe%/Contents/MacOS/$PROCESS_NAME}"; fi
  return 0
}

write_helpers() {
  cat > "$TMP/window-id.swift" <<'EOF'
import CoreGraphics
import Foundation
// Prints the number of the first normal-level window whose owner starts with the given prefix.
let prefix = CommandLine.arguments.dropFirst().first ?? "Macbook"
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    guard let owner = window[kCGWindowOwnerName as String] as? String, owner.hasPrefix(prefix),
          let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
          let number = window[kCGWindowNumber as String] as? Int else { continue }
    print(number)
    break
}
EOF
  cat > "$TMP/caption.swift" <<'EOF'
import AppKit
import Foundation
// Renders one line of white text, centred, onto a transparent PNG.
// Usage: caption.swift <output.png> <width> <height> <font size> <text...>
let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 5, let width = Int(arguments[1]), let height = Int(arguments[2]),
      let size = Double(arguments[3]) else {
    FileHandle.standardError.write(Data("usage: caption.swift <output.png> <width> <height> <font size> <text>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: arguments[0])
let text = arguments[4...].joined(separator: " ")
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                    samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("caption.swift: could not create a bitmap context\n".utf8))
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: size, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph,
    .kern: -0.5,
]
let string = NSAttributedString(string: text, attributes: attributes)
let measured = string.size()
let top = (Double(height) - Double(measured.height)) / 2
string.draw(in: NSRect(x: 0, y: top, width: Double(width), height: Double(measured.height)))
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("caption.swift: could not encode the PNG\n".utf8))
    exit(1)
}
do {
    try png.write(to: output)
} catch {
    FileHandle.standardError.write(Data("caption.swift: \(error.localizedDescription)\n".utf8))
    exit(1)
}
EOF
}

stop_app() {
  pkill -x "$PROCESS_NAME" 2>/dev/null || true
  local tries=0
  while pgrep -x "$PROCESS_NAME" >/dev/null && (( tries < 20 )); do
    sleep 0.25
    tries=$((tries + 1))
  done
}

window_id() {
  local tries=0 id=""
  while (( tries < 20 )); do
    id="$(swift "$TMP/window-id.swift" "$WINDOW_OWNER_PREFIX" 2>/dev/null || true)"
    if [[ -n "$id" ]]; then printf '%s\n' "$id"; return 0; fi
    sleep 0.5
    tries=$((tries + 1))
  done
  return 1
}

capture_window() {
  local app="$1" tab="$2" appearance="$3" output="$4" id=""
  stop_app
  # --tab picks the settings page; -appearance and LAUNCH_DEFAULTS are defaults
  # overrides for this launch only, so the user's saved preferences are left untouched.
  open -n "$app" --args --tab "$tab" -appearance "$appearance" "${LAUNCH_DEFAULTS[@]}"
  sleep "$LAUNCH_WAIT"
  id="$(window_id)" || fail "could not find the $WINDOW_OWNER_PREFIX window for the $tab page"
  screencapture -l "$id" -o -x -t png "$output"
  stop_app
  [[ -s "$output" ]] || fail "screencapture produced no image for the $tab page"
}

compose() {
  local capture="$1" caption="$2" output="$3"
  local gradient="gradients=s=${CANVAS_WIDTH}x${CANVAS_HEIGHT}:c0=${GRADIENT_START}:c1=${GRADIENT_END}"
  gradient+=":x0=0:y0=0:x1=${CANVAS_WIDTH}:y1=${CANVAS_HEIGHT}:nb_colors=2:type=linear"
  local place="[1:v]scale=${WINDOW_WIDTH}:-1[window];"
  place+="[0:v][window]overlay=(W-w)/2:(H-h)/2+${WINDOW_SHIFT}:format=auto[base]"
  if [[ "$HAS_DRAWTEXT" == yes && -n "$FONT" ]]; then
    printf '%s' "$caption" > "$TMP/caption.txt"
    local text="[base]drawtext=fontfile=${FONT}:textfile=${TMP}/caption.txt:fontcolor=white:fontsize=${CAPTION_SIZE}"
    text+=":x=(w-text_w)/2:y=${CAPTION_TOP}+(${CAPTION_HEIGHT}-text_h)/2[out]"
    ffmpeg -loglevel error -y -f lavfi -i "$gradient" -i "$capture" \
      -filter_complex "${place};${text}" -map "[out]" -frames:v 1 -pix_fmt rgb24 "$output"
  else
    swift "$TMP/caption.swift" "$TMP/caption.png" "$CANVAS_WIDTH" "$CAPTION_HEIGHT" "$CAPTION_SIZE" "$caption"
    ffmpeg -loglevel error -y -f lavfi -i "$gradient" -i "$capture" -i "$TMP/caption.png" \
      -filter_complex "${place};[base][2:v]overlay=0:${CAPTION_TOP}:format=auto[out]" \
      -map "[out]" -frames:v 1 -pix_fmt rgb24 "$output"
  fi
}

verify_output() {
  local output="$1" width="" height=""
  width="$(sips -g pixelWidth "$output" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$output" | awk '/pixelHeight/ {print $2}')"
  [[ "$width" == "$CANVAS_WIDTH" && "$height" == "$CANVAS_HEIGHT" ]] \
    || fail "$output is ${width}x${height}, expected ${CANVAS_WIDTH}x${CANVAS_HEIGHT}"
}

main() {
  command -v ffmpeg >/dev/null || fail "ffmpeg is required (brew install ffmpeg)"
  local app="" relaunch="" filters="" shot="" stem="" tab="" appearance="" caption=""
  app="$(find_app)"
  WINDOW_OWNER_PREFIX="$(/usr/libexec/PlistBuddy -c 'Print CFBundleDisplayName' "$app/Contents/Info.plist" 2>/dev/null || true)"
  [[ -n "$WINDOW_OWNER_PREFIX" ]] || fail "$app has no CFBundleDisplayName"
  FONT="$(find_font)"
  HAS_DRAWTEXT=no
  filters="$(ffmpeg -hide_banner -filters 2>/dev/null || true)"
  [[ "$filters" == *" drawtext "* ]] && HAS_DRAWTEXT=yes
  TMP="$(mktemp -d)"
  trap 'stop_app; rm -rf "$TMP"' EXIT
  write_helpers
  mkdir -p "$OUT_DIR"
  relaunch="$(running_bundle)"
  if [[ -n "$relaunch" ]]; then
    printf 'Quitting the running Macbook Duo (%s); it is reopened when the shots are done.\n' "$relaunch"
  fi
  printf 'App: %s (window owner "%s")\n' "$app" "$WINDOW_OWNER_PREFIX"
  if [[ "$HAS_DRAWTEXT" == yes && -n "$FONT" ]]; then
    printf 'Caption: ffmpeg drawtext with %s\n' "$FONT"
  else
    printf 'Caption: AppKit overlay (this ffmpeg has no drawtext filter)\n'
  fi
  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r stem tab appearance caption <<< "$shot"
    capture_window "$app" "$tab" "$appearance" "$TMP/$stem-window.png"
    compose "$TMP/$stem-window.png" "$caption" "$OUT_DIR/$stem.png"
    verify_output "$OUT_DIR/$stem.png"
    printf 'Wrote %s/%s.png\n' "$OUT_DIR" "$stem"
  done
  if [[ -n "$relaunch" ]]; then open "$relaunch"; fi
}

main "$@"
