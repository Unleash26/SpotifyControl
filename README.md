<p align="center">
  <img src="Assets/AppIcon.png" width="128" alt="SpotifyControl app icon">
</p>

<h1 align="center">SpotifyControl</h1>

<p align="center">
  A tiny, always-on-top Spotify controller for macOS.
</p>

<p align="center">
  <a href="https://github.com/Unleash26/SpotifyControl/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/Unleash26/SpotifyControl/actions/workflows/ci.yml/badge.svg"></a>
  <a href="https://github.com/Unleash26/SpotifyControl/releases/tag/v1.0.1"><img alt="Release v1.0.1" src="https://img.shields.io/badge/release-v1.0.1-1DB954"></a>
  <img alt="macOS 13 or later" src="https://img.shields.io/badge/macOS-13%2B-000000?logo=apple&logoColor=white">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

<p align="center">
  <img src="docs/media/spotifycontrol-liquid-ribbon.gif" width="820" alt="SpotifyControl controlling a real Spotify track while its liquid-ribbon timeline moves">
</p>

<p align="center">
  <sub>Actual SpotifyControl v1.0.1 interface — the liquid ribbon moves in a calm 2.1-second loop while music is playing.</sub>
</p>

<p align="center">
  <a href="https://github.com/Unleash26/SpotifyControl/releases/tag/v1.0.1">Release notes</a>
  ·
  <a href="#build-and-run">Build from source</a>
  ·
  <a href="#日本語">日本語</a>
</p>

SpotifyControl keeps album artwork, track information, playback progress, and
essential playback controls available in a compact glass overlay across Spaces
and full-screen apps. The panel stays out of the way: drag it anywhere, or resize
it continuously from the lower-right corner down to 55% of its default size.

It talks directly to the installed Spotify desktop app through Apple Events. No
Spotify developer account, Web API credentials, analytics, or user account is
required.

> SpotifyControl is an independent, unofficial project. It is not affiliated with
> or endorsed by Spotify AB. Spotify and the Spotify logo are trademarks of their
> respective owners.

## Features

- Always-on-top overlay that can appear across Spaces and full-screen apps
- Static full-bleed album artwork with track, artist, and album information
- Animated liquid-ribbon progress with elapsed time, duration, and seeking
- Previous, play/pause, and next controls
- Continuous bottom-right resizing from an unobtrusive 55% scale to 135%
- Remembers the overlay position between launches
- Prevents duplicate widget processes when launched repeatedly
- Compact translucent macOS-native interface
- No analytics, accounts, or bundled credentials

## Actual interface

![SpotifyControl v1.0.1 running with real track data](docs/screenshots/spotifycontrol-v1.png)

The album artwork remains still. Only the elapsed portion of the timeline gently
morphs while Spotify is playing; it is decorative motion rather than an audio
visualizer. Seeking, transport controls, window dragging, and resizing remain
fully interactive.

## Requirements

- macOS 13 Ventura or later
- [Spotify for macOS](https://www.spotify.com/download/mac/)
- Xcode Command Line Tools when building from source

## Build and run

```bash
cd SpotifyControl
./Scripts/package-app.sh release
open build/SpotifyControl.app
```

Run these commands after cloning or downloading the repository. The release
command produces:

- `build/SpotifyControl.app`

The app is built for the architecture of the Mac running the command and is
ad-hoc signed for local use. This repository distributes source code rather than
a notarized binary. A future downloadable build must be signed with a Developer
ID certificate and notarized before publication.

## First-launch permission

When Spotify is running, macOS asks whether SpotifyControl may control Spotify.
Choose **Allow**. If access was denied:

1. Open **System Settings**.
2. Go to **Privacy & Security > Automation**.
3. Enable Spotify under SpotifyControl.

You can also right-click the overlay and choose **オートメーション設定を開く**.

Changing the bundle identifier or rebuilding under a different identity can cause
macOS to request this permission again.

## Usage

- Drag the glass background to reposition the overlay.
- Drag the liquid-ribbon timeline to seek within the current track.
- Drag the small handle at the lower-right corner to resize the complete overlay
  continuously. Its aspect ratio and top-left position stay fixed, and the exact
  size is restored on the next launch.
- Right-click for Spotify, Automation settings, and Quit actions.
- Use the close button in the upper-right corner to quit.
- If Spotify is closed, pressing Play launches it in the background and resumes
  playback.

## Privacy

SpotifyControl has no telemetry and sends no usage data to the developer. Playback
state and controls stay on the Mac through Apple Events. Album artwork is loaded
from the artwork URL supplied by the Spotify desktop app.

## Development

```bash
swift build
swift test
./Scripts/package-app.sh debug
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Known limitations

- The Spotify desktop app must be installed.
- SpotifyControl controls Spotify's own volume, not the macOS system volume.
- Shuffle, repeat, and playlist browsing are not currently exposed.
- Apple Events calls are serialized and limited to three seconds; the first
  macOS permission prompt can still briefly delay a refresh.

## License

SpotifyControl is available under the [MIT License](LICENSE).

---

## 日本語

SpotifyControlは、Spotifyの曲情報・再生位置・再生操作を、ほかのアプリや
フルスクリーン表示の上から操作できる小型macOSオーバーレイです。
Spotify Web APIやAPIキーは不要で、macOSのApple Eventsを使ってローカルの
Spotifyアプリだけを操作します。
