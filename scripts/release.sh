#!/bin/bash
# Build, package and publish a GitHub release whose asset names match the in-app updater.
# Usage: scripts/release.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: scripts/release.sh <version>}"
./build.sh
MACBOOKDUO_ARCH=x86_64 MACBOOKDUO_BUILD_DIR=.build-intel ./build.sh || printf 'Intel build skipped.\n' >&2
scripts/package.sh
ASSETS=(dist/DuoDisplay.dmg dist/DuoDisplay-mac.zip dist/DuoDisplay-SHA256SUMS.txt)
[[ -f dist/DuoDisplay-Intel.dmg ]] && ASSETS+=(dist/DuoDisplay-Intel.dmg dist/DuoDisplay-Intel.zip)
gh release create "v$VERSION" "${ASSETS[@]}" --title "DuoDisplay $VERSION" --notes-file CHANGELOG.md --latest
