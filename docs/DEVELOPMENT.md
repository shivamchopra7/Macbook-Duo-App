# Developing Macbook Duo

This guide covers building, signing, packaging, releasing and verifying Macbook Duo 1.0.0, the source layout, how to add an effect, and localization. For user-facing documentation see the [README](../README.md); for contribution ground rules see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Build

Use **Xcode 16 or newer / Swift 6** on a Mac. The app targets **macOS 13 Ventura or newer** on Apple silicon and Intel; a newer build SDK does not raise the deployment target. Automatic following needs a MacBook with a continuous lid-angle sensor, but the app builds, tests and runs its offscreen checks on any Mac.

```sh
git clone https://github.com/shivamchopra7/Macbook-Duo-App.git
cd Macbook-Duo-App
./build.sh
open "build/Macbook Duo.app"
```

`build.sh` runs `swift build -c release`, strips debug symbols so local build paths do not ship in the executable, copies the localized resource bundle, icon and menu-bar mark into `build/Macbook Duo.app`, writes `Info.plist` (bundle identifier `com.shivamchopra.macbookduo`, version 1.0.0, build 100), signs the bundle and verifies the signature.

## Signing

The default build is ad-hoc signed. An ad-hoc signature changes with every executable, so macOS may ask for Screen Recording permission again after a rebuild. For a stable identity across builds, provide an Apple Development certificate:

```sh
MACBOOKDUO_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" ./build.sh
```

You can also store the identity in a local `signing-identity.txt`, which Git ignores. Keep using the same identity for updates. No certificate, private key or signing identity is included in this repository, and public downloads are ad-hoc signed and not notarized. Check the final DMG and ZIP contents before uploading a release.

## Intel build

The default output is a native ARM64 app. Build the separately packaged Intel app explicitly:

```sh
./build.sh
MACBOOKDUO_ARCH=x86_64 MACBOOKDUO_BUILD_DIR=.build-intel ./build.sh
```

The commands write to `build/Macbook Duo.app` and `build-intel/Macbook Duo.app`, so one build cannot overwrite the other. Set `MACBOOKDUO_OUTPUT_DIR` only when you need a different destination. Do not combine the slices for distribution; both are native builds and neither needs Rosetta. The Intel build is a preview: it compiles and packages, but physical Intel verification is still pending.

## Packaging and releases

```sh
scripts/package.sh
```

`package.sh` packages whatever has been built into `dist/`: `Macbook-Duo.dmg` and `Macbook-Duo-mac.zip` for Apple silicon, `Macbook-Duo-Intel.dmg` and `Macbook-Duo-Intel.zip` when the Intel build exists, and `Macbook-Duo-SHA256SUMS.txt` covering the ZIPs. The ZIPs contain only `Macbook Duo.app` and `INSTALL.txt`, because the in-app updater rejects any other entry. Set `MACBOOKDUO_DIST_DIR` to package elsewhere.

```sh
scripts/release.sh 1.0.0
```

`release.sh <version>` builds both architectures, runs `package.sh`, then creates the GitHub release `v<version>` with `gh release create`, attaching the assets under the exact names the updater expects and using `CHANGELOG.md` as the notes. Keep those asset names stable: `AppUpdater` selects `Macbook-Duo-mac.zip` on ARM64 and `Macbook-Duo-Intel.zip` on x86_64 and validates both against `Macbook-Duo-SHA256SUMS.txt`. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `build.sh`, the `version` field in `RenderCheck.swift`, and the changelog before tagging.

## Icon

The app icon and the menu-bar template mark are rendered from code so the brand assets are reproducible:

```sh
swift scripts/make-icon.swift
```

This writes `Resources/MacbookDuo.icns`, `Resources/MacbookDuoIcon.png` (1024 px) and `Resources/MacbookDuoMark.png` (176 px template) and is the only way the brand assets should change. Pass a directory argument to write elsewhere.

## Verify

```sh
swift test
swift build
.build/debug/MacbookDuo --render-check validation
```

The render check uses generated artwork only and never captures the desktop. For every effect it verifies pixel identity when open and reopened, black closure, opacity, blur, practical geometry, distinct intermediate frames, smooth onset, Reduce Motion, cache freshness, low-resting-angle behaviour and GPU timing, then runs the effect's own detail check and writes `render-check.json` plus reference PNGs into the output directory.

| Flag | Effect |
|---|---|
| `--render-check <dir>` | Output directory for the report and images. |
| `--effects duo,fold` | Limit the per-effect loops to the listed identifiers, so one shader can be validated alone. |
| `--animation` | Export 180 closing and reopening frames per effect into `<dir>/animation/<effect>/`. |
| `--no-timing` | Record GPU times without enforcing the 6 ms budget, for parallel development runs. |
| `--strict-timing` | Enforce the budget on the best p95 as well as the best-of-three median. |

GPU measurements exclude capture and display composition; do not infer a frame-rate or battery-life guarantee from them.

The remaining diagnostics exercise the real app and the updater:

```sh
# Full-screen overlay with a synthetic frame on the built-in display; Esc stops it.
"build/Macbook Duo.app/Contents/MacOS/MacbookDuo" --overlay-check validation-overlay

# Ask GitHub for a newer stable release (network, user-initiated).
.build/debug/MacbookDuo --update-check

# Checksum, bounded extraction, bundle identity, version, macOS, architecture and signature of a package.
.build/debug/MacbookDuo --update-package-check dist/Macbook-Duo-mac.zip dist/Macbook-Duo-SHA256SUMS.txt 1.0.0 validation-update

# LaunchServices, ready handshake, replacement and failed-launch rollback with a local fixture.
.build/debug/MacbookDuo --update-installer-fixture validation-installer

# The helper handoff for an archive, manifest and version.
.build/debug/MacbookDuo --update-handoff-check dist/Macbook-Duo-mac.zip dist/Macbook-Duo-SHA256SUMS.txt 1.0.0
```

`--enable` starts following one second after launch, which is handy when scripting a physical lid sweep. Physical lid sweeps, sustained energy use and platform lifecycle transitions still need testing on more hardware.

## Source layout

```
Package.swift             SwiftPM manifest: FoldCore library, MacbookDuo app, two test targets
build.sh                  Builds, strips, bundles and signs "Macbook Duo.app"
scripts/                  package.sh (DMG, ZIP, checksums), release.sh (GitHub release), make-icon.swift (brand assets)
Resources/                App icon (.icns, .png) and the menu-bar template mark
Sources/FoldCore/         Platform-independent core with no AppKit or Metal dependency
  Effects/                FoldEffect catalog (ids, shader indices, titles, summaries) and EffectOptions with FoldCurve
  Motion/                 Fold math, the visual animation clock, lid motion reference and stillness detection
  Updates/                Release lookup, version parsing, archive validation and the update handoff contract
Sources/MacbookDuo/       The menu-bar app
  App/                    main.swift entry point and diagnostic flags, AppDelegate, brand images, L10n helper
  Model/                  AppModel state, overlay lifecycle, input handling, system integration, appearance
  Capture/                ScreenCaptureKit desktop capture and the bounded frame store
  Sensor/                 Lid-angle HID reader, off the main thread
  Rendering/              Metal renderer, pipelines, uniforms and generated preview artwork
  Rendering/Shaders/      FoldShader assembly, ShaderCommon header and dispatch, one Shader<Name>.swift per effect
  UI/                     Settings window, controls and live preview in the Liquid Glass design language
  Updates/                In-app updater: download, installation, relaunch and diagnostics
  Diagnostics/            RenderCheck and one RenderCheck+<Name>.swift detail check per effect
  Resources/              en, zh-Hans, zh-Hant and ja .lproj string tables
Tests/FoldCoreTests/      Unit tests for effects, options, motion, pacing and updates
Tests/LocalizationTests/  Key coverage and format-placeholder checks across all languages
docs/                     GitHub Pages site (index.html, style.css, assets/) and this guide
```

Every file stays under 400 lines; split a file rather than growing it past that.

## Adding an effect

1. **Catalog.** Add a case to `FoldEffect` in `Sources/FoldCore/Effects/FoldEffect.swift` with the next unused `shaderIndex` (12 for the thirteenth effect), a title, an SF Symbol and a one-sentence summary. Set `usesSegments` if the effect divides the display. Never renumber existing cases or indices; saved preferences and the shader switch depend on them.
2. **Shader.** Create `Sources/MacbookDuo/Rendering/Shaders/Shader<Name>.swift` with a Metal function `fold<Name>(float2 uv, texture2d<float> desktop, texture2d<float> pyramid, sampler s, constant Uniforms& u, float p)` that maps each output pixel back into the desktop image, reads `u.intensity` and `u.segments` where relevant, and returns opaque black at `p == 1`. Add the function to the `FoldShader.source` array in `FoldShader.swift` before `ShaderCommon.dispatch`, then extend the index range and the `if` chain in `ShaderCommon.dispatch` so the new index reaches it.
3. **Render check.** Add `Sources/MacbookDuo/Diagnostics/RenderCheck+<Name>.swift` with a `check<Name>(_ device:, _ renderer:, _ plate:, _ W:, _ H:)` function that asserts the effect's own geometry and optics, and register it in the `detail` list in `RenderCheck+Effects.swift`.
4. **Strings.** Add the title and summary to `Localizable.strings` in all four `.lproj` folders; `swift test` fails on a missing key.
5. **Tests and docs.** Extend `FoldEffectTests`, run `swift test` and `--render-check validation --effects <id>`, then add `docs/assets/<id>.gif`, `<id>.mp4` and `<id>.jpg`, a card in `docs/index.html` and a row in the README table.

## Localization

User-facing text lives in `Sources/MacbookDuo/Resources/{en,zh-Hans,zh-Hant,ja}.lproj`. English source strings are the keys. `L10n` explicitly loads the packaged resource bundle inside an app and falls back to `Bundle.main` during SwiftPM development so an absolute build path is not linked into release executables. Both SwiftUI and AppKit use the same lookup; missing keys fall back to English. Effect persistence identifiers remain unchanged.

To add a language, copy the English `Localizable.strings` and `InfoPlist.strings` into a new `.lproj` folder, translate the values while preserving format placeholders, and add the language to `CFBundleLocalizations` in `build.sh` and the localization test language list. The packaging script copies the SwiftPM bundle and the localized privacy descriptions into the app before signing.

Run `swift test` for key coverage and format-placeholder checks, and `./build.sh` for release packaging and signature verification. For a language smoke test, quit the app and launch it with a temporary process-only language override:

```sh
open -n "build/Macbook Duo.app" --args -AppleLanguages '("ja")'
```

Repeat for `en`, `zh-Hans`, and `zh-Hant`; check the settings, effect and appearance menus, tooltips, and status messages. Also test an unsupported language such as `fr` for English fallback. Do not enable desktop capture just to verify translations. Check a copy of the packaged app outside the checkout with the build resource bundle temporarily unavailable to verify that it is self-contained.

## Privacy and implementation

ScreenCaptureKit excludes this app from its own capture. Audio capture is disabled. Desktop frames remain in bounded memory; they are not saved, uploaded or analyzed. The live effect uses no network service, account, analytics or third-party runtime dependency. User-initiated update checks and downloads contact GitHub; they never include desktop frames.

The HID reader runs off the main thread. A Metal fragment shader and reusable blur pyramid render the effect. Reduce Motion uses a simple fade. Capture stops when the effect clears, and sensor/capture failures restore the desktop.

macOS owns sleep and the secure login screen. Animation cannot be guaranteed while the display is asleep, during login or with protected content. Capture may take a moment to warm up; the desktop and live preview remain clear until a fresh frame is ready.

Update checks and downloads use HTTPS to GitHub. SHA-256 detects corrupt or mismatched downloads; an ad-hoc code signature does not prove publisher identity. Trust still depends on the official repository and GitHub HTTPS. A writable installation folder is required; the updater does not request administrator access or bypass Gatekeeper, and a recovery dialog keeps the verified candidate and the previous app safe if a relaunch is blocked.

## Contributing

Issues and focused pull requests are welcome. Include macOS version, Mac model, whether its lid sensor is detected, reproduction steps and relevant test results. Do not attach private desktop recordings or signing credentials. Run the checks above for renderer or motion changes. Keep the app dependency-free and respect Reduce Motion and existing power limits. See [CONTRIBUTING.md](../CONTRIBUTING.md) and, for third-party notices, [ATTRIBUTION.md](../ATTRIBUTION.md).
