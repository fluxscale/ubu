# ubu

Keeps your macOS Dock locked to your primary display.

macOS moves your Dock to whichever screen you push your cursor against the bottom edge of. There's no setting to disable this. ubu fixes that.

## Install

### Homebrew

```bash
brew install --cask ubu
```

### Download

Grab the latest DMG from [Releases](https://github.com/OWNER/ubu/releases).

## How it works

ubu runs as a menubar app with three layers of defense:

1. **Event Tap** — Blocks the mouse gesture that triggers Dock migration
2. **CoreDock** — If migration somehow occurs, snaps the Dock back instantly
3. **Accessibility Polling** — Safety net that detects and corrects any migration

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission (ubu will prompt you on first launch)

## Building from source

```bash
swift build
swift test
swift build -c release
```

## License

MIT
