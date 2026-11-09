#!/bin/bash
# Build, validate, then publish assets matching the website and in-app updater.
# Usage: scripts/release.sh 1.0.2 (after committing and pushing main)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:?usage: scripts/release.sh <version>}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Use a semantic version, e.g. 1.0.2" >&2; exit 2; }
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] || { echo "Commit release changes first." >&2; exit 1; }
COMMIT="$(git rev-parse HEAD)"
REMOTE_MAIN="$(git ls-remote origin refs/heads/main | cut -f1)"
[[ "$COMMIT" == "$REMOTE_MAIN" ]] || { echo "Push this exact commit to main before releasing." >&2; exit 1; }
REMOTE_TAG="$(git ls-remote origin "refs/tags/v$VERSION" "refs/tags/v$VERSION^{}")"
if [[ -n "$REMOTE_TAG" ]]; then
  TAG_COMMIT="$(printf '%s\n' "$REMOTE_TAG" | tail -1 | cut -f1)"
  [[ "$TAG_COMMIT" == "$COMMIT" ]] || { echo "Tag v$VERSION already points to a different commit." >&2; exit 1; }
fi
swift test
python3 scripts/test-release.py
./build.sh
MACBOOKDUO_ARCH=x86_64 MACBOOKDUO_BUILD_DIR=.build-intel ./build.sh
scripts/package.sh
python3 scripts/verify-release.py "$VERSION"
ASSETS=(dist/Foldbook.dmg dist/Foldbook-mac.zip dist/Foldbook-Intel.dmg dist/Foldbook-Intel.zip dist/Foldbook-SHA256SUMS.txt)
NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
# Publish only this version's notes, not the complete changelog.
awk -v heading="## $VERSION ·" '$0 ~ /^## / { if (found) exit; if (index($0, heading) == 1) { found=1; next } } found { print }' CHANGELOG.md > "$NOTES"
[[ -s "$NOTES" ]] || { echo "No changelog entry for $VERSION" >&2; exit 1; }
# Upload to a draft first; partial asset uploads must never become latest.
gh release create "v$VERSION" "${ASSETS[@]}" --repo shivamchopra7/Macbook-Duo-App \
  --draft --target "$COMMIT" --title "Foldbook $VERSION" --notes-file "$NOTES"
python3 scripts/verify-release.py "$VERSION" --draft
gh release edit "v$VERSION" --repo shivamchopra7/Macbook-Duo-App --draft=false --latest
python3 scripts/verify-release.py "$VERSION" --published
