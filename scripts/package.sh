#!/bin/bash
# Package the built app into the release artifacts the in-app updater expects:
#   dist/Macbook-Duo.dmg, dist/Macbook-Duo-mac.zip (Apple silicon)
#   dist/Macbook-Duo-Intel.dmg, dist/Macbook-Duo-Intel.zip (Intel, when built)
#   dist/Macbook-Duo-SHA256SUMS.txt
set -euo pipefail
cd "$(dirname "$0")/.."
DIST="${MACBOOKDUO_DIST_DIR:-dist}"
mkdir -p "$DIST"
rm -f "$DIST"/Macbook-Duo*.dmg "$DIST"/Macbook-Duo*.zip "$DIST"/Macbook-Duo-SHA256SUMS.txt

package() {
  local app_dir="$1" suffix="$2"
  # The updater downloads Macbook-Duo-mac.zip on Apple silicon and Macbook-Duo-Intel.zip on Intel,
  # while the DMGs are Macbook-Duo.dmg and Macbook-Duo-Intel.dmg.
  local zip_suffix="${suffix:--mac}"
  local app="$app_dir/Macbook Duo.app"
  [[ -d "$app" ]] || { printf 'Skipping %s: %s not built.\n' "$suffix" "$app" >&2; return 0; }
  local stage; stage="$(mktemp -d)"
  ditto "$app" "$stage/Macbook Duo.app"
  printf 'Drag "Macbook Duo.app" into Applications, then open it from there.\nFirst launch: System Settings → Privacy & Security → Open Anyway.\n' > "$stage/INSTALL.txt"
  # The updater validates archive entries: only INSTALL.txt and Macbook Duo.app/... are accepted.
  (cd "$stage" && zip -q -r -X "$OLDPWD/$DIST/Macbook-Duo${zip_suffix}.zip" "Macbook Duo.app" INSTALL.txt)
  local dmg_root; dmg_root="$(mktemp -d)"
  ditto "$app" "$dmg_root/Macbook Duo.app"
  ln -s /Applications "$dmg_root/Applications"
  hdiutil create -quiet -volname "Macbook Duo" -srcfolder "$dmg_root" -ov -format UDZO "$DIST/Macbook-Duo${suffix}.dmg"
  rm -rf "$stage" "$dmg_root"
  printf 'Packaged %s\n' "$DIST/Macbook-Duo${suffix}.dmg"
}

package build ""
package build-intel "-Intel"
(cd "$DIST" && shasum -a 256 Macbook-Duo*.zip > Macbook-Duo-SHA256SUMS.txt && cat Macbook-Duo-SHA256SUMS.txt)
