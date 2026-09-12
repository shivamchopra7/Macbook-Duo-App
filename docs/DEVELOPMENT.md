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

## Mac App Store

Macbook Duo ships in two flavours from the same sources. On the store it is sold as **Lid Fold**, because App Review Guideline 5.2.5 keeps Apple's product names out of App Store app names; `AppBrand.name` picks the name at compile time, and every user-facing string takes it as a `%@` argument.

| Flavour | Built by | Updates | Signing and runtime |
|---|---|---|---|
| Direct download | `./build.sh` (SwiftPM) | In-app updater against the GitHub release | Ad-hoc or Apple Development, not notarized, no sandbox |
| Mac App Store | `Macbook Duo.xcodeproj`, scheme `Macbook Duo` | The App Store; the updater is compiled out | Apple Distribution, App Sandbox, Hardened Runtime |

The Xcode project is generated from `project.yml` at the repository root with [xcodegen](https://github.com/yonaskolb/XcodeGen) (`xcodegen generate`; version 2.46 is known to work). It defines two targets: the static library `FoldCore` from `Sources/FoldCore` and the app `MacbookDuo`, which produces `Lid Fold.app` (`PRODUCT_NAME`, also the bundle and display name) with the executable `MacbookDuo` and the module `MacbookDuo`, bundle identifier `com.shivamchopra.macbookduo`, `App/Info.plist`, the entitlements in `App/MacbookDuo.entitlements`, the privacy manifest `App/PrivacyInfo.xcprivacy` and the asset catalog `Resources/Assets.xcassets` with its `AppIcon` set. The store target sets `SWIFT_ACTIVE_COMPILATION_CONDITIONS = APPSTORE`; the SwiftPM build does not define it and keeps the updater.

**What `APPSTORE` removes.** App Review Guideline 2.4.5 forbids apps that download or install code or replace themselves, so the store build must not contain the self-updater. Under `APPSTORE` the files in `Sources/MacbookDuo/Updates/` (`AppUpdater`, `UpdateDownload`, `UpdateJob` and `UpdateInstallation*`) are compiled out, together with the **Check for Updates…** menu item and `UpdateInstallation.confirmRelaunch()` in `AppDelegate.swift`, the `--update-*` diagnostic flags in `main.swift`, the update button in `SettingsHeader.swift` and the button in `AboutTab.swift`. The pure parsing code in `Sources/FoldCore/Updates` stays, because it has no side effects and its tests still run. Check the SwiftPM build under the same condition with `swift build -Xswiftc -DAPPSTORE --scratch-path .build-appstore` — give it its own scratch path, because sharing `.build` with the plain build leaves both `AppUpdater` variants’ object files behind and the next link fails on duplicate symbols; CI runs that and an unsigned `xcodebuild` of the store scheme on every push.

**Entitlements and why.** `com.apple.security.app-sandbox` is mandatory for the store. `com.apple.security.device.usb` is the one addition: the lid-angle sensor is a built-in IOKit HID device, and `IOHIDManagerOpen` fails under App Sandbox alone but succeeds with this standard entitlement, so no temporary-exception entitlement is needed. Verify on a supported MacBook with `"Macbook Duo.app/Contents/MacOS/MacbookDuo" --sensor-check`, which prints the lid angle or an explicit failure. ScreenCaptureKit, `SMAppService` login items, Carbon hot keys, `IOPSCopyPowerSourcesInfo` and runtime Metal shader compilation all work under App Sandbox and Hardened Runtime without further entitlements. The store build never touches the network, so it has no network entitlement.

**Privacy manifest.** `App/PrivacyInfo.xcprivacy` declares the two required-reason APIs the app uses, `ProcessInfo.systemUptime` (`NSPrivacyAccessedAPICategorySystemBootTime`, reason `35F9.1`) and `UserDefaults` (`NSPrivacyAccessedAPICategoryUserDefaults`, reason `CA92.1`), with `NSPrivacyTracking` false and no collected data types. Add an entry whenever a new required-reason API is introduced; App Store Connect rejects uploads that use one without declaring it.

**Team and signing.** Signing is automatic under the team `ZB6623U832` (ILLUSIONART AI PRIVATE LIMITED), set as `DEVELOPMENT_TEAM` in `project.yml`, which is where to change it for another account before regenerating the project; the same setting is visible under *Signing & Capabilities* in Xcode. An *Apple Distribution* certificate for the team must be in the login keychain for archiving, and the bundle identifier must match the App Store Connect record. Keep the marketing version in the Xcode project in step with `build.sh` and the changelog. The store build number (`CURRENT_PROJECT_VERSION` in `project.yml`) runs ahead of the direct download's: App Store Connect needs a strictly higher build number for every upload, so bump it before each archive.

**Archive and upload.** In Xcode open `Macbook Duo.xcodeproj`, select the `Macbook Duo` scheme with the *My Mac* destination and choose *Product → Archive*. In the Organizer choose *Distribute App → App Store Connect → Upload* (or *Export* to validate first). The same flow is scripted:

```sh
scripts/appstore.sh validate   # archive and validate against App Store Connect
scripts/appstore.sh export     # archive and export the signed app into build-appstore/
scripts/appstore.sh upload     # archive and upload the build
```

**App Store Connect checklist.**

1. Create the app record: platform macOS, name **Lid Fold**, primary language English, bundle identifier `com.shivamchopra.macbookduo`, any SKU.
2. Fill the listing from [docs/appstore/listing.md](appstore/listing.md): subtitle, promotional text, description, keywords, support and marketing URLs, categories (Utilities, Entertainment), copyright and the age-rating answers.
3. Generate the window screenshots with `scripts/appstore-screenshots.sh` (it needs the packaged app, `ffmpeg` and Screen Recording access for the terminal), then the two app previews and the five effect screenshots with `scripts/appstore-previews.sh` (it needs the render check's animation frames at `--animation-size 1920x1248`, rendered by the store flavour; the usage comment in the script has the exact commands). Upload the ten 2880×1800 PNGs from `docs/appstore/screenshots/` and the two 1920×1080 MP4s from `docs/appstore/previews/`. Regenerate them from the store build (the script finds `Lid Fold.app` under `build-appstore/` on its own, or set `MACBOOKDUO_APP`) so every page says Lid Fold and the About page shows no update button.
4. Answer App Privacy with **Data Not Collected** and enter the privacy policy URL `https://macbookduo.illusionart.ai/privacy.html`.
5. Select the uploaded build, paste the *Notes for App Review* section from the listing, answer the export-compliance question, and submit for review.

**Icon.** The store needs the full `AppIcon` set in `Resources/Assets.xcassets`. To replace the artwork with a 1024 px master instead of the generated brand icon, run `swift scripts/make-icon.swift Resources --from icon-1024.png`, which rewrites the `.icns`, the PNGs and the asset catalog together, then rebuild.

**TestFlight for macOS.** Every build uploaded to App Store Connect can be tested before review. Open the app's *TestFlight* tab, add internal testers (App Store Connect users, no review) or an external group (a short Beta App Review), and testers install the *TestFlight* app from the Mac App Store and redeem the invitation. TestFlight builds run with the same sandbox, entitlements and signing as the store build, so use them to confirm the lid sensor, the Screen Recording prompt and Open at login on real hardware; builds expire after 90 days, and a build cannot be tested until its export-compliance answer is recorded.

## Icon

The shipped artwork is `Resources/AppIconSource.png` (1024×1024). `scripts/make-icon.swift` fits it into Apple's macOS icon shape — an 824-point rounded square centred on the 1024 canvas with the system-style shadow — and writes `Resources/MacbookDuo.icns` (direct-download build), `Resources/MacbookDuoIcon.png` (README, website) and `Resources/Assets.xcassets/AppIcon.appiconset` (App Store build). The menu-bar mark is always drawn from code.

```sh
swift scripts/make-icon.swift Resources --from Resources/AppIconSource.png
```

Add `--full-bleed` to skip the rounded-square fit for artwork that already includes its own shape and margins. Without `--from`, the script draws its built-in placeholder artwork instead.

## Verify

```sh
swift test
swift build
.build/debug/MacbookDuo --render-check validation
```

`scripts/verify.sh` chains everything below in one run: the unit tests, the render check for all twelve effects with animation export, the live overlay sandbox (`--overlay-check`, which shows generated artwork on the built-in display for about twenty seconds without Screen Recording access), the release build and packaging, and finally the updater's own `--update-package-check` and `--update-installer-fixture` against the freshly packaged `dist/` artifacts. Pass `--strict-timing` through to it on a quiet machine. After a run, `scripts/make-previews.sh` turns the exported `animation/<effect>/` frames (under `validation/render/` after `verify.sh`) into the `docs/assets/<effect>.{mp4,gif,jpg}` media used by the website and README.

The render check uses generated artwork only and never captures the desktop. For every effect it verifies pixel identity when open and reopened, black closure, opacity, blur, practical geometry, distinct intermediate frames, smooth onset, Reduce Motion, cache freshness, low-resting-angle behaviour and GPU timing, then runs the effect's own detail check and writes `render-check.json` plus reference PNGs into the output directory.

| Flag | Effect |
|---|---|
| `--render-check <dir>` | Output directory for the report and images. |
| `--effects duo,fold` | Limit the per-effect loops to the listed identifiers, so one shader can be validated alone. |
| `--animation` | Export 180 closing and reopening frames per effect into `<dir>/animation/<effect>/`. |
| `--no-timing` | Record GPU times without gating them, for parallel development runs. |
| `--strict-timing` | Enforce the absolute 6 ms budget on the best-of-three median and p95. Without it, every effect is gated at 2.5× the Duo median of the same run (Duo itself at a 12 ms sanity limit), because GPU time on a shared desktop includes other processes' work. |

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
scripts/                  package.sh (DMG, ZIP, checksums), release.sh (GitHub release), make-icon.swift (brand assets),
                          appstore.sh (validate, export, upload), appstore-screenshots.sh (window screenshots), appstore-previews.sh (app previews, effect screenshots) and make-scroll-frames.sh (the website's scroll-to-close Shutter frames)
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
docs/                     GitHub Pages site (index.html, privacy.html, style.css, assets/), this guide,
                          and appstore/ with the App Store Connect listing copy and screenshots
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
