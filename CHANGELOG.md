# Changelog

## [0.1.0] — unreleased

### Added
- Core island: borderless `NSPanel` overlay above the menu bar, real notch
  detection (`auxiliaryTopLeftArea`/`RightArea`), squircle `NotchShape`,
  click-through via `PassthroughView`, one island per display.
- **Now Playing** — Spotify / Apple Music controls (play/pause, next/prev,
  shuffle, seek, artwork) via AppleScript.
- **Clipboard** — text history with copy-back.
- **Battery** — IOKit power-source monitoring.
- **HUD** — volume (CoreAudio) and brightness (private `DisplayServices`).
- **Timer** — pomodoro countdown.
- **Shelf** — drag & drop file shelf (drop onto island, drag out, reveal in Finder).
- **Settings window** — language (English / Русский / 中文, default English),
  feature visibility, behavior, displays, sizes.
- **Hide-until-hover** — island stays invisible until the cursor hovers over it.
- Smooth animations — cross-fade/scale transitions, animated resize.
- Menu-bar status item with quick toggles and Settings/Quit.
- App icon (`.icns`).
- MIT license, SwiftPM build, `.app` bundling via `build-app.sh`.
