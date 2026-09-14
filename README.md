<img src="Resources/MacbookDuoIcon.png" alt="Macbook Duo icon" width="96" align="right">

# Macbook Duo

**Your desktop follows your lid.** Apple just built a $1,999 phone that folds. Your MacBook has folded since day one; it simply never made a thing of it. Macbook Duo makes a thing of it: a native Swift + Metal menu-bar app that folds, rolls, swirls or drains your desktop away as you close the lid, with twelve effects to choose from. Open the lid and everything snaps back into focus.

Works on MacBook. Only MacBook. (See [Compatibility](#compatibility) before you get excited on an iMac.)

[![Release](https://img.shields.io/github/v/release/shivamchopra7/Macbook-Duo-App?color=2F6BFF&label=release)](https://github.com/shivamchopra7/Macbook-Duo-App/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-333333)](#compatibility)
[![MIT](https://img.shields.io/badge/license-MIT-2F6BFF)](LICENSE)

## Download

| Build | Link |
|---|---|
| Apple silicon (recommended) | [**Macbook-Duo.dmg**](https://github.com/shivamchopra7/Macbook-Duo-App/releases/latest/download/Macbook-Duo.dmg) |
| Intel preview | [**Macbook-Duo-Intel.dmg**](https://github.com/shivamchopra7/Macbook-Duo-App/releases/latest/download/Macbook-Duo-Intel.dmg) |
| Everything else (ZIPs, checksums, older versions) | [All releases](https://github.com/shivamchopra7/Macbook-Duo-App/releases) |

**Mac App Store:** the same app is coming to the Mac App Store as **Macbook Fold**, a sandboxed build with no in-app updater; until it is live, use the direct download above.

Version 1.0.0 · [Website](https://macbookduo.illusionart.ai/) · [Changelog](CHANGELOG.md) · [Build from source](#build-from-source) · [Report an issue](https://github.com/shivamchopra7/Macbook-Duo-App/issues)

<p align="center"><img src="docs/assets/window-effects.png" alt="The Macbook Duo settings window on the Effects section, with the live MacBook-shaped preview on the left and the twelve effects on the right" width="800"></p>

## What it does

Macbook Duo reads the lid-angle sensor built into recent MacBooks, captures the desktop with ScreenCaptureKit and renders a Metal effect on a full-screen overlay. As the lid tilts, the desktop bends, folds, rolls or drains away in real time; open it again and everything returns to pixel-exact focus. Hold the lid still at any angle and the screen clears after a short pause, so you can keep working at 70° like a person with a plan.

- Twelve effects, each with its own feel and its own tuning.
- A settings window in a Liquid Glass design language with four sections: **Effects**, **Motion**, **Look** and **About**, plus a live MacBook-shaped preview.
- Light, dark or system appearance.
- Menu-bar access, an opt-in **Open at login** setting (launches start paused), and a menu-bar icon that can be hidden.
- Press **Esc** or **⌃⌥⌘F** anywhere to pause.
- Native Swift + Metal with no third-party runtime dependencies, accounts or analytics.

## Macbook Duo vs iPhone Duo

In September 2026 Apple unveiled the [iPhone Duo](https://www.apple.com/iphone-duo/): a book-style foldable with a 7.6-inch inner display, a titanium hinge with more than a hundred parts, and a nano-texture layer so you can feel the crease but not see it. Close it and the inner screen fades while your apps hop to the outer display. Lovely. We would like to point out that your MacBook has had a hinge, a lid and a fade-to-black this whole time, and that only one of these Duos does something interesting on the way down.

| | iPhone Duo | Macbook Duo |
|---|---|---|
| Folds | Yes. Like a book, 7.6 inches wide open. | Yes. Like a laptop, up to 16 inches wide open. |
| When you close it | The inner screen fades and your apps hop to the outer display. | Your desktop folds, rolls, swirls, shutters, drapes or drains into a black hole. Twelve options. A plain fade is not one of them; we have standards. |
| The hinge | Grade 5 titanium, more than 100 components, a 3D-printed cover. | Whatever Apple already screwed into your MacBook. We just ask it for the angle, sixty times a second. |
| The crease | Nano-texture, so you can feel it but not see it. | Drawn on purpose, in Metal. See: Fold. |
| Angles it understands | Open, closed, and a few poses in between. | Every degree from wide open to shut, in real time, in both directions. |
| Price | From $1,999. | $0. MIT licensed. Tips accepted in GitHub stars. |
| Availability | Pre-orders October 16, 2026. Ships October 23. | Now. Download, drag, open. |
| Cameras | Two 48-megapixel cameras, plus one hiding under the screen. | None. Your desktop is captured into memory for the effect and never leaves the Mac. |
| Works on the iPhone Duo | Yes, obviously. | No. MacBook only. We tried to be clear about this. |

iPhone Duo details are from Apple's September 2026 announcement. iPhone Duo is Apple's product; Macbook Duo is independent software, neither affiliated with nor endorsed by Apple. We just really like hinges.

## Twelve effects

Duo is the default. Fold, Accordion, Louver, Card, Curtain and Blackhole were added in 1.0.0. The iPhone Duo has one closing animation. We have twelve, and none of them is a fade. Fine: Ghost is a fade. A tasteful one.

| Effect | What it feels like |
|---|---|
| **Duo** · default | The desktop swells around the hinge as the lid closes. |
| **Ghost** | The desktop holds its resting plane as the lid tilts and gently falls out of focus. |
| **Roll** | The desktop curls into a roll that travels down to the hinge. |
| **Shutter** | Rigid panels telescope behind each other into the hinge. |
| **Flex** | One bowing flexible display collapses toward the hinge. |
| **Iris** | Eight overlapping blades close an aperture above the hinge. |
| **Fold** | The display creases across the middle and the top half folds down over the bottom. |
| **Accordion** | Pleats zig-zag and gather toward the hinge like a paper fan. |
| **Louver** | Horizontal slats tilt and overlap like closing window blinds. |
| **Card** | The whole desktop tips back as one rigid card in perspective. |
| **Curtain** | Drapes draw together from both sides and settle at the hinge. |
| **Blackhole** | The desktop swirls into a black hole opening at the hinge. |

Shutter, Accordion, Louver and Curtain divide the display into a configurable number of segments.

| Duo | Ghost | Roll | Shutter |
|---|---|---|---|
| ![Duo effect preview](docs/assets/duo.gif) | ![Ghost effect preview](docs/assets/ghost.gif) | ![Roll effect preview](docs/assets/roll.gif) | ![Shutter effect preview](docs/assets/shutter.gif) |

| Flex | Iris | Fold | Accordion |
|---|---|---|---|
| ![Flex effect preview](docs/assets/flex.gif) | ![Iris effect preview](docs/assets/iris.gif) | ![Fold effect preview](docs/assets/fold.gif) | ![Accordion effect preview](docs/assets/accordion.gif) |

| Louver | Card | Curtain | Blackhole |
|---|---|---|---|
| ![Louver effect preview](docs/assets/louver.gif) | ![Card effect preview](docs/assets/card.gif) | ![Curtain effect preview](docs/assets/curtain.gif) | ![Blackhole effect preview](docs/assets/blackhole.gif) |

Previews show the app's bundled wallpaper, not a real desktop. Your real desktop never leaves your Mac.

## Options

Every control lives in the settings window. **Reset to defaults** restores the original tuning in one click.

<p align="center"><img src="docs/assets/window-motion.png" alt="The Macbook Duo settings window on the Motion section, showing the lid-tracking and timing controls" width="800"></p>

| Control | Range | Default | Notes |
|---|---|---|---|
| Effect | Duo, Ghost, Roll, Shutter, Flex, Iris, Fold, Accordion, Louver, Card, Curtain, Blackhole | Duo | Persisted across launches. |
| Intensity | 0–100% | 50% | Exaggerates each effect's geometry. 50% reproduces the original tuning. |
| Segments | 2–8 | 4 | Panel, pleat, slat or drape count for Shutter, Accordion, Louver and Curtain. |
| Curve | Smooth, Gentle, Linear, Brisk | Smooth | How fold progress advances between open and closed. Smooth eases in and out; Gentle starts slowly; Linear tracks the lid one-to-one; Brisk responds immediately, then settles. |
| Response | 20–120 ms | 45 ms | Time constant of the motion smoothing while the lid moves. |
| Clear duration | 0.3–1.2 s | 0.6 s | Length of the animation back to a clear desktop. |
| Perspective | 0–100% | 70% | Depth of the hinge-anchored projection. |
| Softness | 0–100% | 65% | Progressive defocus as the lid closes. |
| Shadow | 0–100% | 65% | Contact and hinge shadows. |
| Clears at | 60°–140° | 105° | The lid angle at which the effect is fully clear. |
| Clear when the lid is still | On / Off | On | Clears the effect after the lid rests. |
| Clear after | 1–5 s | 2 s | How long the lid must rest before clearing. Move the lid to bring the effect back. |
| Follow my lid | On / Off | On | Turn off for manual control of the preview. |
| Preview angle | 5°–140° | 72° | Drives the preview when Follow my lid is off. |
| Appearance | Light, Dark, System | System | Applies to the settings window. |

## Install

1. Download [**Macbook-Duo.dmg**](https://github.com/shivamchopra7/Macbook-Duo-App/releases/latest/download/Macbook-Duo.dmg) for Apple silicon (or [**Macbook-Duo-Intel.dmg**](https://github.com/shivamchopra7/Macbook-Duo-App/releases/latest/download/Macbook-Duo-Intel.dmg) for Intel), open it and drag **Macbook Duo** into **Applications**.
2. Open **Macbook Duo** from Applications. The app is ad-hoc signed and **not notarized**, so macOS may first show "cannot be opened" or "Apple could not verify".
3. Go to **System Settings → Privacy & Security**, scroll to **Security**, click **Open Anyway** next to Macbook Duo, then confirm **Open**. See [Apple's instructions](https://support.apple.com/102445).
4. Press **Replay** to watch the effect on the built-in preview. Replay works without any permission.
5. Click **Enable Macbook Duo** and allow **Screen Recording** when prompted. Reopen the app if macOS asks. Desktop frames stay in memory; nothing is recorded or uploaded.

For manual control, turn off **Follow my lid** and drag **Preview angle**. Keep **Clear when the lid is still** on for everyday use at any angle. Prefer a ZIP? Unzip it, move **Macbook Duo.app** into Applications and follow steps 2–5.

## Updating

This applies to the direct download. The Mac App Store build updates through the App Store and contains no in-app updater.

Choose **Check for Updates…** from the settings window or the menu bar, then **Install & Relaunch**. Macbook Duo reads the latest stable release from the official GitHub repository, picks the native Apple-silicon or Intel ZIP, verifies its SHA-256 checksum and bundle before replacing itself, and preserves your preferences. Checks run only when you ask; there is no background polling.

macOS may require **Privacy & Security → Open Anyway** for the updated app, and Screen Recording may need to be approved again because ad-hoc signatures change with each build. The recovery dialog lets you retry or restore the previous app. Install into a writable Applications folder. For a manual update, quit Macbook Duo before replacing the app. If Screen Recording appears enabled but capture fails, remove the old Macbook Duo entry from Screen Recording settings, add the current app from Applications and reopen it.

## Compatibility

Macbook Duo works on **MacBook only**. It requires **macOS 13 Ventura or newer** and a MacBook with a **continuous lid-angle sensor**: no sensor, no angle; no angle, no show. The app checks for the sensor at launch and says so plainly ("MacBook unsupported") instead of looking for it forever. Replay still shows every effect on the built-in preview, so unsupported Macs can at least window-shop.

| Status | Models |
|---|---|
| Supported | MacBook Air with M2 or newer; 14-inch and 16-inch MacBook Pro with M1 Pro/Max or newer |
| Intel preview | 2019 16-inch MacBook Pro. A native x86_64 build is provided, but physical Intel verification is still pending, so reports are welcome. |
| Unsupported | M1 MacBook Air; 13-inch MacBook Pro with M1 or M2; Intel models that expose only an open/closed clamshell switch. They know the lid moved; they refuse to say how far. |
| Also no, since you asked | iMac (no lid). Mac mini (no lid). Mac Studio (no lid, many ports). iPad (a cover is not a lid). iPhone Duo (has a hinge, wrong hinge). Your fridge (has a hinge, no macOS). |

The Apple-silicon build is native ARM64 and needs no Rosetta. External displays are not animated: the desktop on your MacBook's own screen is the star and everything else is the audience. Animation cannot be guaranteed while the display is asleep, during login or over protected content.

## Languages

English, Simplified Chinese, Traditional Chinese and Japanese. Macbook Duo follows your macOS language preferences, with English as the fallback. To choose a language just for Macbook Duo, add it under **System Settings → General → Language & Region → Applications**, then quit and reopen the app.

## Privacy

- Desktop frames stay in bounded memory on your Mac. They are never saved, uploaded or analyzed.
- ScreenCaptureKit excludes Macbook Duo's own windows from capture, and audio capture is disabled.
- No accounts, no analytics, no telemetry and no third-party runtime dependencies.
- The only network activity is a user-initiated update check against the official GitHub release, over HTTPS. The Mac App Store build has no network access at all.
- The full policy is published at [macbookduo.illusionart.ai/privacy.html](https://macbookduo.illusionart.ai/privacy.html) and versioned in [docs/privacy.html](docs/privacy.html).
- Public builds are ad-hoc signed and not notarized. SHA-256 checksums detect corrupt downloads; trust rests on the official repository and GitHub HTTPS.
- Settled previews stop rendering, blur work is cached, and refresh is capped according to power and temperature, with up to 120 Hz requested on supported displays while plugged in.

## Build from source

Requires Xcode 16 or newer (Swift 6) on macOS.

```sh
git clone https://github.com/shivamchopra7/Macbook-Duo-App.git
cd Macbook-Duo-App
./build.sh
open "build/Macbook Duo.app"
```

Run the unit tests and the offscreen GPU render check (generated artwork only; no desktop capture):

```sh
swift test
swift build
.build/debug/MacbookDuo --render-check validation
```

Two flavours are built from this source. `./build.sh` produces the direct download, with the in-app updater. The Mac App Store build comes from `Macbook Duo.xcodeproj` (scheme **Macbook Duo**), which compiles the updater out, turns on App Sandbox and Hardened Runtime, names the product **Macbook Fold** for the store, and is packaged by `scripts/appstore.sh`.

`scripts/verify.sh` runs all of that plus the live overlay sandbox, release packaging and the updater's self-checks in one go. Add `--effects duo,fold` to check a subset, `--animation` to export closing and reopening frames for each effect, `--no-timing` to record GPU times without gating, or `--strict-timing` to enforce the absolute 6 ms budget on median and p95 (run it on a quiet machine; by default each effect is gated at 2.5× the Duo median measured in the same run, which stays meaningful on a busy desktop). See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for signing, the Intel build, packaging, releases and adding a new effect.

## Contributing

Issues, hardware reports and focused pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first: run `swift test` and the render check, never attach desktop recordings or signing credentials, keep the app dependency-free, and respect Reduce Motion.

## License & credits

Macbook Duo is released under the [MIT License](LICENSE). Third-party notices, the sensor research it relies on and the effect studies that shaped it are listed in [ATTRIBUTION.md](ATTRIBUTION.md).

Made by Shivam Chopra. Independent software, not affiliated with or endorsed by Apple. iPhone, iPhone Duo, MacBook and macOS are trademarks of Apple Inc.
