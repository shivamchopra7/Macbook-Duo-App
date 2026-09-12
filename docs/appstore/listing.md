# App Store Connect listing for Macbook Duo

Copy for the Mac App Store record of Macbook Duo 1.0.0 (build 100), bundle identifier `com.shivamchopra.macbookduo`. Each field below is ready to paste; the fenced blocks are the exact text, and the character limits are App Store Connect's. Keep this file in step with the README and CHANGELOG when the app changes.

## App information

| Field | Value |
|---|---|
| Name | `Macbook Duo` |
| Subtitle (30 characters max) | `Your desktop follows your lid` (29) |
| Bundle ID | `com.shivamchopra.macbookduo` |
| SKU | `macbookduo-mac` (any unique string) |
| Primary language | English (U.S.) |
| Primary category | Utilities (`public.app-category.utilities`) |
| Secondary category | Entertainment |
| Content rights | Does not contain, show or access third-party content |
| Age rating | 4+ (see the answers below) |
| Copyright | `© 2026 Shivam Chopra` |
| Support URL | `https://github.com/shivamchopra7/Macbook-Duo-App/issues` |
| Marketing URL | `https://macbookduo.illusionart.ai/` |
| Privacy policy URL | `https://macbookduo.illusionart.ai/privacy.html` |
| License agreement | Apple's standard EULA (the source is MIT-licensed; nothing extra is required) |
| Pricing | Free, all territories |

## Version information

**Version:** `1.0.0` **Build:** `100`

### Promotional text (170 characters max)

```
Close the lid and watch your desktop fold, roll, ripple or drain away. Twelve Metal effects that track the lid angle in real time, rendered entirely on your Mac.
```

### Description (4000 characters max, no emoji)

```
Macbook Duo animates your desktop as you close your MacBook. It reads the lid-angle sensor built into recent MacBooks and, as the lid tilts, the desktop bends, folds, rolls or drains away in real time. Open the lid again and everything returns to pixel-exact focus. Hold the lid still at any angle and the screen clears after a short pause, so the effect never gets in the way of your work.

TWELVE EFFECTS
Duo (the default): the desktop swells around the hinge as the lid closes.
Ghost: the desktop holds its resting plane as the lid tilts and gently falls out of focus.
Roll: the desktop curls into a roll that travels down to the hinge.
Shutter: rigid panels telescope behind each other into the hinge.
Flex: one bowing flexible display collapses toward the hinge.
Iris: eight overlapping blades close an aperture above the hinge.
Fold: the display creases across the middle and the top half folds down over the bottom.
Accordion: pleats zig-zag and gather toward the hinge like a paper fan.
Louver: horizontal slats tilt and overlap like closing window blinds.
Card: the whole desktop tips back as one rigid card in perspective.
Curtain: drapes draw together from both sides and settle at the hinge.
Blackhole: liquid rings spread from the hinge and the desktop drains into it.

MAKE IT YOURS
Every control lives in one settings window with a live MacBook-shaped preview. Intensity exaggerates each effect's geometry. Segments sets the panel, pleat, slat or drape count for Shutter, Accordion, Louver and Curtain. Curve chooses how the effect advances between open and closed: Smooth, Gentle, Linear or Brisk. Response and Clear duration tune the timing, and Perspective, Softness and Shadow shape the look. Clears at sets the lid angle at which the desktop is fully clear, and Clear when the lid is still decides how long a resting lid waits before the effect fades. Reset to defaults restores the original tuning in one click. Turn off Follow my lid to drive the preview by hand, or press Replay to watch any effect without touching the lid.

DESIGNED FOR THE MENU BAR
Macbook Duo lives in the menu bar and stays out of your way. Choose light, dark or system appearance, opt in to Open at login (it starts paused), hide the menu-bar icon if you prefer, and press Esc or Control-Option-Command-F anywhere to pause. It is written in Swift and Metal with no third-party frameworks, and it respects Reduce Motion as well as power and thermal limits.

PRIVATE BY DESIGN
Macbook Duo asks for Screen Recording permission for one reason: to render a live copy of your desktop inside the effect. Frames are captured only while the effect runs, stay in memory and are never written to disk or sent anywhere. There are no accounts, no analytics, no tracking and no network access of any kind. Your preferences are stored locally on your Mac.

REQUIREMENTS
Macbook Duo needs macOS 13 Ventura or newer and a MacBook with a continuous lid-angle sensor. Supported: MacBook Air with M2 or newer, and the 14-inch and 16-inch MacBook Pro with M1 Pro, M1 Max or newer. Not supported: the M1 MacBook Air and the 13-inch MacBook Pro with M1 or M2, which report only whether the lid is open or closed. On those Macs the app still installs and shows every effect with the Replay button, but it cannot follow the lid. External displays are not animated.

Macbook Duo speaks English, Simplified Chinese, Traditional Chinese and Japanese, and it is open source under the MIT License.
```

### Keywords (100 characters max, comma-separated, no spaces after commas, no repeats of the name)

```
lid,hinge,fold,desktop,animation,effect,metal,menu bar,screen,wallpaper,motion,laptop,close
```

### What's New in This Version

```
First Mac App Store release. Twelve lid-following effects (Duo, Ghost, Roll, Shutter, Flex, Iris, Fold, Accordion, Louver, Card, Curtain and Blackhole), per-effect tuning, a live MacBook-shaped preview, light, dark or system appearance, and four languages. Sandboxed, private, and free of accounts, analytics and network access.
```

## Age rating (4+)

Answer every question in the questionnaire with the first, lowest option:

| Question | Answer |
|---|---|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Realistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Information | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Graphic Sexual Content and Nudity | None |
| Contests | None |
| Gambling | No |
| Unrestricted Web Access | No |
| Loot boxes or similar | No |
| Made for Kids | No |

The resulting rating is 4+.

## App Privacy

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No** (the summary shown on the product page is **Data Not Collected**) |
| Does the app use tracking? | No |
| Privacy policy URL | `https://macbookduo.illusionart.ai/privacy.html` |
| Privacy choices URL | Leave empty |

Rationale, matching the privacy manifest in `App/PrivacyInfo.xcprivacy`: the app collects no data of any kind, has no analytics or third-party SDKs, and the App Store build makes no network connections. Screen frames stay in memory while the effect runs and preferences are stored locally in user defaults.

## Export compliance

| Question | Answer |
|---|---|
| Is your app designed to use cryptography or does it contain or incorporate cryptography? | **No** |

The App Store build performs no encryption and opens no network connections. The shared code computes a SHA-256 hash to describe release archives, which is a checksum rather than encryption, and the code that would use it is compiled out of the store build. Setting `ITSAppUsesNonExemptEncryption` to `NO` in `App/Info.plist` records the same answer for every upload.

## Notes for App Review

Paste into the *Notes* field of the App Review Information section. No sign-in is required, so leave the demo account empty.

```
Macbook Duo is a menu-bar accessory app (LSUIElement is set), so it has no Dock icon; its settings window opens on launch and can be reopened from the menu-bar icon or by opening the app again.

SCREEN RECORDING. The app asks for Screen Recording permission for a single purpose: it uses ScreenCaptureKit to obtain a live copy of the built-in display and renders that copy, transformed by a Metal shader, on a full-screen overlay while the lid moves. Frames are captured only while the effect is on screen, stay in memory on the GPU and in a small bounded buffer, and are never written to disk or transmitted. The app's own windows are excluded from the capture and no audio is captured. The permission is requested only when the user clicks "Enable Macbook Duo" or "Test desktop"; the preview and the Replay button work without it.

LID-ANGLE SENSOR. The effect is driven by the continuous lid-angle sensor built into MacBook Air (M2 or newer) and the 14-inch and 16-inch MacBook Pro (M1 Pro/Max or newer). The sensor is a built-in HID device read through IOKit, and reading it inside the App Sandbox requires the standard com.apple.security.device.usb entitlement; without it IOHIDManagerOpen fails. That entitlement is the only addition to the sandbox. The angle is a single number used for the animation and is not stored or transmitted.

REVIEWING ON A MAC WITHOUT THE SENSOR. Every effect can be evaluated without moving a lid. On the Effects page, pick any effect and press "Replay" to watch it close and reopen in the built-in preview (no permission needed). Press "Test desktop" to run the real full-screen effect on the reviewer's actual desktop for eight seconds (this prompts for Screen Recording). On the Motion page, turn off "Follow my lid" and drag "Preview angle" to hold the effect at any position. Press Esc or Control-Option-Command-F at any time to stop the effect.

NETWORK AND UPDATES. The App Store build contains no networking code and never connects to any server; there is no self-updater, no analytics and no third-party SDK. Updates arrive only through the App Store. The privacy manifest declares the two required-reason APIs the app uses (system boot time for the animation clock and user defaults for preferences).

The app is open source: https://github.com/shivamchopra7/Macbook-Duo-App
```

## Screenshots

App Store Connect accepts Mac screenshots at 1280×800, 1440×900, 2560×1600 or 2880×1800 pixels (16:10). Upload one size; the 2880×1800 set is produced by `scripts/appstore-screenshots.sh` into `docs/appstore/screenshots/` and is what the store scales for every display. Regenerate the set from the store build before uploading so the About page carries no update button: `MACBOOKDUO_APP="build-appstore/<export>/Macbook Duo.app" scripts/appstore-screenshots.sh`.

| Order | File | Shows |
|---|---|---|
| 1 | `01-effects.png` | The Effects page in dark appearance: the twelve effects with Duo selected, the Intensity slider, and the live MacBook-shaped preview with its Enable, Test desktop and Replay buttons. Caption: "Twelve effects that follow your lid". |
| 2 | `02-motion.png` | The Motion page in dark appearance: Follow my lid, Preview angle, Clears at, Clear when the lid is still, Clear after, the Curve picker, Response, Clear duration and Reset to defaults. Caption: "Tune how the desktop follows your hand". |
| 3 | `03-look.png` | The Look page in dark appearance: Perspective, Softness and Shadow sliders, the Light / Dark / System appearance picker, and the Menu bar icon and Open at login switches. Caption: "Perspective, softness, shadow and appearance". |
| 4 | `04-about.png` | The About page in dark appearance: the app icon, version, credit and the Open source on GitHub button. Caption: "Open source. No accounts, no analytics, no tracking." |
| 5 | `05-effects-light.png` | The Effects page again in light appearance, showing the same window and preview with the light glass treatment. Caption: "Light, dark or system appearance". |

Each screenshot is the real settings window (940×550 points captured at 2x) placed on the brand-blue gradient used by the website, with a one-line white caption at the top. The preview inside the window is generated artwork; no real desktop appears in any screenshot. An app preview video is optional; the website's `docs/assets/duo.mp4` can be re-rendered at 1920×1080 if one is wanted later.

## Review information

| Field | Value |
|---|---|
| Contact first and last name, phone, email | Fill in from the developer account (not stored in this repository). |
| Demo account | Not required; leave "Sign-in required" unchecked. |
| Attachment | None needed. The Replay and Test desktop buttons demonstrate every effect. |
| Version release | Manually release this version (release after approval once the website download links are updated). |
