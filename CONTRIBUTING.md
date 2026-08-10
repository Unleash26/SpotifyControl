# Contributing

Thanks for helping improve SpotifyControl.

## Development setup

1. Use macOS 13 or later with Spotify installed.
2. Install Xcode Command Line Tools.
3. Run `swift build` and `swift test`.
4. Package a local app with `./Scripts/package-app.sh debug`.

## Pull requests

- Keep changes focused and preserve the compact overlay behavior.
- Add or update tests for parsing, state handling, and other testable logic.
- Verify the overlay over both light and dark backgrounds.
- Check Spotify running, paused, stopped, not-running, and permission-denied states.
- Do not commit `.build/`, `build/`, credentials, signing identities, or local
  Automation permission data.

## Bug reports

Please include:

- macOS version and Mac architecture
- Spotify version
- Steps to reproduce
- Expected and actual behavior
- A screenshot when the issue is visual

Do not include passwords, cookies, account data, or other secrets.
