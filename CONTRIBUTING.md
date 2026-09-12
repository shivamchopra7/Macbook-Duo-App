# Contributing to Macbook Duo

Issues, hardware reports and focused pull requests are welcome.

## Reporting an issue

Include your macOS version, Mac model, whether the lid sensor is detected (the settings window shows the live angle or "Looking for sensor"), reproduction steps and any relevant test output. Never attach desktop recordings, screenshots of private content, or signing credentials. Generated render-check output from `validation/` is safe to share.

## Before opening a pull request

```sh
swift test
swift build
.build/debug/MacbookDuo --render-check validation
```

Run the render check for any change to shaders, motion or rendering; add `--effects <ids>` to focus on the effects you touched. See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for the source layout, how to add an effect, and the localization checks.

## Ground rules

- Keep the app dependency-free: native Swift, Metal and Apple frameworks only, with no third-party runtime dependencies, accounts or analytics.
- Respect Reduce Motion and the existing power and temperature caps; every effect must fall back to the simple fade.
- Never send desktop frames anywhere. Capture stays in bounded memory and stops when the effect clears.
- Keep files short and focused, one shader file and one render check per effect, and add strings to all four `.lproj` folders.
- Do not renumber `FoldEffect` shader indices or persisted identifiers; saved preferences depend on them.

By contributing you agree that your work is released under the [MIT License](LICENSE).
