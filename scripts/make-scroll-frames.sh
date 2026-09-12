#!/bin/bash
# Cut the website's scroll-to-close sequence from the render check's Shutter
# animation frames: docs/assets/shutter-frames/f-000.jpg … f-090.jpg, the
# closing half of the animation (frame 90 is fully closed), 1280 pixels wide.
# The page scrubs through them as the visitor scrolls (see index.html).
#
#   scripts/make-scroll-frames.sh [frames-dir]
#
# frames-dir is the render check's output directory; render it with the
# direct-download flavour so the artwork says Macbook Duo:
#   .build/debug/MacbookDuo --render-check <dir> --animation \
#       --animation-size 1920x1248 --no-timing --effects shutter
# Without an argument the script looks for validation/render. Needs ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."

FRAMES="${1:-validation/render}"
SRC="$FRAMES/animation/shutter"
OUT="docs/assets/shutter-frames"
LAST=90
WIDTH=1280
QUALITY=4   # ffmpeg mjpeg scale, 2 (best) to 31; 4 is about 25 KB a frame here

fail() { printf 'make-scroll-frames: %s\n' "$*" >&2; exit 1; }
command -v ffmpeg >/dev/null || fail "ffmpeg is required (brew install ffmpeg)"
[[ -f "$SRC/frame-000.png" && -f "$SRC/$(printf "frame-%03d.png" "$LAST")" ]] || fail "no Shutter frames in $SRC; see the usage comment at the top of this script"
width="$(sips -g pixelWidth "$SRC/frame-000.png" | awk '/pixelWidth/ {print $2}')"
(( width >= WIDTH )) || fail "frames are ${width}px wide; render them with --animation-size 1920x1248"

rm -rf "$OUT"
mkdir -p "$OUT"
for i in $(seq -f '%03g' 0 "$LAST"); do
  ffmpeg -loglevel error -y -i "$SRC/frame-$i.png" -vf "scale=$WIDTH:-2" -q:v "$QUALITY" "$OUT/f-$i.jpg"
done
count="$(ls "$OUT" | wc -l | tr -d ' ')"
(( count == LAST + 1 )) || fail "expected $((LAST + 1)) frames, wrote $count"
printf 'Wrote %s frames to %s (%s)\n' "$count" "$OUT" "$(du -sh "$OUT" | cut -f1)"
