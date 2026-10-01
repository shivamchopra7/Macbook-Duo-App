#!/bin/bash
# Package the built app into the release artifacts the in-app updater expects:
#   dist/Foldbook.dmg, dist/Foldbook-mac.zip (Apple silicon)
#   dist/Foldbook-Intel.dmg, dist/Foldbook-Intel.zip (Intel, when built)
#   dist/Foldbook-SHA256SUMS.txt
set -euo pipefail
cd "$(dirname "$0")/.."
DIST="${MACBOOKDUO_DIST_DIR:-dist}"
mkdir -p "$DIST"
rm -f "$DIST"/Foldbook*.dmg "$DIST"/Foldbook*.zip "$DIST"/Foldbook-SHA256SUMS.txt

package() {
  local app_dir="$1" suffix="$2"
  # The updater downloads Foldbook-mac.zip on Apple silicon and Foldbook-Intel.zip on Intel,
  # while the DMGs are Foldbook.dmg and Foldbook-Intel.dmg.
  local zip_suffix="${suffix:--mac}"
  local app="$app_dir/Foldbook.app"
  [[ -d "$app" ]] || { printf 'Skipping %s: %s not built.\n' "$suffix" "$app" >&2; return 0; }
  local stage; stage="$(mktemp -d)"
  ditto "$app" "$stage/Foldbook.app"
  printf 'Drag "Foldbook.app" into Applications, then open it from there.\nFirst launch: System Settings → Privacy & Security → Open Anyway.\n' > "$stage/INSTALL.txt"
  # The updater validates archive entries: only INSTALL.txt and Foldbook.app/... are accepted.
  (cd "$stage" && zip -q -r -X "$OLDPWD/$DIST/Foldbook${zip_suffix}.zip" "Foldbook.app" INSTALL.txt)
  local dmg_root; dmg_root="$(mktemp -d)"
  ditto "$app" "$dmg_root/Foldbook.app"
  ln -s /Applications "$dmg_root/Applications"
  hdiutil create -quiet -volname "Foldbook" -srcfolder "$dmg_root" -ov -format UDZO "$DIST/Foldbook${suffix}.dmg"
  rm -rf "$stage" "$dmg_root"
  printf 'Packaged %s\n' "$DIST/Foldbook${suffix}.dmg"
}

package build ""
package build-intel "-Intel"
(cd "$DIST" && shasum -a 256 Foldbook*.zip > Foldbook-SHA256SUMS.txt && cat Foldbook-SHA256SUMS.txt)
