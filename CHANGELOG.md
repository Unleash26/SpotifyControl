# Changelog

All notable changes to SpotifyControl are documented here.

## Unreleased

### Added

- Galaxy-inspired full-bleed artwork player with an animated liquid-ribbon timeline
- Elapsed time, track duration, and drag-to-seek playback control
- Smooth locally interpolated progress between Spotify refreshes
- Continuous bottom-right resizing from 55% to 135%, with exact-size persistence

### Changed

- Replaced the volume-focused compact layout with title, artist, album, progress,
  and centered transport controls
- Preserved saved overlay placement while adopting the taller player-card size
- Replaced the thin sine-wave stroke with One UI's filled, broad-lobe progress treatment

### Fixed

- Kept resized saved frames fully inside the current display's visible bounds
- Prevented failed or zero-duration refreshes during a drag from seeking to zero
- Prevented pointer seeking or panel movement from leaving a focus rectangle
  around the entire timeline while retaining keyboard focus feedback
- Removed a one-pixel rectangular backdrop seam exposed by continuous scaling
- Avoided transparent-panel damage during timeline updates by using a small
  synchronous Canvas

## 0.2.0 - 2026-08-11

### Added

- Compact translucent overlay with rounded custom shadow
- Remembered overlay position across launches
- Friendly Automation permission guidance
- Right-click menu for Spotify, Automation settings, and Quit
- Unit tests and GitHub Actions CI
- Original green visualizer application icon
- Strict local app signature verification
- Three-second Apple Event timeout and serialized main-thread execution

### Fixed

- Removed the rectangular `NSPanel` shadow visible around rounded corners
- Removed decorative highlight lines that could be mistaken for progress controls
- Replaced the native volume slider with a single-track control to remove its extra highlight
- Propagated playback and volume command failures instead of silently ignoring them
- Launching Spotify from Play now resumes playback after launch
- Prevented older overlapping refreshes from replacing newer UI state
- Prevented stale volume writes from winning over the latest slider value
- Prevented duplicate widget processes with an automatic process lock
- Expanded window dragging to every non-interactive area of the overlay
- Fixed lagging and jumping while dragging the overlay
- Removed the misleading grab cursor shown over playback and volume controls
- Replaced delayed volume debouncing with responsive latest-value throttling

### Changed

- Bundle identifier changed to `io.github.yuyatakeda.SpotifyControl`
- Minimum supported version remains macOS 13
