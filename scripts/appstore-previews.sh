#!/bin/bash
# Build the Mac App Store app previews and the effect screenshots from the
# render check's exported animation frames:
#
#   docs/appstore/previews/01-lid-fold.mp4       Fold, Roll, Curtain, Blackhole, Iris, Duo
#   docs/appstore/previews/02-more-effects.mp4   Accordion, Louver, Card, Shutter, Flex, Ghost
#   docs/appstore/screenshots/06-fold.png … 10-louver.png   one effect each, mid-close
#
# App Store Connect takes Mac app previews at 1920×1080, H.264, 30 fps, 15 to
# 30 seconds, and Mac screenshots at 2880×1800 (the size the other five use).
# Each preview is a title card, six three-second effect clips with a caption,
# and an end card: about 23 seconds. Every frame is the app's own Metal effect
# rendered on its built-in preview artwork, so no real desktop appears.
#
# Usage:
#   scripts/appstore-previews.sh [frames-dir]
#
# frames-dir is the render check's output directory, which needs frames at
# least 1920 pixels wide:
#   .build-appstore/debug/MacbookDuo --render-check <dir> --animation \
#       --animation-size 1920x1248 --no-timing
# (the store flavour, so the artwork says Lid Fold). Without an argument the
# script looks for validation/render. Requires ffmpeg (brew install ffmpeg).
set -euo pipefail
cd "$(dirname "$0")/.."

FRAMES="${1:-validation/render}"
PREVIEW_DIR="docs/appstore/previews"
SHOT_DIR="docs/appstore/screenshots"
WIDTH=1920
HEIGHT=1080
FPS=30
CLIP_SECONDS=3          # 180 frames at 60 fps
CARD_SECONDS=2.5
CLIP_HEIGHT=820         # the effect frame inside the 1080-pixel canvas
CLIP_SHIFT=80           # moved down so the caption has room above it
SHOT_WIDTH=2880
SHOT_HEIGHT=1800
SHOT_FRAME=045          # about half closed: progress = sin²(45/179·π)
GRADIENT_START="2F6BFF" # brand blue, top left
GRADIENT_END="0B1020"   # brand navy, bottom right
MIN_SECONDS=15
MAX_SECONDS=30

# effect id | display name | caption
EFFECTS=(
  "duo|Duo|The desktop swells around the hinge"
  "fold|Fold|Creases across the middle and folds over"
  "roll|Roll|Curls into a roll down to the hinge"
  "curtain|Curtain|Drapes draw together from both sides"
  "ripple|Blackhole|Liquid rings pull the desktop into the hinge"
  "iris|Iris|Eight blades close over the hinge"
  "accordion|Accordion|Pleats gather like a paper fan"
  "louver|Louver|Slats tilt and overlap like blinds"
  "card|Card|The whole desktop tips back in perspective"
  "shutter|Shutter|Rigid panels telescope into the hinge"
  "flex|Flex|One bowing display collapses"
  "ghost|Ghost|The desktop gently falls out of focus"
)
# Fold opens the first preview because Duo, the default, spends most of its
# clip defocused; Duo closes the preview so its reopening leads into the end card.
PREVIEW_ONE=(fold roll curtain ripple iris duo)
PREVIEW_TWO=(accordion louver card shutter flex ghost)
# screenshot stem | effect id
SHOTS=(
  "06-fold|fold"
  "07-blackhole|ripple"
  "08-curtain|curtain"
  "09-accordion|accordion"
  "10-louver|louver"
)

fail() { printf 'appstore-previews: %s\n' "$*" >&2; exit 1; }

effect_field() {  # effect_field <id> <2=name|3=caption>
  local entry
  for entry in "${EFFECTS[@]}"; do
    if [[ "${entry%%|*}" == "$1" ]]; then cut -d'|' -f"$2" <<<"$entry"; return 0; fi
  done
  fail "unknown effect $1"
}

write_helper() {
  # Renders one card: a brand gradient (or a transparent canvas), an optional
  # icon, a title and a subtitle, centred. AppKit does the text so the script
  # does not depend on ffmpeg's drawtext filter, which Homebrew builds omit.
  cat > "$TMP/card.swift" <<'EOF'
import AppKit
import Foundation
// Usage: card.swift <out.png> <width> <height> <gradient|transparent> <icon path or -> <title> <subtitle> <title size> <top>
let a = Array(CommandLine.arguments.dropFirst())
guard a.count == 9, let width = Int(a[1]), let height = Int(a[2]), let titleSize = Double(a[7]), let top = Double(a[8]) else {
    FileHandle.standardError.write(Data("usage: card.swift <out.png> <w> <h> <gradient|transparent> <icon|-> <title> <subtitle> <title size> <top>\n".utf8))
    exit(2)
}
let output = URL(fileURLWithPath: a[0])
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                    samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("card.swift: could not create a bitmap context\n".utf8))
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
let canvas = NSRect(x: 0, y: 0, width: width, height: height)
if a[3] == "gradient" {
    let blue = NSColor(red: 0x2F/255, green: 0x6B/255, blue: 1, alpha: 1)
    let navy = NSColor(red: 0x0B/255, green: 0x10/255, blue: 0x20/255, alpha: 1)
    NSGradient(starting: blue, ending: navy)!.draw(in: canvas, angle: -35)
}
// Everything is measured from the top of the canvas; AppKit's origin is the bottom.
var cursor = Double(height) - top
if a[4] != "-", let icon = NSImage(contentsOfFile: a[4]) {
    let side = titleSize * 2.6
    cursor -= side
    icon.draw(in: NSRect(x: (Double(width) - side) / 2, y: cursor, width: side, height: side),
              from: .zero, operation: .sourceOver, fraction: 1)
    cursor -= titleSize * 0.45
}
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
func draw(_ text: String, size: Double, weight: NSFont.Weight, alpha: Double) {
    guard !text.isEmpty else { return }
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        .paragraphStyle: paragraph, .kern: -0.5,
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let measured = string.size()
    cursor -= Double(measured.height)
    string.draw(in: NSRect(x: 0, y: cursor, width: Double(width), height: Double(measured.height)))
    cursor -= size * 0.35
}
draw(a[5], size: titleSize, weight: .bold, alpha: 1)
draw(a[6], size: titleSize * 0.5, weight: .medium, alpha: 0.85)
NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("card.swift: could not encode the PNG\n".utf8))
    exit(1)
}
do { try png.write(to: output) } catch {
    FileHandle.standardError.write(Data("card.swift: \(error.localizedDescription)\n".utf8))
    exit(1)
}
EOF
}

card() {  # card <out.png> <w> <h> <gradient|transparent> <icon|-> <title> <subtitle> <title size> <top>
  swift "$TMP/card.swift" "$@"
}

background() {  # background <out.png> <w> <h>
  local gradient="gradients=s=$2x$3:c0=0x${GRADIENT_START}:c1=0x${GRADIENT_END}"
  gradient+=":x0=0:y0=0:x1=$2:y1=$3:nb_colors=2:type=linear"
  ffmpeg -loglevel error -y -f lavfi -i "$gradient" -frames:v 1 "$1"
}

frames_dir() {  # frames_dir <effect id>
  local dir="$FRAMES/animation/$1"
  [[ -f "$dir/frame-000.png" && -f "$dir/frame-179.png" ]] || fail "no frames for $1 in $dir; run the render check with --animation --animation-size 1920x1248 first"
  local width; width="$(sips -g pixelWidth "$dir/frame-000.png" | awk '/pixelWidth/ {print $2}')"
  (( width >= WIDTH )) || fail "frames in $dir are ${width}px wide; render them with --animation-size 1920x1248"
  printf '%s\n' "$dir"
}

# One three-second clip: the effect frames scaled onto the gradient with the
# effect's name and caption above.
clip() {  # clip <effect id> <out.mp4>
  local id="$1" out="$2" dir name caption
  dir="$(frames_dir "$id")"
  name="$(effect_field "$id" 2)"; caption="$(effect_field "$id" 3)"
  card "$TMP/caption-$id.png" "$WIDTH" "$HEIGHT" transparent - "$name" "$caption" 56 36
  ffmpeg -loglevel error -y -framerate 60 -i "$dir/frame-%03d.png" -i "$TMP/bg.png" -i "$TMP/caption-$id.png" \
    -filter_complex "[0:v]scale=-2:${CLIP_HEIGHT}[fx];[1:v][fx]overlay=(W-w)/2:(H-h)/2+${CLIP_SHIFT}:format=auto[base];[base][2:v]overlay=0:0:format=auto,fps=${FPS},format=yuv420p[out]" \
    -map "[out]" -t "$CLIP_SECONDS" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r "$FPS" -an "$out"
}

still() {  # still <card.png> <out.mp4>: a card held for CARD_SECONDS
  ffmpeg -loglevel error -y -loop 1 -framerate "$FPS" -i "$1" -t "$CARD_SECONDS" \
    -vf "format=yuv420p" -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r "$FPS" -an "$2"
}

preview() {  # preview <out.mp4> <title> <subtitle> <effect ids...>
  local out="$1" title="$2" subtitle="$3"; shift 3
  local list="$TMP/$(basename "$out" .mp4).txt" id part
  : > "$list"
  card "$TMP/title.png" "$WIDTH" "$HEIGHT" gradient "$ICON" "$title" "$subtitle" 120 300
  still "$TMP/title.png" "$TMP/title.mp4"
  printf "file '%s'\n" "$TMP/title.mp4" >> "$list"
  for id in "$@"; do
    part="$TMP/clip-$id.mp4"
    [[ -f "$part" ]] || clip "$id" "$part"
    printf "file '%s'\n" "$part" >> "$list"
  done
  card "$TMP/end.png" "$WIDTH" "$HEIGHT" gradient "$ICON" "Twelve effects. One lid." "Private by design. Free on the Mac App Store." 96 330
  still "$TMP/end.png" "$TMP/end.mp4"
  printf "file '%s'\n" "$TMP/end.mp4" >> "$list"
  ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" -c copy -movflags +faststart "$out"
  verify_preview "$out"
}

verify_preview() {
  local out="$1" width height seconds
  width="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$out")"
  height="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$out")"
  seconds="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$out" | cut -d. -f1)"
  [[ "$width" == "$WIDTH" && "$height" == "$HEIGHT" ]] || fail "$out is ${width}x${height}, expected ${WIDTH}x${HEIGHT}"
  (( seconds >= MIN_SECONDS && seconds <= MAX_SECONDS )) || fail "$out runs ${seconds}s; App Store Connect takes ${MIN_SECONDS}–${MAX_SECONDS}s"
  printf 'Wrote %s (%sx%s, %ss)\n' "$out" "$width" "$height" "$seconds"
}

# One 2880×1800 screenshot: the effect half closed, with its name as caption.
screenshot() {  # screenshot <stem> <effect id>
  local stem="$1" id="$2" dir name caption out="$SHOT_DIR/$1.png"
  dir="$(frames_dir "$id")"
  name="$(effect_field "$id" 2)"; caption="$(effect_field "$id" 3)"
  card "$TMP/shot-caption-$id.png" "$SHOT_WIDTH" "$SHOT_HEIGHT" transparent - "$name: $caption" "" 68 92
  ffmpeg -loglevel error -y -i "$dir/frame-$SHOT_FRAME.png" -i "$TMP/shot-bg.png" -i "$TMP/shot-caption-$id.png" \
    -filter_complex "[0:v]scale=2160:-2[fx];[1:v][fx]overlay=(W-w)/2:(H-h)/2+90:format=auto[base];[base][2:v]overlay=0:0:format=auto[out]" \
    -map "[out]" -frames:v 1 -pix_fmt rgb24 "$out"
  local width height
  width="$(sips -g pixelWidth "$out" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$out" | awk '/pixelHeight/ {print $2}')"
  [[ "$width" == "$SHOT_WIDTH" && "$height" == "$SHOT_HEIGHT" ]] || fail "$out is ${width}x${height}, expected ${SHOT_WIDTH}x${SHOT_HEIGHT}"
  printf 'Wrote %s\n' "$out"
}

main() {
  command -v ffmpeg >/dev/null || fail "ffmpeg is required (brew install ffmpeg)"
  command -v ffprobe >/dev/null || fail "ffprobe is required (it comes with ffmpeg)"
  [[ -d "$FRAMES/animation" ]] || fail "no animation frames under $FRAMES; see the usage comment at the top of this script"
  ICON="Resources/MacbookDuoIcon.png"
  [[ -f "$ICON" ]] || fail "missing $ICON"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  write_helper
  background "$TMP/bg.png" "$WIDTH" "$HEIGHT"
  background "$TMP/shot-bg.png" "$SHOT_WIDTH" "$SHOT_HEIGHT"
  mkdir -p "$PREVIEW_DIR" "$SHOT_DIR"
  preview "$PREVIEW_DIR/01-lid-fold.mp4" "Lid Fold" "Your desktop follows your lid" "${PREVIEW_ONE[@]}"
  preview "$PREVIEW_DIR/02-more-effects.mp4" "Six more ways to close" "Every effect tracks the lid angle in real time" "${PREVIEW_TWO[@]}"
  local shot stem id
  for shot in "${SHOTS[@]}"; do
    IFS='|' read -r stem id <<< "$shot"
    screenshot "$stem" "$id"
  done
}

main "$@"
