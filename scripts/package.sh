#!/bin/bash
# Package the built app into the release artifacts the in-app updater expects:
#   dist/DuoDisplay.dmg, dist/DuoDisplay-mac.zip (Apple silicon)
#   dist/DuoDisplay-Intel.dmg, dist/DuoDisplay-Intel.zip (Intel, when built)
#   dist/DuoDisplay-SHA256SUMS.txt
set -euo pipefail
cd "$(dirname "$0")/.."
DIST="${MACBOOKDUO_DIST_DIR:-dist}"
mkdir -p "$DIST"
rm -f "$DIST"/DuoDisplay*.dmg "$DIST"/DuoDisplay*.zip "$DIST"/DuoDisplay-SHA256SUMS.txt

package() {
  local app_dir="$1" suffix="$2"
  # The updater downloads DuoDisplay-mac.zip on Apple silicon and DuoDisplay-Intel.zip on Intel,
  # while the DMGs are DuoDisplay.dmg and DuoDisplay-Intel.dmg.
  local zip_suffix="${suffix:--mac}"
  local app="$app_dir/DuoDisplay.app"
  [[ -d "$app" ]] || { printf 'Skipping %s: %s not built.\n' "$suffix" "$app" >&2; return 0; }
  local stage; stage="$(mktemp -d)"
  ditto "$app" "$stage/DuoDisplay.app"
  printf 'Drag "DuoDisplay.app" into Applications, then open it from there.\nFirst launch: System Settings → Privacy & Security → Open Anyway.\n' > "$stage/INSTALL.txt"
  # The updater validates archive entries: only INSTALL.txt and DuoDisplay.app/... are accepted.
  (cd "$stage" && zip -q -r -X "$OLDPWD/$DIST/DuoDisplay${zip_suffix}.zip" "DuoDisplay.app" INSTALL.txt)
  local dmg_root; dmg_root="$(mktemp -d)"
  ditto "$app" "$dmg_root/DuoDisplay.app"
  ln -s /Applications "$dmg_root/Applications"
  hdiutil create -quiet -volname "DuoDisplay" -srcfolder "$dmg_root" -ov -format UDZO "$DIST/DuoDisplay${suffix}.dmg"
  rm -rf "$stage" "$dmg_root"
  printf 'Packaged %s\n' "$DIST/DuoDisplay${suffix}.dmg"
}

package build ""
package build-intel "-Intel"
(cd "$DIST" && shasum -a 256 DuoDisplay*.zip > DuoDisplay-SHA256SUMS.txt && cat DuoDisplay-SHA256SUMS.txt)
