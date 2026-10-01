#!/bin/bash
# Build, package and publish a GitHub release whose asset names match the in-app updater.
# Usage: scripts/release.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: scripts/release.sh <version>}"
./build.sh
MACBOOKDUO_ARCH=x86_64 MACBOOKDUO_BUILD_DIR=.build-intel ./build.sh || printf 'Intel build skipped.\n' >&2
scripts/package.sh
ASSETS=(dist/Foldbook.dmg dist/Foldbook-mac.zip dist/Foldbook-SHA256SUMS.txt)
[[ -f dist/Foldbook-Intel.dmg ]] && ASSETS+=(dist/Foldbook-Intel.dmg dist/Foldbook-Intel.zip)
gh release create "v$VERSION" "${ASSETS[@]}" --title "Foldbook $VERSION" --notes-file CHANGELOG.md --latest
