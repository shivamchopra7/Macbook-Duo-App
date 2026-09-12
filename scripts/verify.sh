#!/bin/bash
# Full local verification without Screen Recording access:
#   1. unit tests            2. GPU render check for every effect (+ animation frames)
#   3. live overlay sandbox  4. release packaging
#   5. the updater's package check and installer fixture against those artifacts
# Usage: scripts/verify.sh [extra --render-check flags, e.g. --strict-timing]
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${MACBOOKDUO_VERIFY_DIR:-validation}"
rm -rf "$OUT"; mkdir -p "$OUT"
step() { printf '\n== %s\n' "$1"; }

step "Unit tests"
swift test 2>&1 | grep -E "error:|failed|Test run|Executed" | tail -4

step "Debug build"
swift build 2>&1 | tail -1
BIN="$(swift build --show-bin-path)"

step "GPU render check (all effects)"
"$BIN/MacbookDuo" --render-check "$OUT/render" --animation "$@" > "$OUT/render-check.json"
python3 - "$OUT/render-check.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
print("gpu:", r["gpu"], "| native median ms:", round(r["nativeGPUTimeMedianMS"], 2), "| p95 ms:", round(r["nativeGPUTimeP95MS"], 2))
print("effects:", ", ".join(e["id"] for e in r["effectCatalog"]))
print("smallest pairwise separation:", round(r["effectChecks"]["smallestIntermediateSeparation"], 2))
for k, v in sorted(r["effectNativeGPUTimes"].items()):
    print(f"  {k:10s} median {v['medianMS']:.2f} ms  p95 {v['p95MS']:.2f} ms")
PY

step "Live overlay sandbox (generated artwork on the built-in display, ~20 s; Esc stops it)"
"$BIN/MacbookDuo" --overlay-check "$OUT/overlay.json" &
APP=$!
for _ in $(seq 1 60); do [[ -s "$OUT/overlay.json" ]] && break; sleep 1; done
kill "$APP" 2>/dev/null || true; wait "$APP" 2>/dev/null || true
[[ -s "$OUT/overlay.json" ]] || { echo "Overlay check produced no report." >&2; exit 1; }
cat "$OUT/overlay.json"

step "Release build and packaging"
./build.sh | tail -2
scripts/package.sh

step "Updater package check against dist/"
"$BIN/MacbookDuo" --update-package-check dist/Macbook-Duo-mac.zip dist/Macbook-Duo-SHA256SUMS.txt \
  "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "build/Macbook Duo.app/Contents/Info.plist")" "$OUT/package-check"

step "Updater installer fixture (disposable apps, LaunchServices handshake, rollback)"
FIXTURE="$(mktemp -d)/MacbookDuo-update-fixture-$$"
"$BIN/MacbookDuo" --update-installer-fixture "$FIXTURE"
cat "$FIXTURE/result.json"; rm -rf "$(dirname "$FIXTURE")"

printf '\nAll checks passed. Reports in %s/, artifacts in dist/.\n' "$OUT"
