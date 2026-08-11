# Changelog

All notable changes to SpotifyControl are documented here.

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
