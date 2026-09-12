# Changelog

## 1.0.0 · 12 September 2026

- **Macbook Duo.** Rebranded as Macbook Duo by Shivam Chopra, with the bundle identifier `com.shivamchopra.macbookduo` and a new app icon and menu-bar mark rendered from `scripts/make-icon.swift`.
- **Six new effects.** Fold, Accordion, Louver, Card, Curtain and Ripple join Duo, Ghost, Roll, Shutter, Flex and Iris, for twelve in total. Duo remains the default.
- **Per-effect options.** Intensity exaggerates each effect's geometry (50% reproduces the original tuning); Segments sets the panel, pleat, slat or drape count for Shutter, Accordion, Louver and Curtain (2–8); Curve chooses Smooth, Gentle, Linear or Brisk progress; Response tunes motion smoothing from 20 to 120 ms; Clear duration sets the return-to-clear animation from 0.3 to 1.2 s.
- **Existing controls kept.** Perspective, Softness, Shadow, Clears at, Clear when the lid is still, Follow my lid and Preview angle carry over unchanged, and **Reset to defaults** restores the original tuning in one click.
- **Redesigned settings window.** A Liquid Glass design language with four sections (Effects, Motion, Look, About), a live MacBook-shaped preview, and light, dark or system appearance.
- **Codebase reorganized by feature.** App, Model, Capture, Sensor, Rendering with one shader file per effect, UI, Updates and Diagnostics in the app; Effects, Motion and Updates in FoldCore. Files stay short, the test suite has grown, and every effect has its own GPU render check.
- **Same privacy model.** Desktop frames stay in memory, there are no analytics, and updates are fetched only on request from the official GitHub release. Builds remain ad-hoc signed and not notarized.
- **Four languages.** English, Simplified Chinese, Traditional Chinese and Japanese, following the macOS language preference with English fallback.
- **Requirements.** macOS 13 Ventura or newer on Apple silicon, with a native Intel preview build. A MacBook with a continuous lid-angle sensor is required: MacBook Air with M2 or newer, or 14-/16-inch MacBook Pro with M1 Pro/Max or newer. The M1 MacBook Air and 13-inch M1/M2 MacBook Pro are unsupported.
- **Release assets.** `Macbook-Duo.dmg` and `Macbook-Duo-mac.zip` for Apple silicon, `Macbook-Duo-Intel.dmg` and `Macbook-Duo-Intel.zip` for Intel, and `Macbook-Duo-SHA256SUMS.txt`, all produced by `scripts/package.sh` and published by `scripts/release.sh`.

## Earlier

1.0.0 is the first Macbook Duo release. The codebase descends from the MIT-licensed Mac Duo project; see [LICENSE](LICENSE) and [ATTRIBUTION.md](ATTRIBUTION.md) for the license text and third-party notices.
