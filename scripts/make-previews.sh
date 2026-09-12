#!/bin/bash
# Turn the render check's exported animation frames into the website/README media:
#   docs/assets/<effect>.mp4, <effect>.gif (README), <effect>.jpg (poster), effects-preview.gif (Duo)
# Run after: MacbookDuo --render-check validation --animation
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:-validation/animation}"
command -v ffmpeg >/dev/null || { echo "ffmpeg is required (brew install ffmpeg)" >&2; exit 1; }
for dir in "$SRC"/*/; do
  id="$(basename "$dir")"
  [[ -f "$dir/frame-000.png" ]] || continue
  ffmpeg -loglevel error -y -framerate 60 -i "$dir/frame-%03d.png" -vf "scale=960:-2,format=yuv420p" -c:v libx264 -crf 22 -movflags +faststart "docs/assets/$id.mp4"
  ffmpeg -loglevel error -y -framerate 60 -i "$dir/frame-%03d.png" -vf "fps=15,scale=480:-2:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" -loop 0 "docs/assets/$id.gif"
  ffmpeg -loglevel error -y -i "$dir/frame-060.png" -vf "scale=960:-2" -q:v 4 "docs/assets/$id.jpg"
  printf 'Wrote docs/assets/%s.{mp4,gif,jpg}\n' "$id"
done
[[ -f docs/assets/duo.gif ]] && cp docs/assets/duo.gif docs/assets/effects-preview.gif
