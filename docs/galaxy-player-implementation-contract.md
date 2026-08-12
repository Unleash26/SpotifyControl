# Galaxy-Inspired Player Implementation Contract

## Source And Target

- Composition source: `/var/folders/qk/q7mf_rz576n07ny_8tzd_fq80000gn/T/codex-clipboard-c297f173-d118-48ad-aae9-3360d98213b7.png`
- Liquid-ribbon motion source: `/Users/yuyatakeda/Downloads/Screen_Recording_20260811_171935_One UI Home.mp4`
- Product surface: the existing native macOS `OverlayView`
- Target viewport: `380 x 150 pt` at 100% inside the transparent shadow-padded
  panel; bottom-right dragging uniformly scales the full composition continuously
  from 55% to 135%
- Platform and theme: macOS 13 or later, dark appearance, always-on-top nonactivating panel
- Reference state: Spotify is running and playing a track with title, artist, album, artwork, position, and duration available; the motion comparison is approximately `01:41 / 03:29`
- Interaction state: pointer is not hovering a control and the seek bar is not being dragged

## Observable Design Contract

- Preserve the reference composition: metadata at the top, seek progress and time in the middle, transport controls centered at the bottom.
- Use the current track's album-cover URL as a static, full-bleed, aspect-fill background.
- Apply a fixed dark scrim and directional gradient so white text and controls remain readable on any cover.
- Keep the card compact, continuously rounded, and visually integrated with the existing macOS glass overlay.
- Display the title on the primary line. Display `artist · album` on the secondary line, omitting either side cleanly when data is missing.
- Draw elapsed progress as a filled pale-blue ribbon with a stable lower edge and one or two broad, smoothly morphing lobes along its upper edge. The remaining track is a quiet straight rail.
- Use a deterministic approximately `2.1s` loop for the ribbon. It must not read or imply audio amplitude, beats, frequency data, or track-specific visualization.
- Freeze the ribbon at a stable shape when paused or when Reduce Motion is enabled.
- The background artwork itself must never animate.

## Visible-Element Ledger

| Visible element | Product source | Action and state semantics |
| --- | --- | --- |
| Full-bleed artwork | `SpotifySnapshot.artworkURL` | Decorative only; use the existing state-aware fallback when unavailable. |
| Dark scrim and border | Local presentation | Decorative only; fixed contrast treatment for all artwork. |
| Track title | `SpotifySnapshot.title` | Read-only, one line, tail truncation. |
| Artist and album | `SpotifySnapshot.artist`, `SpotifySnapshot.album` | Read-only, one line, missing values omitted. |
| Elapsed time | Actual/extrapolated playback position | Read-only during normal playback; mirrors the drag preview while seeking. |
| Total time | `SpotifySnapshot.durationSeconds` | Read-only; unknown duration disables seeking safely. |
| Liquid-ribbon seek control | Position divided by duration | Drag previews locally; release commits Spotify's player position. Its fixed motion is decorative and independent of audio. |
| Previous button | Existing `PlayerModel.previousTrack()` | Enabled only when the current playback state supports track control. |
| Play/pause button | Existing `PlayerModel.playPause()` | Toggles playback; retains the existing permission-settings fallback. |
| Next button | Existing `PlayerModel.nextTrack()` | Enabled only when the current playback state supports track control. |
| Quit button | Existing application termination | Visible on hover only and kept subordinate to playback. |

## Required Runtime States

- Playing: the filled ribbon morphs on a fixed loop and the displayed position advances smoothly between Spotify snapshots.
- Paused or stopped: the ribbon is stable and the displayed position does not advance.
- Seeking: the pointer controls a local preview without being overwritten by the polling refresh.
- Spotify not running or unavailable: preserve the existing status copy, fallback artwork, and launch behavior.
- Automation permission denied: preserve the existing settings action and error copy.
- Artwork load failure: use a readable state-aware gradient, never an empty or transparent card.

## Required Absences

- Device or connection target label
- Media-output destination control
- Podcast control
- Spotify volume control
- Plus, favorite, or library control
- Spotify logo
- Animated, panning, or zooming artwork
- Thin sine-wave or audio-reactive visualizer styling
- Any authentication, Web API, playlist, shuffle, repeat, or browsing affordance

Unsupported or invented visible elements: none.
